import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const AnvayaApp());
}

class AnvayaApp extends StatelessWidget {
  const AnvayaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANVAYA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
