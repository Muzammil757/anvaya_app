// lecture_screen.dart
// ANVAYA — Lecture Mode: an expansive, tablet-optimized flashcard lecture
// experience covering foundational vocabulary in Hindi and Santali
// (Ol Chiki), with a play/pause/restart slideshow — synchronized to
// per-card pronunciation audio — that the teacher can drive from a
// floating control deck.
//
// DATA SOURCE: flashcards are no longer hardcoded here — they're loaded at
// runtime from the on-device `vocabulary` SQLite table via
// [DatabaseService.getLectureCards], keyed by each unit's `unit_name`. Only
// the two units' *display chrome* (titles in both scripts, and the
// `unit_name` used to look them up) lives locally, in [lectureUnits] below
// — also reused by unit_selection_screen.dart to list the units — see
// database_service.dart for the actual card content and its seed data, and
// for verification-status caveats on the Ol Chiki placeholder text (Units
// 1-2 have not been checked by a native Santali speaker or FLN curriculum
// expert).
//
// UNIT SELECTION happens one screen up, in UnitSelectionScreen: this
// screen is always launched already scoped to a single unit (read from
// [LectureProgress] in initState), and its AppBar is just that unit's
// title — no in-place picker any more.
//
// AUDIO ASSETS: audioAssetPath values on each loaded card are relative to
// the assets/ folder (audioplayers' AssetSource default prefix), matching
// WAV files bundled directly under assets/audio/ — e.g. 'audio/one.wav'
// resolves to assets/audio/one.wav.
//
// AUDIO IS NEVER AUTOMATIC ON ITS OWN: it only plays when the teacher taps
// Play (immediately, then again on each timer-driven auto-advance) or taps
// a card's phonetics pill on demand. Screen entry, unit switching, manual
// swipes/Prev/Next, and Restart all leave audio silent — see
// _onPageChanged and the play/pause/restart handlers below.
//
// "OUR SCHOOL" IS NO LONGER A FLASHCARD CAROUSEL (Day 2): that unit now
// renders InteractiveClassroomView instead — a tappable illustrated scene —
// while every other unit keeps the flashcard slideshow below unchanged. See
// _buildBody's unit check.
//
// RHYTHMIC CHANT (Day 3): a Numbers-only control deck button that chants
// through all 5 cards for the class to repeat along with. Unlike the
// regular Play slideshow above (which auto-advances on a fixed timer,
// regardless of a clip's actual length), the chant advances only once the
// current card's audio has genuinely finished — driven by
// [AudioPlayer.onPlayerComplete], not a timer — so the page turn is always
// in sync with the pronunciation. See _playChant/_advanceChant/_stopChant.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/archive_log_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'interactive_classroom_view.dart';

/// Display chrome for one Lecture Mode unit — everything needed to list it
/// on UnitSelectionScreen and to fetch its flashcards. [id] doubles as the
/// PageView's rebuild key and the `unit_name` passed to
/// [DatabaseService.getLectureCards].
class LectureUnit {
  const LectureUnit({
    required this.id,
    required this.titleEnglish,
    required this.titleSantali,
  });

  final String id;
  final String titleEnglish;
  final String titleSantali;
}

/// The two foundational units pre-bundled with the app, matching the
/// `unit_name` values seeded into the vocabulary table by
/// [DatabaseService]. Public so unit_selection_screen.dart can list the
/// same units, rather than duplicating this data. See the file-level DATA
/// SOURCE note above.
const List<LectureUnit> lectureUnits = [
  LectureUnit(
    id: 'Numbers',
    titleEnglish: 'Numbers 1 to 5',
    titleSantali: 'ᱞᱮᱠᱷᱟ ᱟᱨ ᱨᱮᱠᱷᱟ',
  ),
  LectureUnit(
    id: 'Our School',
    titleEnglish: 'Our School',
    titleSantali: 'ᱚᱲᱟᱜ ᱨᱮᱭᱟᱜ ᱚᱠᱛᱚ',
  ),
];

/// A small rotating set of avatar icons for non-numeric units (e.g. "Our
/// School"). The vocabulary table has no per-word icon column, so this is
/// applied purely by a card's position within its unit rather than tied to
/// any specific word's meaning.
const List<IconData> _fallbackCardIcons = [
  Icons.menu_book_rounded,
  Icons.edit_note_rounded,
  Icons.face_rounded,
  Icons.record_voice_over_rounded,
  Icons.meeting_room_rounded,
];

