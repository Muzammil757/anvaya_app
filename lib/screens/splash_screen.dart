// splash_screen.dart
// ANVAYA — launch splash.
//
// Shows the logo + "ANVAYA" + tagline together as one static layout from
// the very first frame — no staggered "logo alone, then text catches up"
// entrance animation, which previously read as two separate splash
// screens shown back to back. Holds for _holdDuration, then
// Navigator.pushReplacement straight to TeacherAuthScreen (which itself
// hands off to HomeDashboard on a successful login) — so the splash route
// never lingers in the back stack.

import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'teacher_auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _holdDuration = Duration(milliseconds: 2500);

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(_holdDuration, _goToNext);
  }

  void _goToNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TeacherAuthScreen()),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 152,
              height: 152,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppTheme.softShadow,
              ),
              // The actual ANVAYA brand mark (already has its own
              // circular fill) — not a generic Material icon — so the
              // logo stays the same from the native Android splash
              // through this Dart splash through to the dashboard header.
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Anvaya',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'AI-Powered Foundational Multilingual Learning Suite',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
