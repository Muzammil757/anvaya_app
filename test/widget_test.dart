// Basic smoke test for the ANVAYA app shell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anvaya_app/main.dart';

void main() {
  testWidgets('Home dashboard shows offline badge and mode cards',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AnvayaApp());

    expect(find.text('100% Offline / Airplane Mode Ready'), findsOneWidget);
    expect(find.text('Lecture Mode'), findsOneWidget);
    expect(find.text('Live Q&A Mode'), findsOneWidget);
    expect(find.text('Worksheet Mode'), findsOneWidget);
  });

  testWidgets('Tapping Lecture Mode navigates to LectureScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AnvayaApp());

    await tester.tap(find.text('Lecture Mode'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Lecture Mode'), findsOneWidget);
  });
}
