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

  @override
  void initState() {
    super.initState();
    _refreshLocationPermission();
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

      setState(() => _status = 'Checked in successfully.');
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

      setState(() => _status = 'Checked in successfully.');
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
            const Spacer(),
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
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
