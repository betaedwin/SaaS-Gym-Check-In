import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    return (rows as List)
        .map((row) {
          final map = row as Map<String, dynamic>;
          final checkedInAt = DateTime.parse(map['checked_in_at'] as String).toLocal();
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

    return (rows as List).isNotEmpty;
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

      final already = await _alreadyCheckedInToday(userId: user.id);
      if (already) {
        setState(() => _status = 'Already checked in today.');
        return;
      }

      _attemptedLocationRequest = true;

      final permission = await Geolocator.requestPermission();
      _locationPermission = permission;

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _status = 'Location permission was denied. Scan the gym QR code to check in.';
        });
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
      );

      setState(() {
        _status = 'Checked in successfully.';
        _historyFuture = _fetchRecentCheckIns();
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

      final already = await _alreadyCheckedInToday(userId: user.id);
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
      );

      setState(() {
        _status = 'Checked in successfully.';
        _historyFuture = _fetchRecentCheckIns();
      });
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

    return Scaffold(
      appBar: AppBar(title: const Text('Check-In')),
      body: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status != null) ...[
              Text(
                _status!,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
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
              ),
              const SizedBox(height: 12),
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
            const SizedBox(height: 24),
            Text(
              'Recent check-ins',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
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
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final client = _supabaseClientOrNull();
                  if (client?.auth.currentUser == null) {
                    return Center(
                      child: Text(
                        'Log in to see your check-in history.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No check-ins yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final methodLabel = switch (item.method) {
                        'gps' => 'GPS',
                        'qr' => 'QR',
                        _ => item.method.toUpperCase(),
                      };

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${_formatDate(item.checkedInAt)} • ${_formatTime(item.checkedInAt)}'),
                        subtitle: Text('Method: $methodLabel'),
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

String _formatDate(DateTime dateTimeLocal) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dateTimeLocal.year}-${two(dateTimeLocal.month)}-${two(dateTimeLocal.day)}';
}

String _formatTime(DateTime dateTimeLocal) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dateTimeLocal.hour)}:${two(dateTimeLocal.minute)}';
}
