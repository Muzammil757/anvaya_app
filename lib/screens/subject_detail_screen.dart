// subject_detail_screen.dart
//
// ANVAYA — Lecture Mode: subject detail (tabbed categories).
//
// Reached by tapping a Subject Card on LectureModeScreen. Math gets 2
// tabs (Rhythmic Chant, Q&A Practice); Language gets 3 (Interactive
// Scene, Rhythmic Chant, Q&A Practice).
//
// UNIVERSAL DRILL-DOWN PATTERN: every tab renders a ListView of
// [_TopicCard]s rather than content directly — the Rhythmic Chant tab
// ([ChantUnitsView]/[_UnitCard]) already worked this way; every other tab
// now matches it, so tapping a topic always pushes a dedicated screen
// rather than some tabs drilling down and others rendering inline.

import 'package:flutter/material.dart';

import '../data/lecture_mode_content.dart';
import '../theme/app_theme.dart';
import 'flashcard_player_screen.dart';
import 'interactive_classroom_view.dart';
import 'orf_reading_screen.dart';

class SubjectDetailScreen extends StatelessWidget {
  const SubjectDetailScreen({super.key, required this.subject, required this.title});

  final LectureSubject subject;
  final String title;

  bool get _isMath => subject == LectureSubject.math;

  @override
  Widget build(BuildContext context) {
    final tabs = _isMath
        ? const [Tab(text: 'Rhythmic Chant'), Tab(text: 'Q&A Practice')]
        : const [Tab(text: 'Interactive Scene'), Tab(text: 'Rhythmic Chant'), Tab(text: 'Q&A Practice')];

    final tabViews = _isMath
        ? const [
            ChantUnitsView(units: mathChantUnits),
            _MathQnAUnitsView(),
          ]
        : const [
            _LanguageInteractiveUnitsView(),
            ChantUnitsView(units: languageChantUnits),
            _LanguageQnAUnitsView(),
          ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(title),
          bottom: TabBar(
            tabs: tabs,
            labelColor: AppTheme.lavenderAccent,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.lavenderAccent,
            labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(child: TabBarView(children: tabViews)),
      ),
    );
  }
}

// =============================================================================
// _TopicCard — the universal drill-down row, reused by every tab below
// =============================================================================

/// A tappable topic row: leading accent icon, title + subtitle, trailing
/// chevron. Same Card/InkWell shape, padding, and (themed, zero) elevation
/// as the Rhythmic Chant tab's [_UnitCard], so every tab's cards look and
/// feel identical regardless of what they drill down into.
class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ChantUnitsView — list of Unit Cards, each opening FlashcardPlayerScreen
// =============================================================================

class ChantUnitsView extends StatelessWidget {
  const ChantUnitsView({super.key, required this.units});

  final List<ChantUnit> units;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: units.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _UnitCard(unit: units[index]),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.unit});

  final ChantUnit unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FlashcardPlayerScreen(unitTitle: unit.title, cards: unit.cards),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.mintContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.style_rounded, color: AppTheme.mintAccent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  unit.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Language, Tab 1 — Interactive Scene: drill-down into Our School / ORF
// =============================================================================

class _LanguageInteractiveUnitsView extends StatelessWidget {
  const _LanguageInteractiveUnitsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _TopicCard(
          title: 'Unit 1: Our School',
          subtitle: 'Interactive Classroom Scene',
          icon: Icons.school_rounded,
          iconColor: AppTheme.mintAccent,
          iconBackground: AppTheme.mintContainer,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _OurSchoolSceneScreen()),
          ),
        ),
        const SizedBox(height: 14),
        _TopicCard(
          title: 'Unit 2: Reading Fluency',
          subtitle: 'Stopwatch ORF Assessment',
          icon: Icons.timer_rounded,
          iconColor: AppTheme.roseAccent,
          iconBackground: AppTheme.roseContainer,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OrfReadingScreen()),
          ),
        ),
      ],
    );
  }
}

/// Hosts [InteractiveClassroomView] as its own pushed screen — that
/// widget is body-content-only (no Scaffold/AppBar of its own, see its
/// file header), so this supplies the AppBar it needs when reached via
/// drill-down rather than embedded directly in a tab.
class _OurSchoolSceneScreen extends StatelessWidget {
  const _OurSchoolSceneScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Our School')),
      body: const InteractiveClassroomView(),
    );
  }
}

