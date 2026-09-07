import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'lecture_screen.dart';
import 'qna_screen.dart';
import 'worksheet_screen.dart';

/// The landing screen for ANVAYA.
///
/// Shows an "offline ready" badge and three large mode cards that route
/// into each learning mode.
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ANVAYA'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _OfflineBadge(),
              const SizedBox(height: 24),
              Text(
                'Class 3 Math',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'हिंदी • ᱥᱟᱱᱛᱟᱲᱤ (Santali)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 28),
              _ModeCard(
                title: 'Lecture Mode',
                subtitle: 'Watch and listen to guided Math lessons',
                icon: Icons.play_circle_fill_rounded,
                color: AppTheme.saffron,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LectureScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _ModeCard(
                title: 'Live Q&A Mode',
                subtitle: 'Ask doubts and get instant answers',
                icon: Icons.chat_bubble_rounded,
                color: AppTheme.teal,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QnAScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _ModeCard(
                title: 'Worksheet Mode',
                subtitle: 'Generate and print practice worksheets',
                icon: Icons.description_rounded,
                color: AppTheme.saffronDark,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WorksheetScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.airplanemode_active_rounded,
            size: 18,
            color: AppTheme.tealDark,
          ),
          const SizedBox(width: 8),
          Text(
            '100% Offline / Airplane Mode Ready',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.tealDark,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
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
