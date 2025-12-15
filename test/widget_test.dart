import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:life_tracker/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: LifeTrackerApp()));

    // Wait for splash screen to initialize
    await tester.pump();

    // Verify the app launched
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
