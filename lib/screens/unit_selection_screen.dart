// unit_selection_screen.dart
// ANVAYA — Unit Selection: the vertical list of Lecture Mode units a
// teacher picks from before entering LectureScreen. Unit switching used to
// live in LectureScreen's own AppBar dropdown; it now happens here instead
// (see lecture_screen.dart's file header), with LectureScreen always
// launched already scoped to whichever unit was tapped.
//
// Each unit is delivered one of two ways once picked, shown as an "Icon
// Legend" map key at the top so teachers know what to expect before
// tapping in:
//  - Icons.touch_app     — an Interactive Scene (currently just "Our School")
//  - Icons.view_carousel — a Flashcards & Chant carousel (every other unit)

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'lecture_screen.dart';

class UnitSelectionScreen extends StatelessWidget {
  const UnitSelectionScreen({super.key});

  /// Which legend icon represents how [unit] is delivered once opened.
  static IconData _iconFor(LectureUnit unit) {
    return unit.id == 'Our School' ? Icons.touch_app : Icons.view_carousel;
  }

  /// Points LectureScreen at [index] (via the same [LectureProgress] it
  /// already resumes from) and opens it fresh at that unit's first card.
  void _openUnit(BuildContext context, int index) {
    LectureProgress.unitIndex = index;
    LectureProgress.cardIndex = 0;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LectureScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Choose a Unit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _CurriculumBadge()),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _IconLegend(),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: lectureUnits.length,
              itemBuilder: (context, index) {
                final unit = lectureUnits[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _UnitCard(
                    unitNumber: index + 1,
                    unit: unit,
                    icon: _iconFor(unit),
                    onTap: () => _openUnit(context, index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A clean, subtle "map key" so teachers know what each unit's icon means
/// before tapping in. Mint-green throughout — coordinating with the unit
/// cards' own mint icon tiles below, rather than the previous unrelated
/// sky-blue — with each entry as its own separate pill (not just spaced
/// text in a row) so they stay visually distinct even on a narrow phone,
/// and a `Wrap` so they reflow onto two lines rather than crowding
/// together if space is tight.
class _IconLegend extends StatelessWidget {
  const _IconLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.mintContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW UNITS WORK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.mintAccent,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _LegendItem(icon: Icons.touch_app, label: 'Interactive'),
              _LegendItem(icon: Icons.view_carousel, label: 'Flashcards'),
            ],
          ),
        ],
      ),
    );
  }
}

/// A subtle, persistent curriculum-context indicator pinned to the AppBar's
/// top-right corner — deliberately small and separate from the icon legend
/// / units list below, so it reads as passive context chrome rather than
/// another interactive element on the page.
class _CurriculumBadge extends StatelessWidget {
  const _CurriculumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.mintContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Text(
        'NIPUN Bharat FLN',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.mintAccent,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.mintAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// One unit's row in the vertical list: its number, title, and the legend
/// icon for how it's delivered once opened.
class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unitNumber,
    required this.unit,
    required this.icon,
    required this.onTap,
  });

  final int unitNumber;
  final LectureUnit unit;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.mintContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppTheme.mintAccent, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit $unitNumber',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit.titleEnglish,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
