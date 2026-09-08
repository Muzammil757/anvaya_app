// lecture_screen.dart
// ANVAYA — Lecture Mode: an expansive, tablet-optimized flashcard lecture
// experience covering foundational vocabulary in Hindi and Santali
// (Ol Chiki), with a play/pause/restart slideshow — synchronized to
// per-card pronunciation audio — that the teacher can drive from a
// floating control deck.
//
// LANGUAGE NOTE: the Ol Chiki *digit glyphs* used in Unit 1 (᱑-᱕) are
// standard Unicode (U+1C51-U+1C55) and are correct regardless of dialect.
// The spelled-out Ol Chiki number words in parentheses, and every other
// Ol Chiki word/phrase and phonetic spelling below (Units 1-2), are
// best-effort placeholders for this prototype, like assets/data/
// qna_scenarios.json's own seed content: NOT verified by a native
// Santali speaker or FLN curriculum expert, and should be reviewed before
// real classroom use.
//
// AUDIO ASSETS: audioAssetPath values below are relative to the assets/
// folder (audioplayers' AssetSource default prefix), matching WAV files a
// teammate has bundled directly under assets/audio/ — e.g. audioAssetPath:
// 'audio/one.wav' resolves to assets/audio/one.wav. The "three" card
// points at assets/audio/three.wav (the file actually bundled), not
// "thee.wav" as originally specified.
//
// AUDIO IS NEVER AUTOMATIC ON ITS OWN: it only plays when the teacher taps
// Play (immediately, then again on each timer-driven auto-advance) or taps
// a card's phonetics pill on demand. Screen entry, unit switching, manual
// swipes/Prev/Next, and Restart all leave audio silent — see
// _onPageChanged and the play/pause/restart handlers below.

import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A single flashcard: one word/concept in both languages, plus whatever
/// built-in visual (a counting grid or an icon avatar) stands in for real
/// artwork until image assets are bundled.
class LectureCard {
  const LectureCard({
    required this.hindiText,
    required this.olChikiText,
    required this.phoneticText,
    this.countValue,
    this.icon,
    this.imageAssetPath,
    this.audioAssetPath,
  });

  final String hindiText;
  final String olChikiText;
  final String phoneticText;

  /// When set, the card shows an interactive counting grid of this many
  /// counters instead of an icon avatar (used by the Numbers unit).
  final int? countValue;

  /// When set (and [countValue] is null), the card shows a large colored
  /// circular avatar containing this icon (used by Classroom Environment
  /// and Foundational Math).
  final IconData? icon;

  /// Path to an illustrative image for this card. Left null for now — no
  /// image assets are bundled yet; when null (or the asset fails to load)
  /// the card falls back to [countValue]'s grid or [icon]'s avatar.
  final String? imageAssetPath;

  /// Path to this card's pronunciation clip, relative to the assets/
  /// folder, e.g. "audio/one.wav" (-> assets/audio/one.wav). See the
  /// file-level AUDIO ASSETS note.
  final String? audioAssetPath;
}

/// A themed set of flashcards, e.g. "Numbers 1-5".
class LectureUnit {
  const LectureUnit({
    required this.id,
    required this.titleHindi,
    required this.titleSantali,
    required this.cards,
  });

  final String id;
  final String titleHindi;
  final String titleSantali;
  final List<LectureCard> cards;
}

