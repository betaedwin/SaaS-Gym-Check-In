import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home_screen.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const HomeScreen();
        }

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
