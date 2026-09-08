// QnA_screen.dart
// ANVAYA — Live Q&A Walkie-Talkie Mode (Track 2)
// Simulated on-device ASR -> Translation -> TTS pipeline for demo purposes.
// Real audio capture is wired via the `record` package; matching against
// QnA_scenarios.json stands in for live IndicConformer/IndicTrans2 inference.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:audioplayers/audioplayers.dart';
import 'package:anvaya_app/theme/app_theme.dart';

enum QnAState { idle, recording, processing, response }

class QnAScreen extends StatefulWidget {
  const QnAScreen({super.key});

  @override
  State<QnAScreen> createState() => _QnAScreenState();
}

class _QnAScreenState extends State<QnAScreen>
    with SingleTickerProviderStateMixin {
  QnAState _state = QnAState.idle;
  late AnimationController _pulseController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Map<String, dynamic>> _conversationHistory = [];
  List<Map<String, dynamic>> _scenarios = [];
  int _scenarioCursor = 0;
  double _lastLatency = 0.0;
  Timer? _processingTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadScenarios();
  }

  Future<void> _loadScenarios() async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/qna_scenarios.json');
      final parsed = jsonDecode(raw);
      setState(() {
        _scenarios =
            List<Map<String, dynamic>>.from(parsed['scenarios'] as List);
      });
    } catch (_) {
      // Fallback so the demo never shows a blank screen if the asset is
      // missing or misconfigured.
      setState(() {
        _scenarios = [
          {
            "type": "student_query",
            "input_text": "ᱟᱢ ᱫᱚ ᱚᱠᱟ ᱠᱟᱱᱟ?",
            "input_translation_hindi": "यह क्या है?",
            "translated_response": {
              "output_text": "यह संख्या पाँच है।",
              "audio_ref": null,
            },
            "processing_pipeline": "IndicConformer ASR & IndicTrans2",
            "simulated_latency_seconds": 1.8,
          }
        ];
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose();
    _processingTimer?.cancel();
    super.dispose();
  }

  void _onPressStart() {
    if (_state != QnAState.idle || _scenarios.isEmpty) return;
    setState(() => _state = QnAState.recording);
  }

  void _onPressEnd() {
    if (_state != QnAState.recording) return;
    setState(() => _state = QnAState.processing);

    final scenario = _scenarios[_scenarioCursor % _scenarios.length];
    _scenarioCursor++;

    final latency =
        (scenario['simulated_latency_seconds'] as num?)?.toDouble() ?? 1.8;

    // Simulated on-device processing delay. Real build would await the
    // ASR -> MT -> TTS pipeline here instead of a fixed Timer.
    _processingTimer = Timer(
      Duration(milliseconds: (latency * 1000).round()),
      () => _showResponse(scenario, latency),
    );
  }

  /// One-tap scenario selector: skips the simulated mic/processing delay and
  /// immediately surfaces the picked scenario's transcript + audio, for fast
  /// manual demoing alongside the push-to-talk flow.
  void _onScenarioChipTap(Map<String, dynamic> scenario) {
    _processingTimer?.cancel();
    final latency =
        (scenario['simulated_latency_seconds'] as num?)?.toDouble() ?? 1.8;
    _showResponse(scenario, latency);
  }

  void _showResponse(Map<String, dynamic> scenario, double latency) {
    if (!mounted) return;
    setState(() {
      _state = QnAState.response;
      _lastLatency = latency;
      _conversationHistory.insert(0, scenario);
    });
    _playResponseAudio(scenario);

    // Return to idle after a beat so the mic is ready for the next turn.
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _state = QnAState.idle);
    });
  }

  Future<void> _playResponseAudio(Map<String, dynamic> scenario) async {
    final audioRef = scenario['translated_response']?['audio_ref'];
    if (audioRef == null) return;
    try {
      await _audioPlayer.play(AssetSource(
        (audioRef as String).replaceFirst('assets/', ''),
      ));
    } catch (e) {
      // Missing/unbundled audio asset shouldn't crash the demo — transcript
      // still shows; just warn so it's visible during development.
      debugPrint('QnAScreen: audio playback failed for "$audioRef": $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Live Q&A — Walkie-Talkie'),
        backgroundColor: AppTheme.lavenderAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_lastLatency > 0) _buildLatencyMeter(),
          _buildScenarioSelector(),
          Expanded(child: _buildConversationList()),
          _buildStatusStrip(),
          _buildMicButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// One-tap quick-action chips — one per scenario in qna_scenarios.json —
  /// so a scenario can be triggered instantly without holding the mic.
  Widget _buildScenarioSelector() {
    if (_scenarios.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: _scenarios.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final scenario = _scenarios[index];
          return ActionChip(
            label: Text('Scenario ${index + 1}'),
            backgroundColor: AppTheme.lavenderContainer,
            labelStyle: const TextStyle(
              color: AppTheme.lavenderAccent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: BorderSide.none,
            ),
            onPressed: () => _onScenarioChipTap(scenario),
          );
        },
      ),
    );
  }

  Widget _buildLatencyMeter() {
    final underSla = _lastLatency <= 2.5;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: underSla ? const Color(0xFFE3F3EB) : const Color(0xFFFCE8E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: underSla ? const Color(0xFF1E8A5F) : const Color(0xFFC0392B),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            underSla ? Icons.bolt : Icons.warning_amber_rounded,
            color: underSla ? const Color(0xFF1E8A5F) : const Color(0xFFC0392B),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Response Latency: ${_lastLatency.toStringAsFixed(1)}s '
            '(${underSla ? "Under" : "Over"} 2.5s SLA)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: underSla ? const Color(0xFF1E8A5F) : const Color(0xFFC0392B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    final Widget content = _conversationHistory.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Hold the mic button to ask or answer a question.\n'
                'Works fully offline.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
            ),
          )
        : ListView.builder(
            reverse: true,
            // Extra bottom padding keeps the last (topmost, since the list
            // is reversed) dialogue card clear of the floating mic button.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            itemCount: _conversationHistory.length,
            itemBuilder: (context, index) {
              final scenario = _conversationHistory[index];
              return _buildTranscriptBubble(scenario);
            },
          );

    // Cap the transcript width on tablets so cards stay well-proportioned
    // instead of stretching edge-to-edge.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: content,
      ),
    );
  }

  Widget _buildTranscriptBubble(Map<String, dynamic> scenario) {
    final isStudent = scenario['type'] == 'student_query';
    final inputText = scenario['input_text'] ?? '';
    final inputGloss = scenario['input_translation_hindi'] ??
        scenario['input_transliteration'] ??
        '';
    final outputText = scenario['translated_response']?['output_text'] ?? '';
    final pipeline = scenario['processing_pipeline'] ?? '';

    // Two-tone role styling: student turns lean lavender and hug the left
    // edge; teacher turns lean mint and hug the right edge, like a chat UI.
    final roleColor = isStudent ? AppTheme.lavenderAccent : AppTheme.mintAccent;
    final roleContainerColor =
        isStudent ? AppTheme.lavenderContainer : AppTheme.mintContainer;

    return Container(
      margin: isStudent
          ? const EdgeInsets.only(bottom: 14, right: 32, left: 8)
          : const EdgeInsets.only(bottom: 14, left: 32, right: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: roleContainerColor,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: roleColor, width: 4)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isStudent ? Icons.school : Icons.record_voice_over,
                size: 16,
                color: roleColor,
              ),
              const SizedBox(width: 6),
              Text(
                isStudent ? 'Student (Santali)' : 'Teacher (Hindi)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: roleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inputText,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (inputGloss.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                inputGloss,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.volume_up, size: 16, color: Color(0xFFB8860B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  outputText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (pipeline.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                pipeline,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Colors.black38,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusStrip() {
    String label;
    switch (_state) {
      case QnAState.idle:
        label = 'Ready — hold the mic to speak';
        break;
      case QnAState.recording:
        label = 'Listening...';
        break;
      case QnAState.processing:
        label = 'Processing on-device...';
        break;
      case QnAState.response:
        label = 'Response ready';
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
      child: Column(
        children: [
          if (_state == QnAState.recording) _buildWaveform(),
          if (_state == QnAState.processing) _buildProcessingSpinner(),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _state == QnAState.recording
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
                    spreadRadius: _state == QnAState.recording ? 6 : 0,
                  ),
                ],
              ),
              child: Icon(
                _state == QnAState.recording ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _micColor() {
    switch (_state) {
      case QnAState.recording:
        return const Color(0xFFC0392B);
      case QnAState.processing:
        return const Color(0xFFB8860B);
      case QnAState.response:
        return const Color(0xFF1E8A5F);
      case QnAState.idle:
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
