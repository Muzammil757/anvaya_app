// interactive_classroom_view.dart
// ANVAYA — Interactive Classroom Scene (Day 2): a tappable illustrated
// classroom backdrop for the "Our School" unit, replacing its basic
// flashcard carousel. Five invisible, subtly-glowing hotspots (Blackboard,
// Teacher, Book, Pencil, School Bag) sit over relative positions within the
// scene image — deliberately not covering the art with solid icons —
// tapping one opens a bottom sheet with audio, Hindi, Santali (Ol Chiki),
// and a "Needs Practice" toggle that feeds the Day 4 Worksheet Generator's
// adaptive loop.
//
// DATA SOURCE: every hotspot's displayed text, audio path, and practice
// status is pulled live from DatabaseService's `vocabulary` table
// (category: 'lecture', unit_name: 'Our School') via
// [DatabaseService.getLectureCards]. Only each hotspot's on-screen
// position and which DB row it maps to (by Hindi label) are hardcoded
// here — see database_service.dart's seed data for the actual vocabulary
// content and its verification-status caveats.
//
// BACKGROUND ASSET: the base layer renders assets/images/classroom_bg_2.jpg
// (a portrait illustration), sized via an AspectRatio(0.75) box so
// BoxFit.cover never crops it — see [_buildScene]. Hotspot positions are
// tuned to this specific image's objects — see [_hotspots].
//
// This widget is body content only — no Scaffold/AppBar of its own — so it
// drops directly into a host screen's body (lecture_screen.dart renders it
// in place of the flashcard carousel when the "Our School" unit is
// selected, reusing that screen's existing AppBar/back navigation).

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../services/archive_log_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// One tappable hotspot on the classroom scene: a fixed relative position
/// plus the Hindi label used to look up its real content from
/// [DatabaseService.getLectureCards]. [label] is UI chrome only (an
/// accessibility tooltip); everything the teacher actually reads or hears
/// comes from the matched [VocabularyItem].
class _Hotspot {
  const _Hotspot({
    required this.label,
    required this.hindiKey,
    required this.leftFactor,
    required this.topFactor,
  });

  final String label;
  final String hindiKey;

  /// Anchor position as a fraction of the scene's own width/height
  /// (0.0-1.0), e.g. `width * leftFactor` — tuned to classroom_bg_2.jpg.
  final double leftFactor;
  final double topFactor;
}

const List<_Hotspot> _hotspots = [
  _Hotspot(
    label: 'Blackboard',
    hindiKey: 'श्यामपट्ट',
    leftFactor: 0.45,
    topFactor: 0.20,
  ),
  _Hotspot(
    label: 'Teacher',
    hindiKey: 'शिक्षक',
    leftFactor: 0.80,
    topFactor: 0.25,
  ),
  _Hotspot(
    label: 'Pencil',
    hindiKey: 'पेंसिल',
    leftFactor: 0.22,
    topFactor: 0.80,
  ),
  _Hotspot(
    label: 'Book',
    hindiKey: 'किताब',
    leftFactor: 0.18,
    topFactor: 0.62,
  ),
  _Hotspot(
    label: 'School Bag',
    hindiKey: 'बस्ता',
    leftFactor: 0.35,
    topFactor: 0.88,
  ),
];

/// Diameter of a hotspot's solid tappable circle. Well above the 48dp
/// minimum touch target so it's easily tappable on government tablets.
const double _hotspotDiameter = 56;

/// Full footprint of a hotspot including its pulsing ring, used to center
/// the widget on its anchor point.
const double _hotspotBoxSize = _hotspotDiameter * 1.8;

class InteractiveClassroomView extends StatefulWidget {
  const InteractiveClassroomView({super.key});

  @override
  State<InteractiveClassroomView> createState() =>
      _InteractiveClassroomViewState();
}

