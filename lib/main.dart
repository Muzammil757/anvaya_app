import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Needed before touching any plugin (SharedPreferences, sqflite) ahead
  // of runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite's default plugin only ships native implementations for
  // Android/iOS/macOS. Desktop (Windows/Linux) needs the FFI-backed
  // sqlite3 factory swapped in instead, before anything touches
  // DatabaseService.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Checked once on boot so a teacher who already logged in doesn't have
  // to re-enter credentials every cold start — SplashScreen still shows
  // briefly either way, then routes to HomeDashboard directly instead of
  // TeacherAuthScreen. teacher_auth_screen.dart sets this true on a
  // successful login; HomeDashboard's drawer "Log Out" sets it back to
  // false.
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(AnvayaApp(isLoggedIn: isLoggedIn));
}

class AnvayaApp extends StatelessWidget {
  const AnvayaApp({super.key, required this.isLoggedIn});

  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANVAYA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SplashScreen(isLoggedIn: isLoggedIn),
    );
  }
}