/// The three foundational units pre-bundled with the app, chosen to match
/// exactly the 15 pronunciation clips bundled under assets/audio/. See the
/// language note at the top of this file regarding verification status.
const List<LectureUnit> _lectureUnits = [
  LectureUnit(
    id: 'numbers_1_5',
    titleHindi: 'संख्या और गिनती (Numbers 1–5)',
    titleSantali: 'ᱞᱮᱠᱷᱟ ᱟᱨ ᱨᱮᱠᱷᱟ',
    cards: [
      LectureCard(
        hindiText: 'एक',
        olChikiText: '᱑ (ᱢᱤᱫ)',
        phoneticText: "Mit'",
        countValue: 1,
        audioAssetPath: 'audio/one.wav',
      ),
      LectureCard(
        hindiText: 'दो',
        olChikiText: '᱒ (ᱵᱟᱨ)',
        phoneticText: 'Bar',
        countValue: 2,
        audioAssetPath: 'audio/two.wav',
      ),
      LectureCard(
        hindiText: 'तीन',
        olChikiText: '᱓ (ᱯᱮ)',
        phoneticText: 'Pe',
        countValue: 3,
        audioAssetPath: 'audio/three.wav',
      ),
      LectureCard(
        hindiText: 'चार',
        olChikiText: '᱔ (ᱯᱳᱱ)',
        phoneticText: 'Pon',
        countValue: 4,
        audioAssetPath: 'audio/four.wav',
      ),
      LectureCard(
        hindiText: 'पांच',
        olChikiText: '᱕ (ᱢᱚᱬᱮ)',
        phoneticText: 'More',
        countValue: 5,
        audioAssetPath: 'audio/five.wav',
      ),
    ],
  ),
  LectureUnit(
    id: 'classroom_environment',
    titleHindi: 'कक्षा का परिवेश (Classroom Environment)',
    titleSantali: 'ᱚᱲᱟᱜ ᱨᱮᱭᱟᱜ ᱚᱠᱛᱚ',
    cards: [
      LectureCard(
        hindiText: 'किताब / पुस्तक',
        olChikiText: 'ᱯᱩᱛᱷᱤ',
        phoneticText: 'Puthi',
        icon: Icons.menu_book_rounded,
        audioAssetPath: 'audio/book.wav',
      ),
      LectureCard(
        hindiText: 'पेंसिल / कलम',
        olChikiText: 'ᱠᱟᱞᱟᱢ',
        phoneticText: 'Kalam',
        icon: Icons.edit_note_rounded,
        audioAssetPath: 'audio/pencil.wav',
      ),
      LectureCard(
        hindiText: 'छात्र / विद्यार्थी',
        olChikiText: 'ᱯᱟᱹᱴᱷᱩᱣᱟᱹ',
        phoneticText: 'Pathua',
        icon: Icons.face_rounded,
        audioAssetPath: 'audio/student.wav',
      ),
      LectureCard(
        hindiText: 'शिक्षक / गुरुजी',
        olChikiText: 'ᱢᱟᱪᱮᱛ',
        phoneticText: 'Machet',
        icon: Icons.record_voice_over_rounded,
        audioAssetPath: 'audio/teacher.wav',
      ),
      LectureCard(
        hindiText: 'कक्षा / कमरा',
        olChikiText: 'ᱚᱲᱟᱜ',
        phoneticText: "Orak'",
        icon: Icons.meeting_room_rounded,
        audioAssetPath: 'audio/classroom.wav',
      ),
    ],
  ),
];

/// Which script is shown large/prominent on each card; the other is shown
/// smaller underneath. Toggled via the AppBar's script button.
enum _ScriptFocus { santali, hindi }

class _LectureScreenState extends State<LectureScreen> {
  static const _slideshowInterval = Duration(milliseconds: 3500);
  static const _autoAdvanceDuration = Duration(milliseconds: 600);
  static const _canvasColor = Color(0xFFF8FAFC);

  late final PageController _pageController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _unitIndex = 0;
  int _cardIndex = 0;
  _ScriptFocus _focus = _ScriptFocus.santali;

  bool _isPlaying = false;
  Timer? _slideshowTimer;

  /// True only while a *programmatic* page change (the slideshow timer's
  /// own auto-advance, or Restart jumping to card 0) is in flight — used so
  /// [_onPageChanged] can tell that apart from a real user swipe or a
  /// Prev/Next tap, both of which should pause the slideshow.
  bool _suppressAutoPause = false;

  LectureUnit get _currentUnit => _lectureUnits[_unitIndex];

