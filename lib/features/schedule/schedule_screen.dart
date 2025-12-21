import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging.dart';
import '../../core/ui/app_style.dart';

class _ScheduleClass {
  const _ScheduleClass({
    required this.id,
    required this.title,
    required this.startTimeLocal,
    required this.endTimeLocal,
    required this.instructor,
    required this.category,
  });

  final String id;
  final String title;
  final DateTime startTimeLocal;
  final DateTime endTimeLocal;
  final String? instructor;
  final String? category;

  factory _ScheduleClass.fromJson(Map<String, dynamic> json) {
    return _ScheduleClass(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      startTimeLocal: _parseTimestamptzToLocal(json['start_time']),
      endTimeLocal: _parseTimestamptzToLocal(json['end_time']),
      instructor: _nullableNonEmpty(json['instructor'] as String?),
      category: _nullableNonEmpty(json['category'] as String?),
    );
  }
}

final _scheduleProvider = FutureProvider.autoDispose<List<_ScheduleClass>>((ref) async {
  SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (e, st) {
    logError('Supabase client unavailable', e, st);
    throw Exception('Service unavailable. Please try again.');
  }

  final user = client.auth.currentUser;
  if (user == null) {
    throw Exception('Not authenticated.');
  }

  try {
    final rows = await client
        .from('class_schedule')
        .select('id,title,start_time,end_time,instructor,category')
        .order('start_time', ascending: true)
        .timeout(const Duration(seconds: 10));

    final list = rows is List ? rows : const [];
    return list
        .map((row) => _ScheduleClass.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList(growable: false);
  } catch (e, st) {
    logError('Schedule fetch failed', e, st);
    rethrow;
  }
});

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = AppTextStyles(Theme.of(context));
    final asyncSchedule = ref.watch(_scheduleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
          vertical: AppSpacing.screenPaddingV,
        ),
        child: asyncSchedule.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'We couldn’t load the schedule.\nPlease try again.',
                    style: styles.primary,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: styles.tertiaryValue,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.refresh(_scheduleProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Text(
                  'No classes scheduled yet.',
                  style: styles.secondary,
                  textAlign: TextAlign.center,
                ),
              );
            }

            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.standard),
                child: AppHairlineDivider(),
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final timeLine = _formatTimeRange(
                  context,
                  item.startTimeLocal,
                  item.endTimeLocal,
                );

                final detailLines = <String>[
                  if (item.instructor != null) 'Instructor: ${item.instructor}',
                  if (item.category != null) 'Category: ${item.category}',
                ];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: styles.primary),
                      const SizedBox(height: AppSpacing.tight),
                      Text(timeLine, style: styles.primarySoft),
                      if (detailLines.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.standard),
                        Text(
                          detailLines.join('\n'),
                          style: styles.tertiaryValue,
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String _formatTimeRange(BuildContext context, DateTime startLocal, DateTime endLocal) {
  final localizations = MaterialLocalizations.of(context);
  final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);

  final date = localizations.formatMediumDate(startLocal);
  final startTime = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(startLocal),
    alwaysUse24HourFormat: use24Hour,
  );
  final endTime = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(endLocal),
    alwaysUse24HourFormat: use24Hour,
  );

  return '$date • $startTime – $endTime';
}

DateTime _parseTimestamptzToLocal(dynamic value) {
  return switch (value) {
    final String v => DateTime.parse(v).toLocal(),
    final DateTime v => v.toLocal(),
    _ => DateTime.now(),
  };
}

String? _nullableNonEmpty(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
