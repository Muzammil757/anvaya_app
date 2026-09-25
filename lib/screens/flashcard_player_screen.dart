// flashcard_player_screen.dart
//
// ANVAYA — Lecture Mode: the Rhythmic Chant flashcard player.
//
// Reached by tapping a Unit Card in ChantUnitsView. A PageView of
// [ChantCard]s with a bottom controls row:
//   [Prev] [Play] [Next]   ...spacer...   [Slideshow toggle]
//
// - Play only plays the audio for whichever card is currently on screen.
// - Prev/Next manually page one card at a time, and — matching the
//   existing lecture_screen.dart convention elsewhere in this app —
//   interrupt an active slideshow rather than fighting it.
// - The slideshow toggle starts/stops a Timer that auto-advances the
//   PageController every 3 seconds, stopping naturally at the last card.
//
// 100% OFFLINE: _playCurrentCardAudio is a dummy hook (see its body) — no
// network/cloud TTS call. Wire it to a bundled audio asset via
// `audioplayers`, matching the rest of the app, once the clips exist.

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/lecture_mode_content.dart';
import '../theme/app_theme.dart';

class FlashcardPlayerScreen extends StatefulWidget {
  const FlashcardPlayerScreen({super.key, required this.unitTitle, required this.cards});

  final String unitTitle;
  final List<ChantCard> cards;

  @override
  State<FlashcardPlayerScreen> createState() => _FlashcardPlayerScreenState();
}

class _FlashcardPlayerScreenState extends State<FlashcardPlayerScreen> {
  static const _slideshowInterval = Duration(seconds: 3);

  final PageController _pageController = PageController();
  int _currentIndex = 0;
  Timer? _slideshowTimer;
  bool _isSlideshowActive = false;

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Manual navigation always interrupts an active slideshow first, so
  /// the timer's own auto-advance never fights a teacher's manual swipe.
  void _goPrevious() {
    if (_currentIndex == 0) return;
    _stopSlideshow();
    _goToPage(_currentIndex - 1);
  }

  void _goNext() {
    if (_currentIndex == widget.cards.length - 1) return;
    _stopSlideshow();
    _goToPage(_currentIndex + 1);
  }

  /// Plays audio for ONLY the card currently on screen — never the whole
  /// unit — regardless of how that card was reached (swipe, arrow, or
  /// slideshow auto-advance).
  void _playCurrentCardAudio() {
    final card = widget.cards[_currentIndex];
    // TTS: English Audio
    debugPrint('TTS: English Audio -> "${card.english}"');
  }

  void _toggleSlideshow() {
    if (_isSlideshowActive) {
      _stopSlideshow();
    } else {
      _startSlideshow();
    }
  }

  void _startSlideshow() {
    setState(() => _isSlideshowActive = true);
    _slideshowTimer = Timer.periodic(_slideshowInterval, (_) {
      if (_currentIndex >= widget.cards.length - 1) {
        _stopSlideshow();
        return;
      }
      _goToPage(_currentIndex + 1);
    });
  }

  void _stopSlideshow() {
    _slideshowTimer?.cancel();
    _slideshowTimer = null;
    if (_isSlideshowActive) setState(() => _isSlideshowActive = false);
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == widget.cards.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(widget.unitTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Card ${_currentIndex + 1} of ${widget.cards.length}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.cards.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) => _FlashcardView(card: widget.cards[index]),
              ),
            ),
            _buildControlsRow(isFirst: isFirst, isLast: isLast),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsRow({required bool isFirst, required bool isLast}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          _ControlButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Previous card',
            onPressed: isFirst ? null : _goPrevious,
          ),
          const SizedBox(width: 12),
          _ControlButton(
            icon: Icons.play_arrow_rounded,
            tooltip: 'Play this card\'s audio',
            onPressed: _playCurrentCardAudio,
            filled: true,
          ),
          const SizedBox(width: 12),
          _ControlButton(
            icon: Icons.arrow_forward_ios_rounded,
            tooltip: 'Next card',
            onPressed: isLast ? null : _goNext,
          ),
          const Spacer(),
          _ControlButton(
            icon: _isSlideshowActive ? Icons.stop_circle_rounded : Icons.slideshow_rounded,
            tooltip: _isSlideshowActive ? 'Stop slideshow' : 'Start slideshow',
            onPressed: _toggleSlideshow,
            active: _isSlideshowActive,
          ),
        ],
      ),
    );
  }
}

/// The flashcard itself: a well-proportioned elevated card (not full-bleed
/// screen-filling), the English headline, and the Santali translation
/// beneath it.
class _FlashcardView extends StatelessWidget {
  const _FlashcardView({required this.card});

  final ChantCard card;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        // The app-wide CardTheme uses elevation 0 for the pastel, flat
        // look used everywhere else; this screen deliberately overrides
        // it — a lifted, elevated card reads better as a single focal
        // object for classroom visibility from a distance.
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        // clipBehavior so the banner + gradient body below actually
        // respect the Card's own rounded corners instead of drawing
        // square edges over them.
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380, minHeight: 260),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Colorful accent header — labels the card's purpose at a
              // glance rather than leaving the whole card a plain white
              // block.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: AppTheme.lavenderAccent,
                child: const Text(
                  'RHYTHMIC CHANT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: Colors.white,
                  ),
                ),
              ),
              // Soft pastel gradient body instead of a flat white
              // background, so the card reads as a designed object
              // rather than an empty box.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.lavenderContainer, AppTheme.surface],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      card.english,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      card.santali,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.lavenderAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round icon control — sized generously for a tablet touch target.
/// [filled]/[active] pick which accent color fills the circle; a null
/// [onPressed] renders it visibly disabled rather than just inert.
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final baseColor = active
        ? AppTheme.mintAccent
        : filled
            ? AppTheme.lavenderAccent
            : AppTheme.surface;
    final foreground = (active || filled) ? Colors.white : AppTheme.textPrimary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? baseColor : baseColor.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        elevation: (filled || active) ? 2 : 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              icon,
              size: 24,
              color: enabled ? foreground : foreground.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
