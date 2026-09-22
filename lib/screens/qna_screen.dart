// qna_screen.dart
// ANVAYA — Interactive Mode (100% Offline with Local Audio & Bilingual Display)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:anvaya_app/theme/app_theme.dart';
import 'package:anvaya_app/services/archive_log_service.dart';

enum _BoardState { idle, recording, processing }

class QnAScreen extends StatefulWidget {
  const QnAScreen({super.key});

  @override
  State<QnAScreen> createState() => _QnAScreenState();
}

class _QnAScreenState extends State<QnAScreen>
    with SingleTickerProviderStateMixin {
  static const _prefsKey = 'anvaya_interactive_mode_board_v3';

  _BoardState _state = _BoardState.idle;
  late AnimationController _pulseController;
  final SpeechToText _speech = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _speechEnabled = false;
  List<Map<String, dynamic>> _instructions = [];
  bool _isLoadingHistory = true;
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
        content: const Text('This removes every saved instruction. Cannot be undone.'),
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
    if ((status == 'notListening' || status == 'done') &&
        _state == _BoardState.recording &&
        mounted) {
      setState(() => _state = _BoardState.idle);
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (mounted) {
      setState(() => _state = _BoardState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mic offline. Please use the keyboard icon to type.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    _speech.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onPressStart() {
    if (_isSubmitting || _state != _BoardState.idle) return;
    if (!_speechEnabled) {
      _showTypedFallbackDialog();
      return;
    }
    setState(() => _state = _BoardState.recording);
    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _handleRecognizedSpeech(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        // Indian English locale — previously 'hi_IN', which forced the
        // native STT engine to transliterate spoken English into
        // Devanagari script (e.g. "keep quiet" -> "कीप क्वाइट"), so it
        // never matched the English entries in our keyword dictionary.
        // en_IN keeps English speech in Latin script while still
        // recognizing Indian-accented pronunciation correctly.
        localeId: 'en_IN',
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 20),
      ),
    );
  }

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

  Future<void> _showTypedFallbackDialog() async {
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
            hintText: 'e.g. Look at the board / बोर्ड देखिए',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    final text = controller.text.trim();
                    Navigator.of(dialogContext).pop();
                    if (text.isNotEmpty) {
                      _submitInstruction(text);
                    }
                  },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  // Keyword sets per command — deliberately generous (multiple English
  // synonyms + multiple Hindi word roots each) since real spoken/typed
  // input rarely matches a single exact word. Hindi entries use word
  // *roots* (e.g. 'खोल' for खोलो/खोलिए, 'पढ़' for पढ़ो/पढ़िए) so common
  // conjugations all match via plain substring containment — matching
  // "please be quiet" or "quiet please" already works the same way, since
  // `contains` doesn't care where in the string the keyword falls.
  static const _boardKeywords = [
    'board', 'blackboard', 'chalkboard', 'look', 'watch', 'see', 'front',
    'बोर्ड', 'श्यामपट्ट', 'ब्लैकबोर्ड', 'देख', 'लुक', 'निहार', 'सामने',
  ];
  static const _slateKeywords = [
    'slate', 'write', 'writing', 'copy',
    'स्लेट', 'लिख', 'लिखो', 'लिखिए', 'नकल',
  ];
  static const _bookKeywords = [
    'book', 'books', 'open', 'notebook', 'textbook',
    'किताब', 'पुस्तक', 'बुक', 'खोल', 'खोलो', 'खोलिए',
  ];
  static const _readKeywords = [
    'read', 'reading', 'aloud', 'recite', 'loudly',
    'पढ़', 'पढ़ो', 'पढ़िए', 'पाठ', 'वाचन', 'जोर से',
  ];
  static const _quietKeywords = [
    'quiet', 'silence', 'silent', 'hush', 'shush', 'shh', 'settle down',
    'शांत', 'चुप', 'खामोश', 'चुप्पी', 'शांति',
  ];
  static const _standKeywords = [
    'stand', 'stand up', 'rise', 'get up', 'stand tall',
    'खड़े', 'खड़ा', 'खड़ी', 'उठ', 'उठो', 'उठिए',
  ];

  bool _matchesAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  /// Maps transcribed/typed text (English or Hindi, mic or manual) to one
  /// of the 6 offline commands — shared by [_submitInstruction] (which
  /// stores the resulting audioPath and english label on the entry) and
  /// reused implicitly by every card's replay button, which replays that
  /// stored path rather than re-matching the text.
  ({String english, String santali, String translit, String audioPath}) _matchCommand(
    String inputText,
  ) {
    final lower = inputText.toLowerCase();

    if (_matchesAny(lower, _boardKeywords)) {
      return (
        english: 'Look at the Board',
        santali: 'ᱵᱚᱨᱰ ᱧᱮᱞ',
        translit: 'bord nyel',
        audioPath: 'audio/instructions/cmd_look_board.mp3',
      );
    }
    if (_matchesAny(lower, _slateKeywords)) {
      return (
        english: 'Write on Slate',
        santali: 'ᱥᱞᱮᱴ ᱨᱮ ᱚᱞ',
        translit: 'slate re ol',
        audioPath: 'audio/instructions/cmd_write_slate.mp3',
      );
    }
    if (_matchesAny(lower, _bookKeywords)) {
      return (
        english: 'Open Your Book',
        santali: 'ᱯᱚᱛᱚᱵ ᱡᱷᱤᱡᱽ ᱢᱮ',
        translit: 'potob jhij me',
        audioPath: 'audio/instructions/cmd_open_book.mp3',
      );
    }
    if (_matchesAny(lower, _readKeywords)) {
      return (
        english: 'Read Aloud',
        santali: 'ᱜᱟᱹᱴᱮ ᱛᱮ ᱯᱟᱲᱦᱟᱣ ᱢᱮ',
        translit: 'gate te padhaw me',
        audioPath: 'audio/instructions/cmd_read_aloud.mp3',
      );
    }
    if (_matchesAny(lower, _quietKeywords)) {
      return (
        english: 'Keep Quiet',
        santali: 'ᱛᱷᱤᱨ ᱛᱟᱦᱮᱸᱱ ᱯᱮ',
        translit: 'thir tahen pe',
        audioPath: 'audio/instructions/cmd_be_quiet.mp3',
      );
    }
    if (_matchesAny(lower, _standKeywords)) {
      return (
        english: 'Stand Up',
        santali: 'ᱛᱤᱸᱜᱩᱱ ᱯᱮ',
        translit: 'tingun pe',
        audioPath: 'audio/instructions/cmd_stand_up.mp3',
      );
    }
    return (
      english: 'Command Not Recognized',
      santali: 'ᱵᱟᱹᱧ ᱵᱩᱡᱷᱟᱹᱣ ᱞᱮᱫᱟ',
      translit: 'banj bujhau leda',
      audioPath: '',
    );
  }

  /// Plays [audioPath] via the shared [_audioPlayer] — used both for the
  /// automatic playback when an instruction is first submitted and for
  /// each card's manual replay button, so both paths behave identically.
  /// Stops any clip already playing first so rapid taps don't overlap.
  /// A no-op for a blank path (the "command not recognized" fallback has
  /// no mapped clip, as does any pre-replay-button saved entry).
  Future<void> _replayAudio(String? audioPath) async {
    if (audioPath == null || audioPath.isEmpty) return;
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(audioPath));
    } catch (e) {
      debugPrint('Audio failed to play: $e');
    }
  }

  Future<void> _submitInstruction(String inputText) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _state = _BoardState.processing;
    });

    try {
      final match = _matchCommand(inputText);
      await _replayAudio(match.audioPath);

      // Only log genuinely recognized commands — a blank audioPath marks
      // the "Command Not Recognized" fallback, which isn't real activity
      // worth surfacing in the Archive / Vault.
      if (match.audioPath.isNotEmpty) {
        await ArchiveLogService.logActivity(
          type: ArchiveLogService.typeInteractive,
          title: match.english,
          details: 'You said: "$inputText"',
        );
      }

      if (!mounted) return;

      setState(() {
        _state = _BoardState.idle;
        _instructions.insert(0, {
          'english_text': match.english,
          'hindi_text': inputText,
          'santali_text': match.santali,
          'transliteration': match.translit,
          'audio_path': match.audioPath,
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
            Text('Instruction Mode'),
            Text(
              'Offline Classroom Controls',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: AppTheme.lavenderAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_alt_outlined),
            tooltip: 'Type instruction manually',
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
      return const Center(child: CircularProgressIndicator(color: AppTheme.lavenderAccent));
    }

    final Widget content = _instructions.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Hold the mic and say a command (e.g. "Look at the board").\n\n'
                '100% Offline Mode Active.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            itemCount: _instructions.length,
            itemBuilder: (context, index) => _buildInstructionCard(_instructions[index]),
          );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: content,
      ),
    );
  }

  Widget _buildInstructionCard(Map<String, dynamic> entry) {
    // 'hindi_text' historically held whatever was actually spoken/typed
    // (English or Hindi) — 'english_text' (added alongside the wider
    // keyword matcher) is the canonical command label shown as the card's
    // primary text, so display is consistent regardless of input language
    // or modality. Falls back to the raw text for entries saved before
    // 'english_text' existed.
    final spokenText = entry['hindi_text'] as String? ?? '';
    final englishText = entry['english_text'] as String? ?? spokenText;
    final santaliText = entry['santali_text'] as String? ?? '';
    final transliteration = entry['transliteration'] as String? ?? '';
    final audioPath = entry['audio_path'] as String?;
    final timestampRaw = entry['timestamp'] as String?;
    final timestamp = timestampRaw != null ? DateTime.tryParse(timestampRaw) : null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.mintContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: AppTheme.mintAccent, width: 5)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.campaign_rounded, size: 16, color: AppTheme.mintAccent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Offline Command',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.mintAccent),
                      ),
                    ),
                  ],
                ),
              ),
              if (timestamp != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      _formatTimestamp(timestamp),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(englishText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          if (spokenText.isNotEmpty && spokenText != englishText) ...[
            const SizedBox(height: 4),
            Text(
              'You said: "$spokenText"',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(santaliText, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'NotoSansOlChiki', color: AppTheme.textPrimary)),
              ),
              const SizedBox(width: 10),
              _buildReplayButton(audioPath),
            ],
          ),
          if (transliteration.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(transliteration, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
            ),
          ],
        ],
      ),
    );
  }

  /// Replay button for one instruction card — re-plays that entry's exact
  /// mapped clip (stored on the entry when it was first submitted, not
  /// re-matched from its text). Dimmed and inert when there's no clip: the
  /// "command not recognized" fallback, or an entry saved before this
  /// field existed. Filled in the card's own mint green so it reads as
  /// part of the card rather than a bolted-on control.
  Widget _buildReplayButton(String? audioPath) {
    final enabled = audioPath != null && audioPath.isNotEmpty;
    return Tooltip(
      message: 'Replay audio',
      child: Material(
        color: AppTheme.mintAccent.withValues(alpha: enabled ? 1.0 : 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? () => _replayAudio(audioPath) : null,
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.volume_up_rounded, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _formatTimestamp(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = _months[dt.month - 1];
    var hour12 = dt.hour % 12;
    if (hour12 == 0) hour12 = 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour < 12 ? 'AM' : 'PM';
    return '$day $month • $hour12:$minute$amPm';
  }

  Widget _buildStatusStrip() {
    String label;
    switch (_state) {
      case _BoardState.idle: label = 'Ready — hold mic for offline command'; break;
      case _BoardState.recording: label = 'Listening...'; break;
      case _BoardState.processing: label = 'Processing offline...'; break;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Padding(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTapDown: (_) => _onPressStart(),
      onTapUp: (_) => _onPressEnd(),
      onTapCancel: _onPressEnd,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _isSubmitting ? 0.4 : 1.0,
        child: Column(
          children: [
            if (_state == _BoardState.recording) _buildWaveform(),
            if (_state == _BoardState.processing) const Padding(padding: EdgeInsets.only(bottom: 4), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFB8860B)))),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = _state == _BoardState.recording ? 1.0 + (_pulseController.value * 0.08) : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _state == _BoardState.recording ? const Color(0xFFC0392B) : AppTheme.lavenderAccent,
                  boxShadow: [
                    BoxShadow(
                      color: (_state == _BoardState.recording ? const Color(0xFFC0392B) : AppTheme.lavenderAccent).withValues(alpha: 0.4),
                      blurRadius: 18,
                      spreadRadius: _state == _BoardState.recording ? 6 : 0,
                    ),
                  ],
                ),
                child: Icon(_state == _BoardState.recording ? Icons.mic : Icons.mic_none, color: Colors.white, size: 42),
              ),
            ),
          ],
        ),
      ),
    );
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
              final height = 8 + 16 * (0.5 + 0.5 * (1 + (_pulseController.value * 2 - 1) * (i.isEven ? 1 : -1)).abs() / 2);
              return Container(
                width: 4, height: height.clamp(6, 30),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: const Color(0xFFC0392B), borderRadius: BorderRadius.circular(2)),
              );
            },
          );
        }),
      ),
    );
  }
}
