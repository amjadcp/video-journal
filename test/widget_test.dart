import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_journal/main.dart';

void main() {
  testWidgets('JournalApp initial boot test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: JournalApp(),
      ),
    );

    // Verify that the title 'Visual Journal' is rendered in the AppBar.
    expect(find.text('Visual Journal'), findsOneWidget);
  });
}
