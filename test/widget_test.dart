// Basic smoke test for the ANVAYA app shell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anvaya_app/main.dart';

/// Pumps [AnvayaApp] and advances past SplashScreen's exact 2000ms hold, so
/// tests land on HomeDashboard the same way they did before the splash
/// screen was introduced.
Future<void> pumpPastSplash(WidgetTester tester) async {
  await tester.pumpWidget(const AnvayaApp());
  await tester.pump(const Duration(milliseconds: 2100));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'Home tab shows air-gapped chip, context pills, action centre and '
      'the vertical classroom mode cards, with a 2-destination nav bar',
      (WidgetTester tester) async {
    await pumpPastSplash(tester);

    expect(find.text('Namaste, Teacher'), findsOneWidget);
    expect(find.text('Air-Gapped'), findsOneWidget);

    expect(find.text('NIPUN Bharat FLN'), findsOneWidget);
    expect(find.text('Class 3 • Bridge Module'), findsOneWidget);
    expect(find.text('English ⇄ Santali (Ol Chiki)'), findsOneWidget);

    // Defaults to Unit 1 until Lecture Mode has been opened and navigated.
    expect(find.text('Numbers 1 to 5'), findsOneWidget);
    expect(find.text('Resume Unit • Card 1 of 5'), findsOneWidget);
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
    await pumpPastSplash(tester);

    final finder = find.text('Lecture Mode');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();

    // LectureScreen's AppBar shows a unit-selector dropdown (the first
    // unit's title) rather than a static "Lecture Mode" label, so check
    // for the flashcard reader's own content instead.
    expect(find.text('Numbers 1 to 5'), findsOneWidget);
    expect(find.text('Card 1 of 5'), findsOneWidget);
  });

  testWidgets('Tapping Interactive Mode navigates to QnAScreen',
      (WidgetTester tester) async {
    await pumpPastSplash(tester);

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

  testWidgets('Worksheet Engine card navigates to WorksheetScreen, and '
      'Archive / Vault lists the classroom activity log, opening a review '
      'sheet on tap', (WidgetTester tester) async {
    await pumpPastSplash(tester);

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
    expect(find.text('Lecture Delivery Registry'), findsOneWidget);
    expect(find.text('Generated Offline Worksheets'), findsOneWidget);
    expect(find.text('Interactive Session Activity'), findsOneWidget);

    // Tapping an entry opens a read-only review sheet — no navigation away.
    await tester.tap(find.text('Lecture Delivery Registry'));
    await tester.pumpAndSettle();

    expect(find.text('Curriculum Delivery Status'), findsOneWidget);
    expect(find.text('Completed (5/5 Cards)'), findsOneWidget);
    expect(find.text('In Progress (3/5 Cards)'), findsOneWidget);
  });

  testWidgets('Switching back to Home shows the dashboard again',
      (WidgetTester tester) async {
    await pumpPastSplash(tester);

    await tester.tap(find.text('Archive / Vault'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Namaste, Teacher'), findsOneWidget);
  });
}