  (Color container, Color accent) get _unitColors {
    switch (_unitIndex) {
      case 0:
        return (AppTheme.mintContainer, AppTheme.mintAccent);
      default:
        return (AppTheme.roseContainer, AppTheme.roseAccent);
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _pageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _selectUnit(int index) {
    if (index == _unitIndex) return;
    _pauseSlideshow();
    setState(() {
      _unitIndex = index;
      _cardIndex = 0;
    });
    _pageController.jumpToPage(0);
  }

  void _toggleScript() {
    setState(() {
      _focus = _focus == _ScriptFocus.santali
          ? _ScriptFocus.hindi
          : _ScriptFocus.santali;
    });
  }

  /// Prev/Next buttons: a deliberate manual override, so it always pauses
  /// any running slideshow first.
  void _goToCard(int index) {
    _pauseSlideshow();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _togglePlay() {
    if (_isPlaying) {
      _pauseSlideshow();
    } else {
      _startSlideshow();
    }
  }

  void _startSlideshow() {
    setState(() => _isPlaying = true);
    _playAudioForCard(_currentUnit.cards[_cardIndex]);
    _slideshowTimer = Timer.periodic(_slideshowInterval, (_) => _autoAdvance());
  }

  /// Stops both the timer and any in-progress pronunciation clip — called
  /// whenever the slideshow explicitly pauses AND, harmlessly/idempotently,
  /// on every card change so nothing ever overlaps with the next clip.
  void _pauseSlideshow() {
    _slideshowTimer?.cancel();
    _slideshowTimer = null;
    _audioPlayer.stop();
    if (_isPlaying) setState(() => _isPlaying = false);
  }

  void _autoAdvance() {
    final total = _currentUnit.cards.length;
    if (_cardIndex >= total - 1) {
      // Reached the last card — stop and reset rather than looping.
      _pauseSlideshow();
      return;
    }
    _suppressAutoPause = true;
    _pageController
        .animateToPage(
          _cardIndex + 1,
          duration: _autoAdvanceDuration,
          curve: Curves.easeInOutCubic,
        )
        .then((_) => _suppressAutoPause = false);
  }

  /// Stops the slideshow (timer + audio + FAB back to Play) and jumps back
  /// to card 0. Deliberately does NOT auto-play — the teacher must tap
  /// Play again to resume audio.
  void _restart() {
    _pauseSlideshow();
    _suppressAutoPause = true;
    _pageController
        .animateToPage(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        )
        .then((_) => _suppressAutoPause = false);
  }

  /// Single consolidated sync point: fires for *every* page change,
  /// whatever caused it (user swipe, Prev/Next, the slideshow timer's own
  /// step, or Restart).
  ///
  /// - A real user-driven change (swipe / Prev / Next — [_suppressAutoPause]
  ///   is false here) always pauses the slideshow outright and never plays
  ///   audio, matching "manual navigation immediately pauses".
  /// - A programmatic change (timer auto-advance or Restart —
  ///   [_suppressAutoPause] is true) only plays the new card's audio when
  ///   the slideshow is actually still playing, i.e. it's the timer's own
  ///   step. Restart already sets `_isPlaying = false` before jumping, so
  ///   this correctly stays silent for it.
  void _onPageChanged(int index) {
    final wasProgrammatic = _suppressAutoPause;
    if (!wasProgrammatic) {
      _pauseSlideshow();
    }
    setState(() => _cardIndex = index);
    if (wasProgrammatic && _isPlaying) {
      _playAudioForCard(_currentUnit.cards[index]);
    }
  }

  /// Stops whatever's currently playing, then plays [card]'s pronunciation
  /// clip. A missing asset or a playback failure is caught and logged
  /// rather than shown to the teacher, so it never interrupts the lecture.
  Future<void> _playAudioForCard(LectureCard card) async {
    await _audioPlayer.stop();
    if (!mounted) return;

    final path = card.audioAssetPath;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio pronunciation is coming soon for this card.'),
        ),
      );
      return;
    }

    try {
      await _audioPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint('LectureScreen: audio playback failed for "$path": $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _unitIndex,
            isExpanded: true,
            dropdownColor: AppTheme.surface,
            icon: const Icon(Icons.expand_more_rounded),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            items: [
              for (var i = 0; i < _lectureUnits.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    _lectureUnits[i].titleHindi,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (index) {
              if (index != null) _selectUnit(index);
            },
          ),
        ),
        actions: [
          IconButton(
            tooltip: _focus == _ScriptFocus.santali
                ? 'Switch focus to Hindi'
                : 'Switch focus to Santali (Ol Chiki)',
            icon: Icon(
              _focus == _ScriptFocus.santali
                  ? Icons.translate_rounded
                  : Icons.abc_rounded,
            ),
            onPressed: _toggleScript,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              key: ValueKey(_currentUnit.id),
              controller: _pageController,
              itemCount: _currentUnit.cards.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) =>
                  _buildCard(_currentUnit.cards[index]),
            ),
          ),
          _buildControlDeck(),
        ],
      ),
    );
  }

  Widget _buildCard(LectureCard card) {
    final isSantaliFocus = _focus == _ScriptFocus.santali;
    final bigText = isSantaliFocus ? card.olChikiText : card.hindiText;
    final smallText = isSantaliFocus ? card.hindiText : card.olChikiText;
    final bigFontFamily =
        isSantaliFocus ? 'NotoSansOlChiki' : 'NotoSansDevanagari';
    final smallFontFamily =
        isSantaliFocus ? 'NotoSansDevanagari' : 'NotoSansOlChiki';
    final (containerColor, accentColor) = _unitColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The flashcard occupies ~80% of the available height — computed
        // from this LayoutBuilder's own constraints (effectively the full
        // screen height minus the thin AppBar/control-deck chrome) rather
        // than a raw MediaQuery height, so it can never overflow its
        // parent even on a short screen.
        final cardHeight = constraints.maxHeight * 0.8;

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 620, maxHeight: cardHeight),
              child: Container(
                width: double.infinity,
                height: cardHeight,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [containerColor, AppTheme.surface],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    ...AppTheme.softShadow,
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.18),
                      blurRadius: 36,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                // No dead space: the upper canvas and lower script stage
                // each claim a fixed proportional share of the card's full
                // height via Expanded flex, instead of a content-hugging
                // Column that leaves empty space around short words.
                child: Column(
                  children: [
                    Expanded(
                      flex: 65,
                      child: _buildUpperCanvas(card, containerColor, accentColor),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      flex: 35,
                      child: _buildLowerStage(
                        card: card,
                        bigText: bigText,
                        smallText: smallText,
                        bigFontFamily: bigFontFamily,
                        smallFontFamily: smallFontFamily,
                        containerColor: containerColor,
                        accentColor: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Upper canvas: a large, high-contrast #F8FAFC stage with rounded
  /// corners, filled by a real image if one is ever bundled, or one of the
  /// built-in dynamic visuals otherwise.
  Widget _buildUpperCanvas(LectureCard card, Color container, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _canvasColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: _buildVisual(card, container, accent, constraints),
        ),
      ),
    );
  }

  Widget _buildVisual(
    LectureCard card,
    Color container,
    Color accent,
    BoxConstraints constraints,
  ) {
    if (card.imageAssetPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          card.imageAssetPath!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => card.countValue != null
              ? _buildCountingGrid(card.countValue!, constraints)
              : _buildIconAvatar(card.icon ?? Icons.image_rounded, container, accent),
        ),
      );
    }
    if (card.countValue != null) {
      return _buildCountingGrid(card.countValue!, constraints);
    }
    return _buildIconAvatar(card.icon ?? Icons.image_rounded, container, accent);
  }

  /// A large (180-200dp), high-contrast colored circular avatar with soft
  /// layered circular backdrops behind a bold, child-friendly icon.
  Widget _buildIconAvatar(IconData icon, Color container, Color accent) {
    const outerSize = 190.0;
    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: container.withValues(alpha: 0.55),
            ),
          ),
          Container(
            width: outerSize * 0.76,
            height: outerSize * 0.76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: container.withValues(alpha: 0.85),
            ),
          ),
          Container(
            width: outerSize * 0.54,
            height: outerSize * 0.54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: container,
              boxShadow: AppTheme.softShadow,
            ),
            child: Icon(icon, size: outerSize * 0.3, color: accent),
          ),
        ],
      ),
    );
  }

  /// A large (70-90dp), vibrant, "bubbly" (glossy radial-gradient
  /// highlight) grid of counters — e.g. 1 circle for count 1, a 2x2 grid
  /// for count 4 — filling the upper canvas, so students can visually
  /// count along instead of just reading the digit.
  Widget _buildCountingGrid(int count, BoxConstraints constraints) {
    const spacing = 16.0;
    final columns = math.sqrt(count).ceil();
    final rows = (count / columns).ceil();

    final availableWidth = constraints.maxWidth - (columns - 1) * spacing;
    final availableHeight = constraints.maxHeight - (rows - 1) * spacing;
    final chipSize = math
        .min(availableWidth / columns, availableHeight / rows)
        .clamp(70.0, 90.0);

    const colors = [
      AppTheme.mintAccent,
      AppTheme.roseAccent,
      AppTheme.skyAccent,
      AppTheme.lavenderAccent,
    ];

    return SizedBox(
      width: columns * chipSize + (columns - 1) * spacing,
      height: rows * chipSize + (rows - 1) * spacing,
      child: GridView.count(
        crossAxisCount: columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(count, (i) {
          return _CountingChip(color: colors[i % colors.length], size: chipSize);
        }),
      ),
    );
  }

  /// Lower stage: the Santali/Hindi script pairing (whichever is currently
  /// focused shown large as the hero, the other smaller beneath) and the
  /// tappable phonetics pill. Wrapped in a scroll view as a safety net —
  /// hero text at 60sp should always fit, but this guards against a hard
  /// render overflow rather than risking one on an unusually short or
  /// narrow device.
  Widget _buildLowerStage({
    required LectureCard card,
    required String bigText,
    required String smallText,
    required String bigFontFamily,
    required String smallFontFamily,
    required Color containerColor,
    required Color accentColor,
  }) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            bigText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 60,
              fontWeight: FontWeight.bold,
              fontFamily: bigFontFamily,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            smallText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              fontFamily: smallFontFamily,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _buildPhoneticPill(card, containerColor, accentColor),
        ],
      ),
    );
  }

  Widget _buildPhoneticPill(LectureCard card, Color container, Color accent) {
    return Material(
      color: container,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _playAudioForCard(card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card.phoneticText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.volume_up_rounded, size: 22, color: accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlDeck() {
    final total = _currentUnit.cards.length;
    final isFirst = _cardIndex == 0;
    final isLast = _cardIndex == total - 1;
    final (_, accentColor) = _unitColors;
    final progress = (_cardIndex + 1) / total;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: 'Restart',
                    onPressed: _restart,
                    icon: const Icon(Icons.replay_rounded),
                  ),
                  IconButton(
                    tooltip: 'Previous',
                    onPressed: isFirst ? null : () => _goToCard(_cardIndex - 1),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: IconButton(
                      tooltip: _isPlaying ? 'Pause slideshow' : 'Play slideshow',
                      onPressed: _togglePlay,
                      iconSize: 32,
                      icon: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: isLast ? null : () => _goToCard(_cardIndex + 1),
                    icon: const Icon(Icons.arrow_forward_ios_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(width: 4),
                  Text(
                    'Card ${_cardIndex + 1} of $total',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: progress),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 8,
                          backgroundColor: AppTheme.background,
                          valueColor: AlwaysStoppedAnimation(accentColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LectureScreen extends StatefulWidget {
  const LectureScreen({super.key});

  @override
  State<LectureScreen> createState() => _LectureScreenState();
}

/// One counter in the counting grid — a glossy, "bubbly" pastel chip (a
/// radial highlight over the base color) with a tap ripple, giving the
/// grid a tactile, interactive feel even though it doesn't track any
/// counting state of its own.
class _CountingChip extends StatelessWidget {
  const _CountingChip({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.6),
      child: Ink(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 1.1,
            colors: [Colors.white.withValues(alpha: 0.6), color],
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {},
        ),
      ),
    );
  }
}
