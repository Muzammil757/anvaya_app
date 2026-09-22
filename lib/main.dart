import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  // sqflite's default plugin only ships native implementations for
  // Android/iOS/macOS. Desktop (Windows/Linux) needs the FFI-backed
  // sqlite3 factory swapped in instead, before anything touches
  // DatabaseService.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
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
