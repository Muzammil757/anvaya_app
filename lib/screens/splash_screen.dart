// splash_screen.dart
// ANVAYA — animated launch splash.
//
// Shown for exactly 2000ms total before handing off to HomeDashboard via
// Navigator.pushReplacement (so the splash route never lingers in the back
// stack). The entrance animation itself — icon scale/fade, then title/
// subtitle slide-up/fade — runs over the first 1200ms of that hold.

import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'home_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 1200);
  static const _holdDuration = Duration(milliseconds: 2000);

  late final AnimationController _controller;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );

    // Icon: gentle ease-out scale + fade over the first ~70% of the timeline.
    _iconScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Title + subtitle: slide up from 25% below their resting position,
    // fading in, starting partway through the icon's animation so the two
    // feel sequenced rather than simultaneous.
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _navigationTimer = Timer(_holdDuration, _goToDashboard);
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeDashboard()),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
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
            FadeTransition(
              opacity: _iconFade,
              child: ScaleTransition(
                scale: _iconScale,
                child: Container(
                  width: 152,
                  height: 152,
                  decoration: BoxDecoration(
                    color: AppTheme.lavenderContainer,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    size: 80,
                    color: AppTheme.lavenderAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: _textFade,
              child: SlideTransition(
                position: _textSlide,
                child: Column(
                  children: [
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
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
            ),
          ],
        ),
      ),
    );
  }
}
