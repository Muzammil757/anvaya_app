import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Placeholder for Lecture Mode.
///
/// Owner: Lecture pair — responsible for offline audio/animation-driven
/// lessons for Class 3 Math, delivered in Hindi and Santali.
class LectureScreen extends StatelessWidget {
  const LectureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('Lecture Mode'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppTheme.saffron.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 56,
                  color: AppTheme.saffron,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Lecture Mode',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'This screen is owned by the Lecture pair.\n'
                'It will host offline, narrated Class 3 Math lessons '
                'in Hindi and Santali.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
