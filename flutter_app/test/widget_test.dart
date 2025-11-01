import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dispenser/main.dart';

void main() {
  testWidgets('App test', (WidgetTester tester) async {
    await tester.pumpWidget(const MedicineDispenserApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(UserMedicineManager), findsOneWidget);
  });
}
