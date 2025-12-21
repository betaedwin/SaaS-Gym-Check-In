import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/date_formatting.dart';
import '../../core/logging.dart';
import '../../core/ui/app_style.dart';
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

  final recentVisits = recentRows
      .map((row) => _parseTimestampToLocal(row['checked_in_at']))
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

  static const _gymLogoAssetPath = 'web/icons/Icon-512.png';

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
    final theme = Theme.of(context);
    final styles = AppTextStyles(theme);

    final asyncProfile = ref.watch(_profileProvider);
    final isPreparingSnapshot = ref.watch(_isPreparingSnapshotProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
        minimum: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
          vertical: AppSpacing.screenPaddingV,
        ),
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
              padding: EdgeInsets.zero,
              children: [
                _IdentityBlock(
                  name: profile.fullName.isEmpty
                      ? 'Unknown user'
                      : profile.fullName,
                  email: displayEmail.isEmpty ? '—' : displayEmail,
                  belt: profile.belt.isEmpty ? '—' : profile.belt,
                  styles: styles,
                  logo: const _GymLogo(assetPath: _gymLogoAssetPath),
                ),
                const SizedBox(height: _ProfileSpacing.blockGap),
                AppHairlineDivider(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
                ),
                const SizedBox(height: _ProfileSpacing.blockGap),
                Text(
                  'Attendance',
                  style: styles.sectionTitle,
                ),
                const SizedBox(height: _ProfileSpacing.sectionGap),
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
                        padding: const EdgeInsets.only(top: _ProfileSpacing.sectionGap),
                        child: Text(
                          'No check-ins yet.',
                          style: styles.primary,
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
                        _LabeledValue(
                          label: 'Member since',
                          value: memberSince,
                          labelStyle: styles.secondary,
                          valueStyle: styles.primary,
                        ),
                        const SizedBox(height: _ProfileSpacing.factGap),
                        _LabeledValue(
                          label: 'Total check-ins',
                          value: snapshot.totalCheckIns.toString(),
                          labelStyle: styles.secondary,
                          valueStyle: styles.primary,
                        ),
                        const SizedBox(height: _ProfileSpacing.factGap),
                        _LabeledValue(
                          label: 'Last visit',
                          value: lastVisit,
                          labelStyle: styles.secondary,
                          valueStyle: styles.primary,
                        ),
                        const SizedBox(height: _ProfileSpacing.factGap),
                        _LabeledValue(
                          label: 'Recent activity',
                          value: recent.isEmpty ? '—' : recent,
                          labelStyle: styles.secondary,
                          valueStyle: styles.tertiaryValue,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: _ProfileSpacing.blockGap),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.82),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.55),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    minimumSize: const Size.fromHeight(44),
                    textStyle: styles.actionText,
                  ),
                  onPressed: isPreparingSnapshot
                      ? null
                      : () => _shareTrainingSnapshot(
                            context,
                            ref,
                            memberName: profile.fullName,
                          ),
                  child: const Text('Share training snapshot'),
                ),
                const SizedBox(height: _ProfileSpacing.blockGap),
                AppHairlineDivider(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
                ),
                const SizedBox(height: _ProfileSpacing.sectionGap),
                _LabeledValue(
                  label: 'User ID',
                  value: userId,
                  labelStyle: styles.tertiaryLabel,
                  valueStyle: styles.tertiaryValue,
                ),
                const SizedBox(height: _ProfileSpacing.sectionGap),
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

class _ProfileSpacing {
  static const double labelToValueGap = AppSpacing.tight;
  static const double factGap = AppSpacing.rowGap;
  static const double sectionGap = AppSpacing.standard;
  static const double blockGap = AppSpacing.loose;
}

class _GymLogo extends StatelessWidget {
  const _GymLogo({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Opacity(
      opacity: 0.16,
      child: Image.asset(
        assetPath,
        width: 26,
        height: 26,
        fit: BoxFit.contain,
        color: onSurface,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.low,
      ),
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({
    required this.name,
    required this.email,
    required this.belt,
    required this.styles,
    required this.logo,
  });

  final String name;
  final String email;
  final String belt;
  final AppTextStyles styles;
  final Widget logo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        logo,
        const SizedBox(height: _ProfileSpacing.labelToValueGap),
        Text(name, style: styles.display),
        const SizedBox(height: _ProfileSpacing.sectionGap),
        _LabeledValue(
          label: 'Email',
          value: email,
          labelStyle: styles.secondary,
          valueStyle: styles.primarySoft,
        ),
        const SizedBox(height: _ProfileSpacing.factGap),
        _LabeledValue(
          label: 'Belt',
          value: belt,
          labelStyle: styles.secondary,
          valueStyle: styles.primarySoft,
        ),
      ],
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: labelStyle ?? Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: _ProfileSpacing.labelToValueGap),
        Text(
          value,
          style: valueStyle ?? Theme.of(context).textTheme.bodyLarge,
          softWrap: true,
        ),
      ],
    );
  }
}
