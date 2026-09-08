// qna_screen.dart
// ANVAYA — Interactive Mode (Instruction Board)
//
// A teacher speaks or types a classroom instruction in Hindi; Gemini
// translates it into Santali (Ol Chiki), and the bilingual instruction card
// is added to a persistent, timestamped board. The board is saved to
// SharedPreferences as a JSON list, so past instructions (with their
// original timestamps) are still there the next time the app opens.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:anvaya_app/theme/app_theme.dart';
import 'package:anvaya_app/services/ai_curriculum_service.dart';

enum _BoardState { idle, recording, translating }

class QnAScreen extends StatefulWidget {
  const QnAScreen({super.key});

  @override
  State<QnAScreen> createState() => _QnAScreenState();
}

class _QnAScreenState extends State<QnAScreen>
    with SingleTickerProviderStateMixin {
  static const _prefsKey = 'anvaya_interactive_mode_board_v1';

  _BoardState _state = _BoardState.idle;
  late AnimationController _pulseController;
  final SpeechToText _speech = SpeechToText();
  bool _speechEnabled = false;
  List<Map<String, dynamic>> _instructions = [];
  bool _isLoadingHistory = true;

  /// True while a mic/typed instruction is in flight (translating and
  /// being saved). Guards against double-tap bursts on the mic and the
  /// typed dialog's Send button firing a second overlapping request.
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadHistory();
    _initSpeech();
  }

  /// Loads the persisted instruction board from SharedPreferences (a JSON
  /// list of {hindi_text, santali_text, transliteration, timestamp}).
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _instructions =
            decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('QnAScreen: could not load instruction history: $e');
    }
    if (mounted) setState(() => _isLoadingHistory = false);
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_instructions));
    } catch (e) {
      debugPrint('QnAScreen: could not save instruction history: $e');
    }
  }

  Future<void> _clearBoard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear Board?'),
        content: const Text(
          'This removes every saved instruction from this device. This '
          'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _instructions = []);
    await _saveHistory();
  }

  /// Initializes the on-device speech recognizer used for live Hindi input
  /// on the mic button. If unavailable (no permission, unsupported device,
  /// simulator, etc.) the mic falls back to opening the typed-input dialog.
  ///
  /// SpeechToText() is a process-wide singleton (see its `factory`
  /// constructor), and its `initialize()` is a one-time no-op after the
  /// first successful call — it returns the cached result WITHOUT
  /// rebinding `statusListener`/`errorListener` to whichever State instance
  /// called it. Left alone, a previous (now-disposed) QnAScreen's stale
  /// closures would keep driving the singleton's callbacks forever, which
  /// is exactly what caused the mic to hang on "Keep speaking..." after
  /// navigating away and back. So: cancel any leftover session from a prior
  /// instance, then explicitly rebind both listener fields ourselves every
  /// time this screen mounts, regardless of whether `initialize()` actually
  /// ran its internal setup this time.
  Future<void> _initSpeech() async {
    bool available = false;
    try {
      await _speech.cancel();
      available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );
      _speech.statusListener = _handleSpeechStatus;
      _speech.errorListener = _handleSpeechError;
    } catch (e) {
      debugPrint('QnAScreen: speech initialize failed: $e');
    }
    if (mounted) setState(() => _speechEnabled = available);
  }

  void _handleSpeechStatus(String status) {
    debugPrint('QnAScreen: speech status: $status');
    // The recognizer stopped (e.g. silence for the full listenFor/pauseFor
    // window) without ever producing a final result — don't leave the mic
    // stuck showing "recording".
    if ((status == 'notListening' || status == 'done') &&
        _state == _BoardState.recording &&
        mounted) {
      setState(() => _state = _BoardState.idle);
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    debugPrint('QnAScreen: speech error: $error');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Both stop() and cancel() are called so no listen session — and no
    // pending final-result timer — survives this screen, whether the mic
    // was actively recording or idle when the user navigated away.
    _speech.stop();
    _speech.cancel();
    super.dispose();
  }

  /// Push-to-talk: starts live Hindi speech recognition. Falls back to the
  /// typed-input dialog if the recognizer isn't available on this device.
  void _onPressStart() {
    // Belt-and-braces double-tap guard, on top of the _state check below —
    // _isSubmitting stays true for the full translate+save round trip,
    // covering the brief window where _state may already be back to idle
    // but a save is still in flight.
    if (_isSubmitting || _state != _BoardState.idle) return;
    if (!_speechEnabled) {
      _showTypedFallbackDialog();
      return;
    }
    setState(() => _state = _BoardState.recording);
    _speech.listen(
      // Only ever act on the final result — either the recognizer decides
      // the sentence is complete (silence for pauseFor, or listenFor
      // elapses), or the user releases/re-taps the mic, which calls stop()
      // below and itself produces a final result through this same
      // callback. Partial results are ignored so the AI call only ever
      // fires once per utterance, on the full captured sentence.
      onResult: (result) {
        if (result.finalResult) {
          _handleRecognizedSpeech(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: 'hi_IN',
        listenMode: ListenMode.dictation,
        // Natural speech pauses shouldn't cut the sentence off early.
        pauseFor: const Duration(seconds: 3),
        // Upper bound so a stuck/forgotten mic can't listen forever.
        listenFor: const Duration(seconds: 20),
      ),
    );
  }

  /// Manually stops listening (e.g. the user tapped/released the mic again).
  /// stop() causes the recognizer to deliver a final result through the
  /// same onResult callback passed to listen() above, so this doesn't need
  /// to trigger the AI call itself.
  void _onPressEnd() {
    if (_state != _BoardState.recording) return;
    _speech.stop();
  }

  Future<void> _handleRecognizedSpeech(String spokenText) async {
    final trimmed = spokenText.trim();
    if (trimmed.isEmpty) {
      if (mounted) setState(() => _state = _BoardState.idle);
      return;
    }
    await _submitInstruction(trimmed);
  }

  /// Quick text-input fallback for loud classrooms or when speech
  /// recognition isn't available — types a Hindi instruction and runs it
  /// through the same live translation pipeline as the mic.
  ///
  /// The ScaffoldMessenger is captured *before* the dialog is shown and
  /// threaded through to `_handleInstructionSubmit` rather than re-derived
  /// via `ScaffoldMessenger.of(context)` after the dialog closes and the AI
  /// call completes. Re-deriving it that late — across the dialog's pop and
  /// an async gap — can look up a context whose element is mid-deactivation
  /// and throw a `_dependents.isEmpty` assertion (the Flutter "red screen"
  /// crash). Capture once, reuse everywhere below; never hold onto
  /// `dialogContext` past its own Cancel/Send handlers.
  Future<void> _showTypedFallbackDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Type an instruction'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. अपनी किताबें पन्ना पाँच पर खोलिए',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            // Disabled if a submission from elsewhere (e.g. the mic) is
            // already in flight when this dialog is opened — prevents a
            // second overlapping request from a double-tap burst.
            onPressed: _isSubmitting
                ? null
                : () {
                    final text = controller.text.trim();
                    // Close the dialog first — dialogContext must never be
                    // used again after this, especially not across the
                    // async AI call _handleInstructionSubmit is about to
                    // kick off.
                    Navigator.of(dialogContext).pop();
                    if (text.isNotEmpty) {
                      _handleInstructionSubmit(text, messenger);
                    }
                  },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  /// Delegate for the typed-instruction dialog's Send button. Runs entirely
  /// after the dialog has already been popped, using the [messenger]
  /// captured by [_showTypedFallbackDialog] before the dialog was shown.
  Future<void> _handleInstructionSubmit(
    String text,
    ScaffoldMessengerState messenger,
  ) async {
    if (!mounted) return;
    await _submitInstruction(text, messenger: messenger);
  }

  /// Live pipeline shared by the mic and the typed fallback: translates the
  /// Hindi instruction to Santali via Gemini, then adds it to the top of
  /// the instruction board and persists the board to SharedPreferences.
  ///
  /// [messenger] lets callers (like the typed-input dialog) pass in a
  /// ScaffoldMessenger captured before an async gap, instead of this method
  /// re-deriving one via `ScaffoldMessenger.of(context)` after the await
  /// below — see [_showTypedFallbackDialog] for why that matters. The mic
  /// path has no such gap to worry about, so it can omit it.
  ///
  /// Wrapped in try/finally so `_isSubmitting` always clears, re-enabling
  /// the mic and the typed dialog's Send button no matter how this ends.
  ///
  /// [AiCurriculumService.translateDialogue] now guarantees a renderable
  /// result on its own — it falls back to a known routine-command match or
  /// an honest offline placeholder internally rather than returning null on
  /// failure — so in practice this never falls into the `result == null`
  /// branch below. That branch is kept only as a defensive last resort
  /// (the return type is still nullable), not as the primary fallback path.
  Future<void> _submitInstruction(
    String hindiText, {
    ScaffoldMessengerState? messenger,
  }) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _state = _BoardState.translating;
    });

    try {
      final result = await AiCurriculumService.translateDialogue(
        text: hindiText,
        fromLang: 'Hindi',
        toLang: 'Santali',
      );

      if (!mounted) return;

      if (result == null) {
        setState(() => _state = _BoardState.idle);
        (messenger ?? ScaffoldMessenger.of(context)).showSnackBar(
          SnackBar(
            content: Text(
              'AI translation failed: ${AiCurriculumService.lastError ?? 'Unknown error'}',
            ),
          ),
        );
        return;
      }

      setState(() {
        _state = _BoardState.idle;
        _instructions.insert(0, {
          'hindi_text': hindiText,
          'santali_text': result['translated_text'] ?? '',
          'transliteration': result['transliteration'] ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
      await _saveHistory();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Interactive Mode'),
            Text(
              'Classroom Instruction & Assignment Board',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: AppTheme.lavenderAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_alt_outlined),
            tooltip: 'Type an instruction instead',
            onPressed: () => _showTypedFallbackDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear Board',
            onPressed: () => _clearBoard(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBoard()),
          _buildStatusStrip(),
          _buildMicButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.lavenderAccent),
      );
    }

    final Widget content = _instructions.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Hold the mic to give an instruction.\n'
                'It will appear here in Hindi and Santali for the class.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
            ),
          )
        : ListView.builder(
            // Extra bottom padding keeps the last card clear of the
            // floating mic button.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            itemCount: _instructions.length,
            itemBuilder: (context, index) =>
                _buildInstructionCard(_instructions[index]),
          );

    // Tablet-optimized container — caps card width so a classroom tablet
    // (or a phone in landscape) doesn't stretch cards edge-to-edge.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: content,
      ),
    );
  }

  Widget _buildInstructionCard(Map<String, dynamic> entry) {
    final hindiText = entry['hindi_text'] as String? ?? '';
    final santaliText = entry['santali_text'] as String? ?? '';
    final transliteration = entry['transliteration'] as String? ?? '';
    final timestampRaw = entry['timestamp'] as String?;
    final timestamp =
        timestampRaw != null ? DateTime.tryParse(timestampRaw) : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.mintContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(color: AppTheme.mintAccent, width: 5),
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: instruction label on the left, date/time chip on the
          // right. Both sides are wrapped in Flexible with ellipsis
          // overflow — under a larger accessibility text scale (or a very
          // narrow phone) the label + chip can together exceed the card's
          // width; without this the Row throws a RenderFlex overflow
          // instead of gracefully truncating.
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.campaign_rounded,
                      size: 16,
                      color: AppTheme.mintAccent,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Instruction',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.mintAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (timestamp != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _formatTimestamp(timestamp),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Hindi section.
          Text(
            hindiText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Santali section — large and high-contrast so it's readable from
          // across a classroom desk.
          Text(
            santaliText,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'NotoSansOlChiki',
              color: AppTheme.textPrimary,
            ),
          ),

          // Phonetic section — a romanized reading guide for non-native
          // Santali-speaking teachers.
          if (transliteration.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                transliteration,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Formats a timestamp like "08 Sep • 10:15 AM".
  String _formatTimestamp(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = _months[dt.month - 1];
    var hour12 = dt.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour < 12 ? 'AM' : 'PM';
    return '$day $month • $hour12:$minute $amPm';
  }

  Widget _buildStatusStrip() {
    String label;
    switch (_state) {
      case _BoardState.idle:
        label = 'Ready — hold the mic to give an instruction';
        break;
      case _BoardState.recording:
        label = 'Listening...';
        break;
      case _BoardState.translating:
        label = 'Translating with Gemini...';
        break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Padding(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTapDown: (_) => _onPressStart(),
      onTapUp: (_) => _onPressEnd(),
      onTapCancel: _onPressEnd,
      // Visually disabled while a submission is in flight, matching the
      // functional guard in _onPressStart.
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _isSubmitting ? 0.4 : 1.0,
        child: Column(
        children: [
          if (_state == _BoardState.recording) _buildWaveform(),
          if (_state == _BoardState.translating) _buildProcessingSpinner(),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _state == _BoardState.recording
                  ? 1.0 + (_pulseController.value * 0.08)
                  : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _micColor(),
                boxShadow: [
                  BoxShadow(
                    color: _micColor().withValues(alpha: 0.4),
                    blurRadius: 18,
                    spreadRadius: _state == _BoardState.recording ? 6 : 0,
                  ),
                ],
              ),
              child: Icon(
                _state == _BoardState.recording ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Color _micColor() {
    switch (_state) {
      case _BoardState.recording:
        return const Color(0xFFC0392B);
      case _BoardState.translating:
        return const Color(0xFFB8860B);
      case _BoardState.idle:
        return AppTheme.lavenderAccent;
    }
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(9, (i) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final height = 8 +
                  16 *
                      (0.5 +
                          0.5 *
                              (1 +
                                      (_pulseController.value * 2 - 1) *
                                          (i.isEven ? 1 : -1))
                                  .abs() /
                              2);
              return Container(
                width: 4,
                height: height.clamp(6, 30),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFC0392B),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildProcessingSpinner() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFFB8860B),
        ),
      ),
    );
  }
}