// =============================================================================
// QnA drill-down — Math (Division / Multiplication) and Language (General
// Knowledge)
// =============================================================================

class _MathQnAUnitsView extends StatelessWidget {
  const _MathQnAUnitsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _TopicCard(
          title: 'Unit 1: Division Practice',
          subtitle: '${mathDivisionQnAItems.length} questions',
          icon: Icons.calculate_rounded,
          iconColor: AppTheme.skyAccent,
          iconBackground: AppTheme.skyContainer,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const _MathQnAUnitScreen(
                title: 'Division Practice',
                items: mathDivisionQnAItems,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _TopicCard(
          title: 'Unit 2: Multiplication Practice',
          subtitle: '${mathMultiplicationQnAItems.length} questions',
          icon: Icons.grid_view_rounded,
          iconColor: AppTheme.skyAccent,
          iconBackground: AppTheme.skyContainer,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const _MathQnAUnitScreen(
                title: 'Multiplication Practice',
                items: mathMultiplicationQnAItems,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageQnAUnitsView extends StatelessWidget {
  const _LanguageQnAUnitsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _TopicCard(
          title: 'Unit 1: General Knowledge',
          subtitle: 'Basic awareness questions',
          icon: Icons.quiz_rounded,
          iconColor: AppTheme.lavenderAccent,
          iconBackground: AppTheme.lavenderContainer,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const _LanguageQnAUnitScreen(
                title: 'General Knowledge',
                items: languageQnAItems,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The pushed screen for one Math Q&A unit (Division or Multiplication) —
/// same [_MathQnARow] rendering as before, just hosted on its own Scaffold
/// instead of directly inside a TabBarView.
class _MathQnAUnitScreen extends StatelessWidget {
  const _MathQnAUnitScreen({required this.title, required this.items});

  final String title;
  final List<MathQnAItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          itemBuilder: (context, index) => _MathQnARow(item: items[index]),
        ),
      ),
    );
  }
}

/// The pushed screen for the Language Q&A unit — same [_LanguageQnARow]
/// rendering as before, hosted on its own Scaffold.
class _LanguageQnAUnitScreen extends StatelessWidget {
  const _LanguageQnAUnitScreen({required this.title, required this.items});

  final String title;
  final List<LanguageQnAItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          itemBuilder: (context, index) => _LanguageQnARow(item: items[index]),
        ),
      ),
    );
  }
}

/// Math Q&A row: a large numbered question line ("1. Divide 15 ÷ 3"), and
/// a smaller, secondary-colored answer line beneath it. No audio icons.
class _MathQnARow extends StatelessWidget {
  const _MathQnARow({required this.item});

  final MathQnAItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.index}. ${item.verb} ${item.equation}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            // Same accent color _LanguageQnARow uses for its answer line,
            // so both subjects give the answer the same clear visual
            // separation from the question above it.
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Answer: ', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '${item.answerNumber} [${item.answerSantali}]'),
                ],
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.mintAccent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Language (EVS) Q&A row: a numbered question line with its own play
/// button, and an "Answer: ..." line beneath it with a separate play
/// button — a teacher can play either independently.
class _LanguageQnARow extends StatelessWidget {
  const _LanguageQnARow({required this.item});

  final LanguageQnAItem item;

  void _playQuestionAudio() {
    // plays question mp3
    debugPrint('Audio: question mp3 -> "${item.question}"');
  }

  void _playAnswerAudio() {
    // plays answer mp3
    debugPrint('Audio: answer mp3 -> "${item.answer}"');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.index}. ${item.question}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ),
                IconButton(
                  onPressed: _playQuestionAudio,
                  tooltip: 'Play question audio',
                  color: AppTheme.skyAccent,
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Answer: ${item.answer}',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppTheme.mintAccent),
                    ),
                  ),
                  IconButton(
                    onPressed: _playAnswerAudio,
                    tooltip: 'Play answer audio',
                    color: AppTheme.mintAccent,
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
