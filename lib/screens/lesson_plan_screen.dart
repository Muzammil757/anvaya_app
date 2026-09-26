// lesson_plan_screen.dart
//
// ANVAYA — Lesson Plans: a mock weekly curriculum guide matching the
// content actually built into Lecture Mode (4x/5x/6x/7x tables, Days of
// the Week, the "Our School" interactive scene, and the ORF stopwatch
// assessment) — so this reads as a real teaching plan for what the app
// already delivers, not disconnected placeholder text.
//
// The FAB's "Download PDF" builds the exported PDF from the exact same
// _weeks data driving the on-screen ExpansionTiles, rather than a
// separately hardcoded copy, so the two can never drift out of sync.

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';

class LessonPlanScreen extends StatelessWidget {
  const LessonPlanScreen({super.key});

  static const List<_WeekPlan> _weeks = [
    _WeekPlan(
      title: 'Week 1',
      focus: 'Focus: 4 & 5 Tables, Days of the Week',
      bullets: [
        'Introduce equal sharing using the apple-and-basket drag-and-drop manipulative',
        'Practice the 4x and 5x Rhythmic Chant flashcards',
        'Deliver the "Our School" Interactive Classroom Scene',
      ],
    ),
    _WeekPlan(
      title: 'Week 2',
      focus: 'Focus: 6 & 7 Tables, Oral Reading Fluency',
      bullets: [
        'Advanced multiplication practice for the 6x and 7x tables',
        'Conduct the 60-second ORF stopwatch assessment and record WPM',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Lesson Plans')),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: _weeks.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _WeekPlanCard(plan: _weeks[index]),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _downloadPdf,
        icon: const Icon(Icons.picture_as_pdf_rounded),
        label: const Text('Download PDF'),
      ),
    );
  }

  /// Builds a one-page PDF summary of every week in [_weeks] and hands it
  /// to the OS's native print/save dialog — entirely on-device, no
  /// network call.
  Future<void> _downloadPdf() async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(text: 'ANVAYA Lesson Plan'),
              for (final week in _weeks) ...[
                pw.SizedBox(height: 14),
                pw.Text(
                  '${week.title}: ${week.focus}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                for (final bullet in week.bullets) pw.Bullet(text: bullet),
              ],
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }
}

class _WeekPlan {
  const _WeekPlan({required this.title, required this.focus, required this.bullets});

  final String title;
  final String focus;
  final List<String> bullets;
}

class _WeekPlanCard extends StatelessWidget {
  const _WeekPlanCard({required this.plan});

  final _WeekPlan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          plan.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          plan.focus,
          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final bullet in plan.bullets) _buildBulletRow(bullet)],
      ),
    );
  }

  Widget _buildBulletRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: AppTheme.lavenderAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
