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
    expect(find.text('Walkie-Talkie'), findsOneWidget);
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

  testWidgets('Tapping Walkie-Talkie navigates to QnAScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AnvayaApp());

    final finder = find.text('Walkie-Talkie');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Live Q&A Mode'), findsOneWidget);
  });

  testWidgets('Tapping Worksheet Engine navigates to WorksheetScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AnvayaApp());

    final finder = find.text('Worksheet Engine');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Worksheet Mode'), findsOneWidget);
  });

  testWidgets(
      'Switching to the Archive / Vault tab shows the 3 cached items',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AnvayaApp());

    await tester.tap(find.text('Archive / Vault'));
    await tester.pumpAndSettle();

    expect(find.text('Offline Archive & Vault'), findsOneWidget);
    expect(find.text('Class 3 Addition Practice Sheet'), findsOneWidget);
    expect(find.text('Lesson 1 Counting Audio Pack'), findsOneWidget);
    expect(find.text('Recent Walkie-Talkie Session'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Preview'), findsOneWidget);
  });

  testWidgets(
      'Tapping Preview in the Archive / Vault tab navigates to '
      'WorksheetScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const AnvayaApp());

    await tester.tap(find.text('Archive / Vault'));
    await tester.pumpAndSettle();

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
