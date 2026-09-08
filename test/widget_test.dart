// Basic smoke test for the ANVAYA app shell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anvaya_app/main.dart';

void main() {
  testWidgets(
      'Home tab shows air-gapped chip, context pills, action centre and '
      'the vertical classroom mode cards, with a 2-destination nav bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AnvayaApp());

    expect(find.text('Namaste, Teacher'), findsOneWidget);
    expect(find.text('Air-Gapped'), findsOneWidget);

    expect(find.text('Class 3'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Santali (Ol Chiki)'), findsOneWidget);

    expect(find.text('Addition & Counting'), findsOneWidget);
    expect(find.text('Resume Unit'), findsOneWidget);

    expect(find.text('Lecture Mode'), findsOneWidget);
    expect(find.text('Interactive Mode'), findsOneWidget);
    expect(find.text('Worksheet Engine'), findsOneWidget);

    expect(find.byIcon(Icons.menu_rounded), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsNothing);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(2));
  });

  testWidgets('Tapping Lecture Mode navigates to LectureScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AnvayaApp());

    final finder = find.text('Lecture Mode');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Lecture Mode'), findsOneWidget);
  });

  testWidgets('Tapping Interactive Mode navigates to QnAScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AnvayaApp());

    final finder = find.text('Interactive Mode');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    // QnAScreen runs a perpetual mic-pulse animation, so pumpAndSettle()
    // would never terminate here — pump once to dispatch the tap/route
    // push, then a bounded duration to let the push transition finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.widgetWithText(AppBar, 'Interactive Mode'),
      findsOneWidget,
    );

    // Navigate back so QnAScreen's perpetual mic-pulse ticker is disposed
    // here rather than leaking into the next test.
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  });

  // Both WorksheetScreen entry points (the dashboard card and the vault's
  // Preview button) are exercised in a single test. WorksheetScreen loads
  // assets/data/worksheet_content.json via rootBundle on each push; under
  // flutter_test that load only resolves reliably within the *first*
  // testWidgets block that touches it in a given file — a second, separate
  // test block awaiting the same asset key hangs indefinitely. Pushing it
  // twice from within one test (with a pop in between) works fine, so both
  // paths are verified here instead of in separate tests.
  testWidgets(
      'Worksheet Engine card and Archive / Vault Preview both navigate to '
      'WorksheetScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const AnvayaApp());

    final finder = find.text('Worksheet Engine');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Worksheet Mode'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Archive / Vault'));
    await tester.pumpAndSettle();

    expect(find.text('Offline Archive & Vault'), findsOneWidget);
    expect(find.text('Class 3 Addition Practice Sheet'), findsOneWidget);
    expect(find.text('Lesson 1 Counting Audio Pack'), findsOneWidget);
    expect(find.text('Recent Walkie-Talkie Session'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Preview'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Worksheet Mode'), findsOneWidget);
  });

  testWidgets('Switching back to Home shows the dashboard again',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AnvayaApp());

    await tester.tap(find.text('Archive / Vault'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Namaste, Teacher'), findsOneWidget);
  });
}
