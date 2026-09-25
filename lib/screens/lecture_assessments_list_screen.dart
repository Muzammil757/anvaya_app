// lecture_assessments_list_screen.dart
//
// ANVAYA — Lecture Assessments: week-based PDF worksheets generated from
// Lecture Mode content (see lib/data/lecture_mode_content.dart).
//
// Reached from WorksheetScreen's compact "Lecture Mode Assessments" card.
// A Math / Language TabBar separates the weeks by subject rather than
// listing all of them in one flat, mixed list.
// Generating a worksheet here replicates the exact same PDF pipeline the
// Standard Practice Templates section already uses — a plain numbered
// List<String> of prompts pushed into worksheet_screen.dart's
// [TopicWorksheetScreen] (no Hindi/Ol Chiki font embedding needed, since
// none of this content uses those scripts) — rather than inventing a
// second, parallel PDF code path.
//
// "Our School: Needs Practice" is deliberately NOT listed here — that's
// already covered for real by WorksheetScreen's own "Needs Practice — By
// Unit" section (DB-backed via DatabaseService.getItemsForPractice),
// which a tile here would otherwise duplicate as a non-functional stub.

import 'package:flutter/material.dart';

import '../data/lecture_mode_content.dart';
import '../services/archive_log_service.dart';
import '../theme/app_theme.dart';
import 'worksheet_screen.dart' show TopicWorksheetScreen;

class LectureAssessmentsListScreen extends StatelessWidget {
  const LectureAssessmentsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Lecture Assessments'),
          bottom: const TabBar(
            labelColor: AppTheme.lavenderAccent,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.lavenderAccent,
            labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Math'),
              Tab(text: 'Language'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _AssessmentTile(
                    title: 'Week 1: Math (4 Table & Division)',
                    subtitle: '5 randomized fill-in-the-blank problems',
                    onGenerate: () => _generateAndOpen(
                      context,
                      worksheetTitle: 'Week 1: Math Practice',
                      prompts: _generateMathWeek1(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AssessmentTile(
                    title: 'Week 2: Math (5 Table & Multiplication)',
                    subtitle: '5 randomized fill-in-the-blank problems',
                    onGenerate: () => _generateAndOpen(
                      context,
                      worksheetTitle: 'Week 2: Math Practice',
                      prompts: _generateMathWeek2(),
                    ),
                  ),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _AssessmentTile(
                    title: 'Week 1: Language (Days & EVS)',
                    subtitle: '5 randomized fill-in-the-blank prompts',
                    onGenerate: () => _generateAndOpen(
                      context,
                      worksheetTitle: 'Week 1: Language Practice',
                      prompts: _generateLanguageWeek1(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logs the generation to the same Archive/Vault activity trail every
/// other worksheet-generate action feeds (see worksheet_screen.dart's
/// _openTopicWorksheet), then opens the exact same PDF preview/export
/// screen the Standard Practice Templates section uses.
Future<void> _generateAndOpen(
  BuildContext context, {
  required String worksheetTitle,
  required List<String> prompts,
}) async {
  await ArchiveLogService.logActivity(
    type: ArchiveLogService.typeWorksheet,
    title: worksheetTitle,
    details: '${prompts.length} prompt${prompts.length == 1 ? '' : 's'} generated',
  );
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TopicWorksheetScreen(title: worksheetTitle, prompts: prompts),
    ),
  );
}

/// One row: title/subtitle on the left, a "Generate PDF" button on the
/// right. The button deliberately uses no explicit color override — it
/// falls back to the app's themed ElevatedButton style (a single
/// consistent primary color everywhere), rather than a different accent
/// per row.
class _AssessmentTile extends StatelessWidget {
  const _AssessmentTile({
    required this.title,
    required this.subtitle,
    required this.onGenerate,
  });

  final String title;
  final String subtitle;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        // Generous padding + the themed button's own ample padding keep
        // this row comfortable for tablet use.
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onGenerate,
              child: const Text('Generate PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Anti-cheating shuffled/blanked subset generators
// =============================================================================
//
// Pure data-in/data-out helpers pulling from lecture_mode_content.dart —
// no widget/State dependency. Every list is shuffled fresh on each call
// (List.shuffle uses a new unseeded Random internally), then capped to 5
// items, so two teachers generating "the same" worksheet get different
// item orders/subsets each time.

/// Strips a chant equation's answer (e.g. "4 x 3 = 12") down to its blank
/// form ("4 x 3 = _____").
String _blankEquationFromCard(ChantCard card) {
  final equalsIndex = card.english.indexOf('=');
  final leftSide = equalsIndex == -1 ? card.english : card.english.substring(0, equalsIndex).trim();
  return '$leftSide = _____';
}

/// 4x table equations + division Q&A, shuffled, 5 items, answers blanked.
List<String> _generateMathWeek1() {
  final pool = <String>[
    for (final card in mathChantUnits[0].cards) _blankEquationFromCard(card),
    for (final item in mathDivisionQnAItems) '${item.equation} = _____',
  ]..shuffle();
  return pool.take(5).toList();
}

/// 5x table equations + multiplication Q&A, shuffled, 5 items, answers
/// blanked.
List<String> _generateMathWeek2() {
  final pool = <String>[
    for (final card in mathChantUnits[1].cards) _blankEquationFromCard(card),
    for (final item in mathMultiplicationQnAItems) '${item.equation} = _____',
  ]..shuffle();
  return pool.take(5).toList();
}

/// Days of the Week + EVS questions, shuffled, 5 items, each with a blank
/// answer line beneath it.
List<String> _generateLanguageWeek1() {
  final pool = <String>[
    for (final card in languageChantUnits[0].cards)
      'Translate to Santali: ${card.english}\n_________________',
    for (final item in languageQnAItems) '${item.question}\n_________________',
  ]..shuffle();
  return pool.take(5).toList();
}