/// Tracks the most recently viewed unit/card index across LectureScreen
/// sessions so HomeDashboard's Action Centre can show which unit is
/// active and resume exactly where the teacher left off. Starts at Unit 1
/// ("Numbers 1 to 5"), Card 1, until the teacher opens Lecture Mode and
/// navigates elsewhere.
class LectureProgress {
  LectureProgress._();

  static int unitIndex = 0;
  static int cardIndex = 0;

  /// Card count of the active unit's most recently loaded flashcards, kept
  /// in sync by LectureScreen after every SQLite fetch. Seeded with a sane
  /// placeholder so HomeDashboard's Action Centre has something to show
  /// before Lecture Mode has been opened this session.
  static int totalCards = 5;

  static LectureUnit get unit => lectureUnits[unitIndex];
}

/// Which script is shown large/prominent on each card; the other is shown
/// smaller underneath. Toggled via the AppBar's script button.
enum _ScriptFocus { santali, hindi }

class _LectureScreenState extends State<LectureScreen> {
  static const _slideshowInterval = Duration(milliseconds: 3500);
  static const _autoAdvanceDuration = Duration(milliseconds: 600);
  static const _canvasColor = Color(0xFFF8FAFC);

  PageController _pageController = PageController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _unitIndex = 0;
  int _cardIndex = 0;
  _ScriptFocus _focus = _ScriptFocus.santali;

  bool _isPlaying = false;
  Timer? _slideshowTimer;

  /// True while the Rhythmic Chant (Numbers unit only) is actively running.
  /// Mutually exclusive with [_isPlaying] — starting one stops the other.
  bool _isChanting = false;

  /// Drives the chant's card-to-card advance: fires whenever the current
  /// clip finishes, regardless of what started it. [_advanceChant] is only
  /// called while [_isChanting] is true, so this has no effect on the
  /// regular timer-driven slideshow or a one-off phonetics-pill preview.
  late final StreamSubscription<void> _playerCompleteSubscription;

  /// True only while a *programmatic* page change (the slideshow timer's
  /// own auto-advance, or Restart jumping to card 0) is in flight — used so
  /// [_onPageChanged] can tell that apart from a real user swipe or a
  /// Prev/Next tap, both of which should pause the slideshow.
  bool _suppressAutoPause = false;

  /// The active unit's flashcards, loaded from SQLite. Null while a fetch
  /// is in flight — the very first load, or right after switching units —
  /// during which [build] shows a loading indicator instead of the
  /// slideshow.
  List<VocabularyItem>? _cards;

  /// True once this unit-viewing session has already logged its
  /// "Completed" activity entry — reset in [_loadUnit] so re-opening the
  /// same unit later can log completion again, but reaching the last card
  /// repeatedly within one open doesn't spam duplicate log rows.
  bool _completionLogged = false;

  LectureUnit get _currentUnitMeta => lectureUnits[_unitIndex];

