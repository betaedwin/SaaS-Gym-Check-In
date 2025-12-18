import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging.dart';

class _Profile {
  const _Profile({
    required this.id,
    required this.name,
    required this.belt,
  });

  final String id;
  final String name;
  final String belt;

  factory _Profile.fromJson(Map<String, dynamic> json) {
    return _Profile(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      belt: (json['belt'] as String?) ?? '',
    );
  }
}

final _profileProvider = FutureProvider.autoDispose<_Profile>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw Exception('Not authenticated.');
  }

  final data = await Supabase.instance.client
      .from('profiles')
      .select('id,name,belt')
      .eq('id', user.id)
      .single();

  final profile = _Profile.fromJson(Map<String, dynamic>.from(data));
  if (profile.id.isEmpty) throw Exception('Profile not found.');
  return profile;
});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(_profileProvider);

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
            child: Text(
              'Failed to load profile.\n${error.toString()}',
              textAlign: TextAlign.center,
            ),
          ),
          data: (profile) {
            final userId = Supabase.instance.client.auth.currentUser?.id ?? profile.id;
            return ListView(
              children: [
                Text(
                  profile.name.isEmpty ? 'Unknown user' : profile.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                _Row(label: 'Belt', value: profile.belt.isEmpty ? '—' : profile.belt),
                const SizedBox(height: 8),
                _Row(label: 'User ID', value: userId),
              ],
            );
          },
        ),
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
