// audio_service.dart
//
// ANVAYA — shared offline audio playback for Lecture Mode's Rhythmic
// Chant and Language Q&A audio buttons.
//
// Singleton: one shared AudioPlayer instance for the whole app. Calling
// play() on an already-playing player interrupts it with the new clip
// rather than overlapping, so routing every "play this clip" call through
// the same instance is what prevents two clips ever sounding at once.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class AudioService {
  AudioService._internal();

  static final AudioService instance = AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  /// Plays [fileName] from assets/audio/ (e.g. 'math_4x1.wav'). A missing
  /// or corrupt clip is caught and logged rather than thrown — matching
  /// the same defensive pattern used elsewhere in the app (e.g.
  /// lecture_screen.dart's _playAudioForCard) — so a bad asset never
  /// crashes the lesson in front of a class.
  Future<void> playLocalAudio(String fileName) async {
    try {
      await _audioPlayer.play(AssetSource('audio/$fileName'));
    } catch (e) {
      debugPrint('AudioService: failed to play "$fileName": $e');
    }
  }

  /// Stops whatever's currently playing — used by the flashcard player's
  /// Play/Pause toggle when switching to its "paused" state.
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('AudioService: failed to stop: $e');
    }
  }
}
