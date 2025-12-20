import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/profile_bootstrap.dart';
import '../home_screen.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  Future<void>? _ensureProfileFuture;
  String? _ensureProfileUserId;
  Session? _latestSession;

  Future<void> _recoverFromProfileSetupFailure(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      setState(_resetEnsureProfile);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  void _startEnsureProfileIfNeeded({required Session session}) {
    final userId = session.user.id;
    _latestSession = session;
    if (_ensureProfileFuture != null && _ensureProfileUserId == userId) return;

    _ensureProfileUserId = userId;
    _ensureProfileFuture = ensureProfileExistsForUser(
      userId: session.user.id,
      email: session.user.email,
    );
  }

  void _resetEnsureProfile() {
    _ensureProfileFuture = null;
    _ensureProfileUserId = null;
    _latestSession = null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        if (session != null) {
          _startEnsureProfileIfNeeded(session: session);

          return FutureBuilder<void>(
            future: _ensureProfileFuture,
            builder: (context, ensureSnapshot) {
              if (ensureSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (ensureSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'We couldn’t set up your profile.\nPlease try again.',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              _recoverFromProfileSetupFailure(context);
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return const HomeScreen();
            },
          );
        }

        _resetEnsureProfile();

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Something went wrong. Please try again.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
