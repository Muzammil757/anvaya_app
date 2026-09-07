import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Placeholder for Live Q&A Mode.
///
/// Owner: Q&A pair — responsible for the on-device question answering
/// experience for Class 3 Math doubts in Hindi and Santali.
class QnAScreen extends StatelessWidget {
  const QnAScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('Live Q&A Mode'),
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
                  color: AppTheme.teal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  size: 48,
                  color: AppTheme.teal,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Live Q&A Mode',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'This screen is owned by the Q&A pair.\n'
                'It will let students ask doubts and get instant, '
                'offline answers in Hindi and Santali.',
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
