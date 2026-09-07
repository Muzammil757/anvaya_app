import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Placeholder for Worksheet Mode.
///
/// Owner: Worksheet pair — responsible for generating and printing/exporting
/// practice worksheets (PDF) for Class 3 Math in Hindi and Santali.
class WorksheetScreen extends StatelessWidget {
  const WorksheetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('Worksheet Mode'),
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
                  Icons.description_rounded,
                  size: 48,
                  color: AppTheme.saffron,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Worksheet Mode',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'This screen is owned by the Worksheet pair.\n'
                'It will generate printable Class 3 Math practice '
                'sheets in Hindi and Santali.',
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
