import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_style.dart';
import 'qr_scan_screen.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  static const _gymLat = 36.8529;
  static const _gymLng = -121.4016;
  static const _radiusMeters = 100.0;
  static const _qrExpected = 'hollisterbjj-checkin-v1';

  bool _loading = false;
  bool _attemptedLocationRequest = false;
  LocationPermission _locationPermission = LocationPermission.denied;
  String? _status;

  late Future<List<_CheckInHistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _refreshLocationPermission();
    _historyFuture = _fetchRecentCheckIns();
  }

  SupabaseClient? _supabaseClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<_CheckInHistoryItem>> _fetchRecentCheckIns() async {
    final client = _supabaseClientOrNull();
    if (client == null) return const [];

    final user = client.auth.currentUser;
    if (user == null) return const [];

    final rows = await client
        .from('check_ins')
        .select('checked_in_at, method')
        .eq('user_id', user.id)
        .order('checked_in_at', ascending: false)
        .limit(7);

    final list = rows is List ? rows : const [];
    return list
        .map((row) {
          final map = row as Map<String, dynamic>;
          final checkedInAtRaw = map['checked_in_at'];
          final checkedInAt = switch (checkedInAtRaw) {
            final String v => DateTime.parse(v).toLocal(),
            final DateTime v => v.toLocal(),
            _ => DateTime.now(),
          };
          final method = (map['method'] as String?) ?? 'unknown';
          return _CheckInHistoryItem(checkedInAt: checkedInAt, method: method);
        })
        .toList(growable: false);
  }

  void _refreshHistory() {
    setState(() {
      _historyFuture = _fetchRecentCheckIns();
    });
  }

  Future<void> _refreshLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (!mounted) return;
    setState(() => _locationPermission = permission);
  }

  Future<bool> _alreadyCheckedInToday({required String userId}) async {
    final nowLocal = DateTime.now();
    final startLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final endLocal = startLocal.add(const Duration(days: 1));

    final rows = await Supabase.instance.client
        .from('check_ins')
        .select('checked_in_at')
        .eq('user_id', userId)
        .gte('checked_in_at', startLocal.toUtc().toIso8601String())
        .lt('checked_in_at', endLocal.toUtc().toIso8601String())
        .limit(1);

    final list = rows is List ? rows : const [];
    return list.isNotEmpty;
  }

  Future<void> _insertCheckIn({
    required String userId,
    required String method,
    double? lat,
    double? lng,
  }) async {
    await Supabase.instance.client.from('check_ins').insert({
      'user_id': userId,
      'checked_in_at': DateTime.now().toUtc().toIso8601String(),
      'lat': lat,
      'lng': lng,
      'method': method,
    });
  }

  Future<void> _checkInViaGps() async {
    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _status = 'You must be logged in to check in.');
        return;
      }

      final already = await _alreadyCheckedInToday(userId: user.id).timeout(
        const Duration(seconds: 10),
      );
      if (already) {
        setState(() => _status = 'Already checked in today.');
        return;
      }

      _attemptedLocationRequest = true;

      final permission = await Geolocator.requestPermission().timeout(
        const Duration(seconds: 15),
      );
      _locationPermission = permission;

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _status = 'Location permission was denied. Scan the gym QR code to check in.';
        });
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 10),
      );
      if (!serviceEnabled) {
        setState(() {
          _status = 'Location services are off. Turn them on to check in with GPS.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(
        const Duration(seconds: 20),
      );

      final distance = Geolocator.distanceBetween(
        _gymLat,
        _gymLng,
        position.latitude,
        position.longitude,
      );

      if (distance > _radiusMeters) {
        setState(() {
          _status = 'Too far from the gym. You must be within ${_radiusMeters.toStringAsFixed(0)}m to check in.';
        });
        return;
      }

      await _insertCheckIn(
        userId: user.id,
        method: 'gps',
        lat: position.latitude,
        lng: position.longitude,
      ).timeout(const Duration(seconds: 10));

      setState(() {
        _status = 'Checked in successfully.';
        _historyFuture = _fetchRecentCheckIns();
      });
    } on TimeoutException {
      setState(() {
        _status = 'This is taking too long. Try again, or scan the gym QR code to check in.';
      });
    } catch (e) {
      setState(() => _status = 'Check-in failed. ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _checkInViaQr() async {
    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _status = 'You must be logged in to check in.');
        return;
      }

      final already = await _alreadyCheckedInToday(userId: user.id).timeout(
        const Duration(seconds: 10),
      );
      if (already) {
        setState(() => _status = 'Already checked in today.');
        return;
      }

      final scanned = await _scanQrCode();
      if (!mounted) return;

      if (scanned == null) {
        setState(() => _status = 'QR scan canceled.');
        return;
      }

      if (scanned != _qrExpected) {
        setState(() => _status = 'Invalid QR code.');
        return;
      }

      await _insertCheckIn(
        userId: user.id,
        method: 'qr',
        lat: null,
        lng: null,
      ).timeout(const Duration(seconds: 10));

      setState(() {
        _status = 'Checked in successfully.';
        _historyFuture = _fetchRecentCheckIns();
      });
    } on TimeoutException {
      setState(() => _status = 'Check-in is taking too long. Please try again.');
    } catch (e) {
      setState(() => _status = 'Check-in failed. ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _scanQrCode() {
    return Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final denied = _attemptedLocationRequest &&
        (_locationPermission == LocationPermission.denied ||
            _locationPermission == LocationPermission.deniedForever);
    final styles = AppTextStyles(Theme.of(context));

    return Scaffold(
      appBar: AppBar(title: const Text('Check-In')),
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
          vertical: AppSpacing.screenPaddingV,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status != null) ...[
              Text(
                _status!,
                style: styles.primary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.loose),
            ],
            if (!denied)
              FilledButton(
                onPressed: _loading ? null : _checkInViaGps,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Check In'),
              )
            else ...[
              Text(
                'Location permission is required for GPS check-in.\nScan the gym QR code instead.',
                textAlign: TextAlign.center,
                style: styles.secondary,
              ),
              const SizedBox(height: AppSpacing.standard),
              FilledButton(
                onPressed: _loading ? null : _checkInViaQr,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Scan QR Code'),
              ),
            ],
            const SizedBox(height: AppSpacing.loose),
            const AppHairlineDivider(),
            const SizedBox(height: AppSpacing.standard),
            Text(
              'Recent check-ins',
              style: styles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.standard),
            Expanded(
              child: FutureBuilder<List<_CheckInHistoryItem>>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load check-in history.',
                        style: styles.secondary,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final client = _supabaseClientOrNull();
                  if (client?.auth.currentUser == null) {
                    return Center(
                      child: Text(
                        'Log in to see your check-in history.',
                        style: styles.secondary,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No check-ins yet.',
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
                      final methodLabel = switch (item.method) {
                        'gps' => 'GPS',
                        'qr' => 'QR',
                        _ => item.method.toUpperCase(),
                      };

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Checked in', style: styles.secondary),
                            const SizedBox(height: AppSpacing.tight),
                            Text(
                              '${_formatDateLabel(item.checkedInAt)} • ${_formatTimeLabel(item.checkedInAt)} • $methodLabel',
                              style: styles.primary,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInHistoryItem {
  const _CheckInHistoryItem({required this.checkedInAt, required this.method});

  final DateTime checkedInAt;
  final String method;
}

String _formatDateLabel(DateTime dateTimeLocal) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(dateTimeLocal.year, dateTimeLocal.month, dateTimeLocal.day);

  if (date == today) return 'Today';
  if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';

  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[dateTimeLocal.month - 1];
  return '$month ${dateTimeLocal.day}, ${dateTimeLocal.year}';
}

String _formatTimeLabel(DateTime dateTimeLocal) {
  String two(int v) => v.toString().padLeft(2, '0');
  final hour24 = dateTimeLocal.hour;
  final hour12 = switch (hour24 % 12) { 0 => 12, final v => v };
  final suffix = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:${two(dateTimeLocal.minute)} $suffix';
}
