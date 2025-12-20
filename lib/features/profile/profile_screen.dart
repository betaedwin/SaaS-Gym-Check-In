import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/date_formatting.dart';
import '../../core/logging.dart';
import 'training_snapshot_share.dart';

class _Profile {
  const _Profile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.belt,
  });

  final String id;
  final String email;
  final String fullName;
  final String belt;

  factory _Profile.fromJson(Map<String, dynamic> json) {
    return _Profile(
      id: (json['id'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      belt: (json['belt'] as String?) ?? '',
    );
  }
}

final _profileProvider = FutureProvider.autoDispose<_Profile>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw Exception('Not authenticated.');
  }

  Future<Map<String, dynamic>?> fetch() async {
    final data = await Supabase.instance.client
        .from('profiles')
        .select('id,email,full_name,belt')
        .eq('id', user.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  final data = await fetch();
  if (data == null) throw Exception('Profile not found. Please try again.');

  final profile = _Profile.fromJson(data);
  if (profile.id.isEmpty) throw Exception('Profile not found.');
  return profile;
});

class _AttendanceSnapshot {
  const _AttendanceSnapshot({
    required this.totalCheckIns,
    required this.firstCheckInAt,
    required this.recentVisits,
  });

  final int totalCheckIns;
  final DateTime? firstCheckInAt;
  final List<DateTime> recentVisits;

  DateTime? get lastVisitAt => recentVisits.isEmpty ? null : recentVisits.first;
}

final _attendanceSnapshotProvider =
    FutureProvider.autoDispose<_AttendanceSnapshot>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw Exception('Not authenticated.');
  }

  final client = Supabase.instance.client;
  final countResponse = await client
      .from('check_ins')
      .select('id')
      .eq('user_id', user.id)
      .count(CountOption.exact)
      .timeout(const Duration(seconds: 10));
  final total = countResponse.count;

  DateTime? first;
  if (total > 0) {
    final row = await client
        .from('check_ins')
        .select('checked_in_at')
        .eq('user_id', user.id)
        .order('checked_in_at', ascending: true)
        .limit(1)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));
    final raw = (row is Map<String, dynamic>) ? row['checked_in_at'] : null;
    first = _parseTimestampToLocal(raw);
  }

  final recentRows = await client
      .from('check_ins')
      .select('checked_in_at')
      .eq('user_id', user.id)
      .order('checked_in_at', ascending: false)
      .limit(5)
      .timeout(const Duration(seconds: 10));

  final recentList = recentRows is List ? recentRows : const [];
  final recentVisits = recentList
      .map((row) {
        final map = row as Map<String, dynamic>;
        return _parseTimestampToLocal(map['checked_in_at']);
      })
      .whereType<DateTime>()
      .toList(growable: false);

  return _AttendanceSnapshot(
    totalCheckIns: total,
    firstCheckInAt: first,
    recentVisits: recentVisits,
  );
});

class _IsPreparingSnapshotNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setPreparing(bool value) => state = value;
}

final _isPreparingSnapshotProvider =
    NotifierProvider.autoDispose<_IsPreparingSnapshotNotifier, bool>(
        _IsPreparingSnapshotNotifier.new);

DateTime? _parseTimestampToLocal(Object? raw) {
  return switch (raw) {
    final String v => DateTime.tryParse(v)?.toLocal(),
    final DateTime v => v.toLocal(),
    _ => null,
  };
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e, st) {
      logError('Logout failed', e, st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logout failed. Please try again.')),
        );
      }
    }
  }

  Future<void> _shareTrainingSnapshot(
    BuildContext context,
    WidgetRef ref, {
    required String memberName,
  }) async {
    if (memberName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to generate snapshot. Please try again.')),
      );
      return;
    }

    ref.read(_isPreparingSnapshotProvider.notifier).setPreparing(true);
    var dialogPopped = false;
    final accentColor = Theme.of(context).colorScheme.primary;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BlockingDialog(message: 'Preparing snapshot…'),
    );

    try {
      final snapshot = await ref.read(_attendanceSnapshotProvider.future);
      final xFile = await buildTrainingSnapshotXFile(
        memberName: memberName,
        memberSince: snapshot.firstCheckInAt,
        totalCheckIns: snapshot.totalCheckIns,
        accentColor: accentColor,
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      dialogPopped = true;
      await SharePlus.instance.share(
        ShareParams(files: [xFile]),
      );
    } catch (e, st) {
      logError('Share snapshot failed', e, st);
      if (context.mounted) {
        if (!dialogPopped) {
          Navigator.of(context, rootNavigator: true).pop();
          dialogPopped = true;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unable to generate snapshot. Please try again.')),
        );
      }
    } finally {
      ref.read(_isPreparingSnapshotProvider.notifier).setPreparing(false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(_profileProvider);
    final isPreparingSnapshot = ref.watch(_isPreparingSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: asyncProfile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'We couldn’t load your profile.\nPlease try again.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.refresh(_profileProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (profile) {
            final asyncAttendance = ref.watch(_attendanceSnapshotProvider);
            final userId =
                Supabase.instance.client.auth.currentUser?.id ?? profile.id;
            final authEmail =
                Supabase.instance.client.auth.currentUser?.email ?? '';
            final displayEmail =
                profile.email.isEmpty ? authEmail : profile.email;
            return ListView(
              children: [
                Text(
                  profile.fullName.isEmpty ? 'Unknown user' : profile.fullName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                _Row(
                    label: 'Email',
                    value: displayEmail.isEmpty ? '—' : displayEmail),
                const SizedBox(height: 8),
                _Row(
                    label: 'Belt',
                    value: profile.belt.isEmpty ? '—' : profile.belt),
                const SizedBox(height: 16),
                Text(
                  'Attendance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                asyncAttendance.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'We couldn’t load your attendance snapshot.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(error.toString()),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              ref.refresh(_attendanceSnapshotProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (snapshot) {
                    if (snapshot.totalCheckIns == 0) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No check-ins yet.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      );
                    }

                    final memberSince = snapshot.firstCheckInAt == null
                        ? '—'
                        : formatLocalDate(snapshot.firstCheckInAt!);
                    final lastVisit = snapshot.lastVisitAt == null
                        ? '—'
                        : formatLocalDate(snapshot.lastVisitAt!);
                    final recent =
                        snapshot.recentVisits.map(formatLocalDate).join(', ');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Row(
                            label: 'Total',
                            value: snapshot.totalCheckIns.toString()),
                        const SizedBox(height: 8),
                        _Row(label: 'Member since', value: memberSince),
                        const SizedBox(height: 8),
                        _Row(label: 'Last visit', value: lastVisit),
                        const SizedBox(height: 8),
                        _Row(
                            label: 'Recent',
                            value: recent.isEmpty ? '—' : recent),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: isPreparingSnapshot
                      ? null
                      : () => _shareTrainingSnapshot(
                            context,
                            ref,
                            memberName: profile.fullName,
                          ),
                  child: const Text('Share training snapshot'),
                ),
                const SizedBox(height: 16),
                _Row(label: 'User ID', value: userId),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BlockingDialog extends StatelessWidget {
  const _BlockingDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(message)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