  /// Only valid once [_cards] is non-null — i.e. from within the branch of
  /// [build] that renders the loaded slideshow.
  List<VocabularyItem> get _loadedCards => _cards!;

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
    // Resume exactly where the teacher last left off (defaults to Unit 1,
    // Card 1 the very first time Lecture Mode is ever opened).
    _unitIndex = LectureProgress.unitIndex;
    _cardIndex = LectureProgress.cardIndex;
    _pageController = PageController(initialPage: _cardIndex);
    _loadUnit(initialCardIndex: _cardIndex);
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (_isChanting) _advanceChant();
    });
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _playerCompleteSubscription.cancel();
    _pageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Fetches the active unit's flashcards from SQLite. While the fetch is
  /// in flight, [_cards] is cleared to null so [build] shows a loading
  /// indicator. A fresh [PageController] is created once the data lands —
  /// rather than reusing the old one — because [initialCardIndex] may need
  /// clamping (e.g. a saved card position no longer fits a unit that
  /// shrank), and a PageController's initial page can't be changed after
  /// its PageView has already attached to it.
  Future<void> _loadUnit({int initialCardIndex = 0}) async {
    setState(() {
      _cards = null;
      _completionLogged = false;
    });

    final cards = await DatabaseService.getLectureCards(_currentUnitMeta.id);
    if (!mounted) return;

    final clampedIndex =
        cards.isEmpty ? 0 : initialCardIndex.clamp(0, cards.length - 1);
    final oldController = _pageController;

    setState(() {
      _cards = cards;
      _cardIndex = clampedIndex;
      _pageController = PageController(initialPage: clampedIndex);
    });
    oldController.dispose();

    LectureProgress.totalCards = cards.length;
    _saveProgress();

    if (cards.isNotEmpty) {
      final startedFresh = clampedIndex == 0;
      await ArchiveLogService.logActivity(
        type: ArchiveLogService.typeLecture,
        title: _currentUnitMeta.titleEnglish,
        details: startedFresh
            ? 'Started • Card 1 of ${cards.length}'
            : 'Resumed • Card ${clampedIndex + 1} of ${cards.length}',
      );
      if (clampedIndex == cards.length - 1) {
        _completionLogged = true;
      }
    }
  }

  void _toggleScript() {
    setState(() {
      _focus = _focus == _ScriptFocus.santali
          ? _ScriptFocus.hindi
          : _ScriptFocus.santali;
    });
  }

  /// Persists the current position into [LectureProgress] so
  /// HomeDashboard's Action Centre reflects it as soon as the teacher
  /// returns to the dashboard.
  void _saveProgress() {
    LectureProgress.unitIndex = _unitIndex;
    LectureProgress.cardIndex = _cardIndex;
  }

  /// Prev/Next buttons: a deliberate manual override, so it always pauses
  /// any running slideshow — or chant — first.
  void _goToCard(int index) {
    _pauseSlideshow();
    _stopChant();
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
    _stopChant();
    setState(() => _isPlaying = true);
    _playAudioForCard(_loadedCards[_cardIndex]);
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
    final total = _loadedCards.length;
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
    _stopChant();
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
  /// step, a chant advance, or Restart).
  ///
  /// - A real user-driven change (swipe / Prev / Next — [_suppressAutoPause]
  ///   is false here) always pauses the slideshow (and interrupts any
  ///   running chant) outright and never plays audio, matching "manual
  ///   navigation immediately pauses/interrupts".
  /// - A programmatic change (timer auto-advance, a chant advance, or
  ///   Restart — [_suppressAutoPause] is true) only plays the new card's
  ///   audio when the slideshow or chant is actually still running, i.e.
  ///   it's that mechanism's own step. Restart already sets
  ///   `_isPlaying`/`_isChanting` false before jumping, so this correctly
  ///   stays silent for it.
  void _onPageChanged(int index) {
    final wasProgrammatic = _suppressAutoPause;
    if (!wasProgrammatic) {
      _pauseSlideshow();
      _stopChant();
    }
    setState(() => _cardIndex = index);
    _saveProgress();
    if (wasProgrammatic && (_isPlaying || _isChanting)) {
      _playAudioForCard(_loadedCards[index]);
    }
    if (!_completionLogged && index == _loadedCards.length - 1) {
      _completionLogged = true;
      ArchiveLogService.logActivity(
        type: ArchiveLogService.typeLecture,
        title: _currentUnitMeta.titleEnglish,
        details: 'Completed • ${_loadedCards.length} card${_loadedCards.length == 1 ? '' : 's'} delivered',
      );
    }
  }

  /// Stops whatever's currently playing, then plays [card]'s pronunciation
  /// clip. A missing asset or a playback failure is caught and logged
  /// rather than shown to the teacher, so it never interrupts the lecture.
  Future<void> _playAudioForCard(VocabularyItem card) async {
    await _audioPlayer.stop();
    if (!mounted) return;

    final path = card.audioPath;
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

  /// Starts the Rhythmic Chant: always begins at card 1, then chains
  /// forward — see [_advanceChant], which [_playerCompleteSubscription]
  /// calls once each card's audio genuinely finishes.
  void _playChant() {
    _pauseSlideshow();
    setState(() => _isChanting = true);
    if (_cardIndex == 0) {
      // Already on card 1 — no page transition will fire _onPageChanged
      // to trigger its audio, so start it directly.
      _playAudioForCard(_loadedCards[0]);
    } else {
      _suppressAutoPause = true;
      _pageController
          .animateToPage(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          )
          .then((_) => _suppressAutoPause = false);
    }
  }

  /// Chains to the next card once the current one's audio has finished.
  /// Stops the chant naturally after the last card rather than looping.
  void _advanceChant() {
    final total = _loadedCards.length;
    if (_cardIndex >= total - 1) {
      _stopChant();
      return;
    }
    _suppressAutoPause = true;
    _pageController
        .nextPage(duration: _autoAdvanceDuration, curve: Curves.easeInOutCubic)
        .then((_) => _suppressAutoPause = false);
  }

  /// Stops the chant (audio + further advancing) without touching the
  /// regular slideshow's own state. Safe to call even when not chanting.
  void _stopChant() {
    if (!_isChanting) return;
    _audioPlayer.stop();
    setState(() => _isChanting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        // Unit switching now happens on UnitSelectionScreen, one level up
        // the navigation stack — this screen is always scoped to a single
        // unit (whichever UnitSelectionScreen sent it to), so the AppBar
        // is just a plain title and Flutter's own default back arrow.
        title: Text(_currentUnitMeta.titleEnglish),
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // "Our School" swaps out the flashcard carousel entirely for the
    // tappable interactive scene — it manages its own SQLite fetch/loading
    // state, so this branch skips this screen's own _cards/spinner logic
    // (below) rather than waiting on a load it doesn't need.
    if (_currentUnitMeta.id == 'Our School') {
      return const InteractiveClassroomView();
    }

    final cards = _cards;
    if (cards == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No flashcards found for this unit yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            key: ValueKey(_currentUnitMeta.id),
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) => _buildCard(cards[index], index),
          ),
        ),
        _buildControlDeck(),
      ],
    );
  }

  Widget _buildCard(VocabularyItem card, int index) {
    final isSantaliFocus = _focus == _ScriptFocus.santali;
    final bigText = isSantaliFocus ? card.santaliText : card.hindiText;
    final smallText = isSantaliFocus ? card.hindiText : card.santaliText;
    // Hindi renders fine in the default font — only the Ol Chiki side
    // needs the dedicated font family, whichever role it's playing.
    final bigFontFamily = isSantaliFocus ? 'NotoSansOlChiki' : null;
    final smallFontFamily = isSantaliFocus ? null : 'NotoSansOlChiki';
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
                      child: _buildUpperCanvas(
                        index,
                        containerColor,
                        accentColor,
                      ),
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
  /// corners, filled by the unit's built-in dynamic visual — a counting
  /// grid for the Numbers unit, or a rotating icon avatar otherwise (see
  /// [_fallbackCardIcons]).
  Widget _buildUpperCanvas(int index, Color container, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _canvasColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: _buildVisual(index, container, accent),
      ),
    );
  }

  Widget _buildVisual(int index, Color container, Color accent) {
    if (_currentUnitMeta.id == 'Numbers') {
      return _buildDigitDisplay(index + 1);
    }
    final icon = _fallbackCardIcons[index % _fallbackCardIcons.length];
    return _buildIconAvatar(icon, container, accent);
  }

  /// A clean, standalone digit for the Numbers unit — no bubbles, badges,
  /// or rings, just a bold digit standing prominent on the white stage.
  Widget _buildDigitDisplay(int value) {
    return Text(
      '$value',
      style: const TextStyle(
        fontSize: 130,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
        height: 1,
      ),
    );
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

  /// Lower stage: the Santali/Hindi script pairing (whichever is currently
  /// focused shown large as the hero, the other smaller beneath) and the
  /// tappable phonetics pill. Wrapped in a scroll view as a safety net —
  /// hero text at 60sp should always fit, but this guards against a hard
  /// render overflow rather than risking one on an unusually short or
  /// narrow device.
  Widget _buildLowerStage({
    required VocabularyItem card,
    required String bigText,
    required String smallText,
    required String? bigFontFamily,
    required String? smallFontFamily,
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

  Widget _buildPhoneticPill(VocabularyItem card, Color container, Color accent) {
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
                card.transliteration,
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
    final total = _loadedCards.length;
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
                  if (_currentUnitMeta.id == 'Numbers')
                    IconButton(
                      tooltip: _isChanting ? 'Stop Chant' : 'Start Chant',
                      onPressed: _isChanting ? _stopChant : _playChant,
                      icon: Icon(
                        _isChanting
                            ? Icons.stop_circle_rounded
                            : Icons.campaign_rounded,
                        color: _isChanting ? AppTheme.saffron : accentColor,
                      ),
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
