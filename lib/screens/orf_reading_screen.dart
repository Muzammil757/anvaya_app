// orf_reading_screen.dart
//
// ANVAYA — Oral Reading Fluency (ORF) assessment, NIPUN Bharat-aligned.
//
// A teacher starts the stopwatch as a student reads the on-screen passage
// aloud, taps any word the student stumbles on (flagging it red), then
// stops and grades the attempt — producing a Words-Per-Minute score from
// elapsed time, total words, and flagged mistakes. Entirely offline, no
// audio recording or network call involved: it's a manual observation
// tool for the teacher, not automated speech recognition.

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A ~55-word, Class 3-appropriate passage about a school day, pre-split
/// into word tokens (punctuation kept attached) so each one can be
/// individually tapped/flagged.
const List<String> _orfPassage = [
  'Every', 'morning,', 'Meera', 'wakes', 'up', 'early', 'and', 'gets',
  'ready', 'for', 'school.', 'She', 'eats', 'a', 'warm', 'breakfast',
  'with', 'her', 'family', 'before', 'walking', 'to', 'the', 'bus',
  'stop.', 'At', 'school,', 'she', 'greets', 'her', 'friends', 'and',
  'teacher', 'with', 'a', 'smile.', 'During', 'class,', 'she', 'listens',
  'carefully', 'and', 'answers', 'questions.', 'At', 'lunch,', 'she',
  'shares', 'her', 'food', 'and', 'plays', 'happily', 'in', 'the',
  'sunny', 'playground.',
];

class OrfReadingScreen extends StatefulWidget {
  const OrfReadingScreen({super.key});

  @override
  State<OrfReadingScreen> createState() => _OrfReadingScreenState();
}

class _OrfReadingScreenState extends State<OrfReadingScreen> {
  int elapsedSeconds = 0;
  bool isRunning = false;
  final Set<int> flaggedWords = {};

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    if (isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    setState(() => isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => elapsedSeconds++);
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    if (isRunning) setState(() => isRunning = false);
  }

  void _reset() {
    _pauseTimer();
    setState(() {
      elapsedSeconds = 0;
      flaggedWords.clear();
    });
  }

  /// Tapping a word only flags/unflags it once the reading has actually
  /// started — otherwise every word would be trivially tappable before
  /// the student has even begun, which isn't a meaningful mistake.
  void _toggleWord(int index) {
    if (elapsedSeconds == 0) return;
    setState(() {
      if (!flaggedWords.add(index)) {
        flaggedWords.remove(index);
      }
    });
  }

  void _grade() {
    _pauseTimer();

    final totalWords = _orfPassage.length;
    final mistakes = flaggedWords.length;
    final correctWords = totalWords - mistakes;
    // Guard elapsedSeconds == 0 — no time elapsed means no meaningful
    // rate, not a divide-by-zero crash.
    final wpm = elapsedSeconds == 0 ? 0.0 : correctWords / (elapsedSeconds / 60);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => _OrfResultsDialog(
        elapsedSeconds: elapsedSeconds,
        totalWords: totalWords,
        mistakes: mistakes,
        wpm: wpm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Reading Fluency (ORF)')),
      body: SafeArea(
        child: Column(
          children: [
            _buildStopwatch(),
            Expanded(child: _buildReadingArea()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildStopwatch() {
    final minutes = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsedSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: AppTheme.actionCentreDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          const Text(
            'TIME',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: Colors.white54),
          ),
          const SizedBox(height: 4),
          Text(
            '$minutes:$seconds',
            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingArea() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        children: [
          for (var i = 0; i < _orfPassage.length; i++) _buildWordChip(i),
        ],
      ),
    );
  }

  Widget _buildWordChip(int index) {
    final flagged = flaggedWords.contains(index);
    final canTap = elapsedSeconds > 0;

    return GestureDetector(
      onTap: canTap ? () => _toggleWord(index) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: flagged ? const Color(0xFFFCE4E8) : AppTheme.mintContainer,
          borderRadius: BorderRadius.circular(10),
          border: flagged ? Border.all(color: const Color(0xFFE38AA3), width: 1.2) : null,
        ),
        child: Text(
          _orfPassage[index],
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: flagged ? const Color(0xFFB0264A) : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoundIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Reset',
            onPressed: _reset,
          ),
          const SizedBox(width: 22),
          _RoundIconButton(
            icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
            tooltip: isRunning ? 'Pause' : 'Play',
            onPressed: _togglePlayPause,
            accentColor: AppTheme.lavenderAccent,
          ),
          const SizedBox(width: 22),
          _RoundIconButton(
            icon: Icons.check_circle_rounded,
            tooltip: 'Grade',
            onPressed: _grade,
            accentColor: AppTheme.mintAccent,
          ),
        ],
      ),
    );
  }
}

/// A large, tablet-friendly circular icon control. A non-null
/// [accentColor] fills the circle solid with white iconography (the
/// "primary" actions — Play/Pause, Grade); leaving it null renders a
/// plain outlined-on-white button (Reset).
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accentColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final filled = accentColor != null;
    final background = accentColor ?? AppTheme.surface;
    final foreground = filled ? Colors.white : AppTheme.textPrimary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        elevation: filled ? 3 : 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Icon(icon, size: 30, color: foreground),
          ),
        ),
      ),
    );
  }
}

/// The premium results dialog shown when a teacher taps Grade.
class _OrfResultsDialog extends StatelessWidget {
  const _OrfResultsDialog({
    required this.elapsedSeconds,
    required this.totalWords,
    required this.mistakes,
    required this.wpm,
  });

  final int elapsedSeconds;
  final int totalWords;
  final int mistakes;
  final double wpm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppTheme.mintContainer, shape: BoxShape.circle),
              child: const Icon(Icons.emoji_events_rounded, color: AppTheme.mintAccent, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reading Results',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 22),
            _ResultRow(label: 'Time Taken', value: '$elapsedSeconds seconds'),
            const SizedBox(height: 8),
            _ResultRow(label: 'Total Words', value: '$totalWords'),
            const SizedBox(height: 8),
            _ResultRow(label: 'Mistakes', value: '$mistakes'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              wpm.toStringAsFixed(0),
              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: AppTheme.mintAccent, height: 1),
            ),
            const Text(
              'WORDS PER MINUTE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                // TODO: Persist this attempt to the teacher/student
                // profile once that data model exists — for now this just
                // closes the dialog.
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Save to Profile', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      ],
    );
  }
}
