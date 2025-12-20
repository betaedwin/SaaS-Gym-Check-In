import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'logging.dart';

Future<void> ensureProfileExists({SupabaseClient? supabase}) async {
  final client = supabase ?? Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) throw Exception('Not authenticated.');
  return ensureProfileExistsForUser(
    userId: user.id,
    email: user.email,
    supabase: client,
  );
}

Future<void> ensureProfileExistsForUser({
  required String userId,
  String? email,
  SupabaseClient? supabase,
}) async {
  final client = supabase ?? Supabase.instance.client;

  final existing = await client
      .from('profiles')
      .select('id')
      .eq('id', userId)
      .maybeSingle()
      .timeout(const Duration(seconds: 10));

  if (existing != null) return;

  try {
    await client.from('profiles').insert({
      'id': userId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'email': email ?? '',
      'full_name': '',
      'belt': '',
    }).timeout(const Duration(seconds: 10));
  } on PostgrestException catch (e, st) {
    if (_isDuplicateKey(e)) return;
    logError('Profile creation failed', e, st);
    rethrow;
  }
}

bool _isDuplicateKey(PostgrestException e) {
  if (e.code == '23505') return true;
  final message = e.message.toLowerCase();
  return message.contains('duplicate key') || message.contains('already exists');
}
