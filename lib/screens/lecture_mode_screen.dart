// lecture_mode_screen.dart
//
// ANVAYA — Lecture Mode root: a hierarchical, drill-down flow rather than
// the previous single-screen tabbed/swipeable layout.
//
//   LectureModeScreen (this file) — a plain vertical list of Subject Cards.
//     -> SubjectDetailScreen — tabs for that subject's categories.
//          -> ChantUnitsView (one tab) — a list of Unit Cards.
//               -> FlashcardPlayerScreen — the manual/auto slideshow player.
//          -> QnAListView (another tab) — a numbered Q&A list.
//
// See lib/data/lecture_mode_content.dart for all static content, and
// subject_detail_screen.dart / flashcard_player_screen.dart for the rest
// of the flow.

import 'package:flutter/material.dart';

import '../data/lecture_mode_content.dart';
import '../theme/app_theme.dart';
import 'subject_detail_screen.dart';

class LectureModeScreen extends StatelessWidget {
  const LectureModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Lecture Mode')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _SubjectCard(
              subject: LectureSubject.math,
              title: 'Mathematics',
              subtitle: 'Multiplication tables & practice',
              icon: Icons.calculate_rounded,
              accentColor: AppTheme.skyAccent,
              containerColor: AppTheme.skyContainer,
            ),
            SizedBox(height: 16),
            _SubjectCard(
              subject: LectureSubject.language,
              title: 'Language',
              subtitle: 'Santali vocabulary & interactive scenes',
              icon: Icons.translate_rounded,
              accentColor: AppTheme.lavenderAccent,
              containerColor: AppTheme.lavenderContainer,
            ),
          ],
        ),
      ),
    );
  }
}

/// One subject's entry card on the root list — stacked vertically, not
/// swipeable, so it reads as a simple menu rather than a carousel.
class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.containerColor,
  });

  final LectureSubject subject;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SubjectDetailScreen(subject: subject, title: title),
          ),
        ),
        child: Padding(
          // Generous padding keeps the whole row a large, comfortable
          // tablet touch target.
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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
