import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saas_gym_check_in/features/checkin/checkin_screen.dart';

void main() {
  testWidgets('Check-in screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CheckInScreen()));
    expect(find.text('Check In'), findsOneWidget);
  });
}
