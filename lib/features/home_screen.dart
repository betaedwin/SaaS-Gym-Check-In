import 'package:flutter/material.dart';

import 'checkin/checkin_screen.dart';
import 'profile/profile_screen.dart';
import 'schedule/schedule_screen.dart';

/// Simple bottom-nav shell shown after authentication.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _screens = [
    CheckInScreen(),
    ProfileScreen(),
    ScheduleScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.qr_code), label: 'Check-In'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.event_note), label: 'Schedule'),
        ],
      ),
    );
  }
}

