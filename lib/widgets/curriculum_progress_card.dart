// curriculum_progress_card.dart
//
// ANVAYA — "Curriculum Progress" summary card for the Home dashboard.
//
// A compact entry point placed at the top of the Home tab: the active
// class/curriculum label on the left, a "View" action on the right that
// opens the full read-only CurriculumProgressScreen. Purely
// presentational — all real progress data lives in
// CurriculumProgressScreen (eventually backed by SQLite).

import 'package:flutter/material.dart';

import '../screens/curriculum_progress_screen.dart';
import '../theme/app_theme.dart';

class CurriculumProgressCard extends StatelessWidget {
  const CurriculumProgressCard({super.key});

  void _openProgressScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CurriculumProgressScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openProgressScreen(context),
          child: Padding(
            // Generous vertical padding keeps the whole tappable row a
            // comfortably large touch target for tablet use, since the
            // card itself is now the tap target rather than a button.
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.skyContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: AppTheme.skyAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Curriculum Progress: Class 3',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
