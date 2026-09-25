// teacher_auth_screen.dart
//
// ANVAYA — Teacher Authentication (offline PIN login).
//
// Strictly local: Teacher ID + 4-digit PIN are checked against a stub
// offline lookup (see [_authenticate]'s doc comment) — no network call
// anywhere in this flow. Once a `teachers` table exists in
// DatabaseService, [_authenticate] is the only place that needs to
// change; everything else in this file is unaffected.
//
// Not currently wired into the app's launch flow (SplashScreen still
// pushes straight to HomeDashboard) — this screen is ready to drop in as
// a gate in front of it whenever that's wanted.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'home_dashboard.dart';

class TeacherAuthScreen extends StatefulWidget {
  const TeacherAuthScreen({super.key});

  @override
  State<TeacherAuthScreen> createState() => _TeacherAuthScreenState();
}

class _TeacherAuthScreenState extends State<TeacherAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teacherIdController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _teacherIdController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  /// Dummy offline credential check standing in for a future
  /// `DatabaseService.getTeacherByIdAndPin(...)` SQLite lookup. Any
  /// non-empty Teacher ID paired with PIN '1234' succeeds — enough for the
  /// screen to have something real to validate against until that table
  /// exists. The artificial delay stands in for the (near-instant) SQLite
  /// round-trip, so the loading state on the button has something to show.
  Future<bool> _authenticate(String teacherId, String pin) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return teacherId.trim().isNotEmpty && pin == '1234';
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting) return;
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final success = await _authenticate(
      _teacherIdController.text,
      _pinController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome to Class 3')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeDashboard()),
      );
    } else {
      setState(() {
        _isSubmitting = false;
        _errorText = 'Incorrect Teacher ID or PIN. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 28),
                    Text(
                      'Teacher Login',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Offline sign-in — no network required',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    _buildAuthCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// App logo placeholder — swap for `Image.asset('assets/images/logo.png')`
  /// once this screen is wired into the real app shell.
  Widget _buildLogo() {
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.lavenderContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: const Icon(Icons.school_rounded, size: 44, color: AppTheme.lavenderAccent),
    );
  }

  Widget _buildAuthCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _teacherIdController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.characters,
              decoration: _fieldDecoration(
                label: 'Teacher ID',
                icon: Icons.badge_outlined,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter your Teacher ID'
                  : null,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _pinController,
              obscureText: true,
              // Number-pad keyboard on tablets/phones for fast PIN entry.
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 4,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: _fieldDecoration(
                label: '4-Digit PIN',
                icon: Icons.lock_outline_rounded,
              ).copyWith(counterText: ''),
              onFieldSubmitted: (_) => _handleLogin(),
              validator: (value) =>
                  (value == null || value.length != 4) ? 'Enter your 4-digit PIN' : null,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorText!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 26),
            // Ample touch target for tablet use.
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleLogin,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Works fully offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required String label, required IconData icon}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppTheme.background,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppTheme.lavenderAccent, width: 1.6),
      ),
    );
  }
}