class _InteractiveClassroomViewState extends State<InteractiveClassroomView> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<VocabularyItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await DatabaseService.getLectureCards('Our School');
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  /// Finds the vocabulary row backing [hotspot], matched by its Hindi
  /// label. Null if the seed data doesn't (yet) have a matching row.
  VocabularyItem? _itemFor(_Hotspot hotspot) {
    for (final item in _items) {
      if (item.hindiText.trim() == hotspot.hindiKey) return item;
    }
    return null;
  }

  Future<void> _openHotspotSheet(_Hotspot hotspot, VocabularyItem item) async {
    await ArchiveLogService.logActivity(
      type: ArchiveLogService.typeInteractive,
      title: 'Focus Area: ${hotspot.label}',
      details: '${item.hindiText} — ${item.santaliText}',
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return _HotspotSheet(item: item, audioPlayer: _audioPlayer);
      },
    );
    // The sheet may have toggled needs_practice — refresh so the hotspot's
    // pulse color on the scene reflects the latest status.
    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFocusAreaHeader(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildScene(),
        ),
      ],
    );
  }

  /// Header badge showing how many tappable spots the scene has —
  /// deliberately phrased as "Learning Focus Areas" rather than the
  /// internal "hotspot" term, which is implementation jargon a teacher
  /// shouldn't need to see.
  Widget _buildFocusAreaHeader() {
    final count = _hotspots.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.mintContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.touch_app_rounded, size: 20, color: AppTheme.mintAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count Learning Focus Area${count == 1 ? '' : 's'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScene() {
    // AspectRatio locks the scene to the background image's own portrait
    // proportions, so BoxFit.cover below never has a mismatched box to
    // crop — Center keeps it centered when the available space is wider
    // or taller than that ratio, and SafeArea keeps it clear of any
    // notches/system chrome.
    return SafeArea(
      child: Center(
        child: AspectRatio(
          aspectRatio: 0.75,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              return Stack(
                children: [
                  const Positioned.fill(child: _ClassroomBackground()),
                  for (final hotspot in _hotspots)
                    Positioned(
                      left: width * hotspot.leftFactor - _hotspotBoxSize / 2,
                      top: height * hotspot.topFactor - _hotspotBoxSize / 2,
                      child: _HotspotButton(
                        hotspot: hotspot,
                        item: _itemFor(hotspot),
                        onTap: (item) => _openHotspotSheet(hotspot, item),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The classroom scene's base layer — see the file-level BACKGROUND ASSET
/// note.
class _ClassroomBackground extends StatelessWidget {
  const _ClassroomBackground();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/classroom_bg_2.jpg',
      fit: BoxFit.cover,
    );
  }
}

/// An invisible tappable zone over the illustration, marked only by a
/// subtle pulsing glow outline — so the art underneath stays uncovered.
/// When [item] is null (no matching DB row yet), the zone still renders —
/// for layout stability — but is inert (no tap handler).
class _HotspotButton extends StatefulWidget {
  const _HotspotButton({
    required this.hotspot,
    required this.item,
    required this.onTap,
  });

  final _Hotspot hotspot;
  final VocabularyItem? item;
  final ValueChanged<VocabularyItem> onTap;

  @override
  State<_HotspotButton> createState() => _HotspotButtonState();
}

class _HotspotButtonState extends State<_HotspotButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final needsPractice = item?.needsPractice ?? false;
    // White/yellow glow by default so it reads against most illustrated
    // backdrops; shifts to amber once flagged for practice, echoing the
    // same "needs practice" signal used elsewhere in the app.
    final glowColor = needsPractice ? AppTheme.saffron : const Color(0xFFFFF8DC);

    return Tooltip(
      message: widget.hotspot.label,
      child: GestureDetector(
        onTap: item == null ? null : () => widget.onTap(item),
        child: SizedBox(
          width: _hotspotBoxSize,
          height: _hotspotBoxSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing glow ring — the only visible cue that this spot is
              // tappable, so the illustration itself stays uncovered.
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final t = _pulseController.value;
                  return Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0) * 0.85,
                    child: Transform.scale(
                      scale: 0.7 + t * 0.55,
                      child: Container(
                        width: _hotspotDiameter,
                        height: _hotspotDiameter,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: glowColor.withValues(alpha: 0.95),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withValues(alpha: 0.6),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              // The actual invisible tappable zone — sized well above the
              // 48dp minimum touch target for easy tapping on tablets.
              Container(
                width: _hotspotDiameter,
                height: _hotspotDiameter,
                color: Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bottom sheet opened when a hotspot is tapped: audio, Hindi, Santali
/// + transliteration, and the Needs Practice toggle. Owns its own local
/// `needs_practice` state so the pill updates instantly on tap, in
/// addition to persisting the change via [DatabaseService.toggleNeedsPractice].
class _HotspotSheet extends StatefulWidget {
  const _HotspotSheet({required this.item, required this.audioPlayer});

  final VocabularyItem item;
  final AudioPlayer audioPlayer;

  @override
  State<_HotspotSheet> createState() => _HotspotSheetState();
}

class _HotspotSheetState extends State<_HotspotSheet> {
  late bool _needsPractice = widget.item.needsPractice;
  bool _isTogglingPractice = false;

  /// Only ever called when [VocabularyItem.audioPath] is non-null — see
  /// the audioPath == null branch in [build], which renders a
  /// non-tappable "coming soon" state instead of this button.
  Future<void> _playAudio() async {
    final path = widget.item.audioPath!;
    await widget.audioPlayer.stop();
    if (!mounted) return;

    try {
      await widget.audioPlayer.play(AssetSource(path));
    } catch (e) {
      debugPrint(
        'InteractiveClassroomView: audio playback failed for "$path": $e',
      );
    }
  }

  Future<void> _togglePractice() async {
    if (_isTogglingPractice) return;
    final next = !_needsPractice;
    setState(() {
      _isTogglingPractice = true;
      _needsPractice = next;
    });
    await DatabaseService.toggleNeedsPractice(widget.item.id, next);
    if (!mounted) return;
    setState(() => _isTogglingPractice = false);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),
            if (item.audioPath != null)
              Material(
                color: AppTheme.lavenderContainer,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _playAudio,
                  child: const Padding(
                    padding: EdgeInsets.all(22),
                    child: Icon(
                      Icons.volume_up_rounded,
                      size: 48,
                      color: AppTheme.lavenderAccent,
                    ),
                  ),
                ),
              )
            else
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_off, size: 56, color: Colors.grey),
                  SizedBox(height: 6),
                  Text(
                    '(Audio Coming Soon)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Text(
              item.hindiText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              item.santaliText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                fontFamily: 'NotoSansOlChiki',
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.transliteration,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontStyle: FontStyle.italic,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            _PracticeToggle(
              active: _needsPractice,
              busy: _isTogglingPractice,
              onTap: _togglePractice,
            ),
          ],
        ),
      ),
    );
  }
}

/// The "[Needs Practice]" pill toggle — amber/filled when active, neutral
/// outline otherwise.
class _PracticeToggle extends StatelessWidget {
  const _PracticeToggle({
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        active ? AppTheme.saffron : AppTheme.textSecondary.withValues(alpha: 0.12);
    final foregroundColor = active ? Colors.white : AppTheme.textSecondary;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 20,
                color: foregroundColor,
              ),
              const SizedBox(width: 8),
              Text(
                active ? '[ Needs Practice ✓ ]' : '[ Needs Practice ]',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
