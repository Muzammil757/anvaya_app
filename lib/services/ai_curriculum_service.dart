// ai_curriculum_service.dart
//
// ANVAYA — live AI curriculum service, backed by the Gemini API.
//
// Two features:
//  - translateDialogue: Hindi <-> Santali (Ol Chiki) live QnA translation,
//    used by the Walkie-Talkie mic pipeline in qna_screen.dart.
//  - generateWorksheet: dynamic bilingual Class 3 FLN worksheet generation,
//    used by the "AI Generate" sheet in worksheet_screen.dart.
//
// Every call degrades gracefully: on any failure (missing API key, network
// error, malformed response) the method returns null and logs a warning via
// debugPrint, rather than throwing — callers are expected to handle a null
// result (e.g. show a SnackBar) instead of crashing the UI.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiCurriculumService {
  AiCurriculumService._();

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  /// Supply the real key at build/run time with:
  ///   flutter run --dart-define=GEMINI_API_KEY=your_key_here
  static const String _geminiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '<YOUR_KEY_HERE>',
  );

  /// Translates [text] from [fromLang] to [toLang] for the live QnA
  /// Walkie-Talkie flow. Santali output is required to be authentic Ol Chiki
  /// Unicode (U+1C50-U+1C7F), never Devanagari or Roman transliteration.
  ///
  /// Returns a map shaped like:
  /// {
  ///   "source_text": "...",
  ///   "translated_text": "...",
  ///   "transliteration": "...",
  ///   "target_language": "Santali (Ol Chiki)"
  /// }
  /// or null if the request/parse failed.
  static Future<Map<String, dynamic>?> translateDialogue({
    required String text,
    required String fromLang,
    required String toLang,
  }) {
    final prompt = '''
You are a professional $fromLang to $toLang translator specializing in Class 3
Foundational Literacy and Numeracy (FLN) classroom dialogue for the ANVAYA
offline learning platform.

Translate the following $fromLang sentence into $toLang. The Santali output
MUST be written in authentic Ol Chiki Unicode script (U+1C50-U+1C7F) — never
Devanagari and never a Roman transliteration in that field.

Sentence: "$text"

Respond with STRICTLY raw JSON only — no markdown code fences, no commentary —
matching exactly this schema:
{
  "source_text": "the original $fromLang sentence",
  "translated_text": "the $toLang translation, in authentic Ol Chiki Unicode",
  "transliteration": "a Roman transliteration of the translated text",
  "target_language": "Santali (Ol Chiki)"
}
''';
    return _generate(prompt);
  }

  /// Generates 4 bilingual (Hindi + Ol Chiki Santali) Class 3 FLN
  /// math/literacy questions on [topic], matching the schema used by
  /// assets/data/worksheet_content.json.
  ///
  /// Returns a map shaped like:
  /// {
  ///   "worksheet_title": "...",
  ///   "class_level": "Class 3",
  ///   "subject": "...",
  ///   "lesson": "...",
  ///   "questions": [
  ///     {
  ///       "question_number": 1,
  ///       "question_hindi": "...",
  ///       "question_santali": "...",
  ///       "santali_verified": false,
  ///       "visual_hint": "..."
  ///     },
  ///     ...
  ///   ]
  /// }
  /// or null if the request/parse failed.
  static Future<Map<String, dynamic>?> generateWorksheet({
    required String topic,
  }) {
    final prompt = '''
You are creating a Class 3 Foundational Literacy and Numeracy (FLN) practice
worksheet for the ANVAYA offline bilingual learning platform, on the topic:
"$topic".

Generate exactly 4 age-appropriate primary-grade math/literacy questions.
Every question's Santali text MUST be written in authentic Ol Chiki Unicode
script (U+1C50-U+1C7F) — never Devanagari and never a Roman transliteration.

Respond with STRICTLY raw JSON only — no markdown code fences, no commentary —
matching exactly this schema:
{
  "worksheet_title": "a short title for this worksheet",
  "class_level": "Class 3",
  "subject": "Mathematics",
  "lesson": "$topic",
  "questions": [
    {
      "question_number": 1,
      "question_hindi": "the question, in Hindi (Devanagari)",
      "question_santali": "the same question, in authentic Ol Chiki Unicode",
      "santali_verified": false,
      "visual_hint": "a short visual/numeric hint, e.g. an equation or emoji-style prompt"
    }
  ]
}
The "questions" array must contain exactly 4 items, numbered 1 to 4.
''';
    return _generate(prompt);
  }

  static Future<Map<String, dynamic>?> _generate(String prompt) async {
    if (_geminiKey.isEmpty || _geminiKey == '<YOUR_KEY_HERE>') {
      debugPrint(
        'AiCurriculumService: GEMINI_API_KEY not configured — pass '
        '--dart-define=GEMINI_API_KEY=your_key at build/run time.',
      );
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$_endpoint?key=$_geminiKey'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          // Ask Gemini to constrain output to raw JSON directly, on top of
          // the prompt instructions — belt and braces against markdown fences.
          'generationConfig': {'responseMimeType': 'application/json'},
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
          'AiCurriculumService: Gemini request failed '
          '(${response.statusCode}): ${response.body}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        debugPrint(
          'AiCurriculumService: no candidates in Gemini response: $decoded',
        );
        return null;
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final rawText = (parts != null && parts.isNotEmpty)
          ? parts.first['text'] as String?
          : null;
      if (rawText == null) {
        debugPrint(
          'AiCurriculumService: no text in Gemini response: $decoded',
        );
        return null;
      }

      final cleaned = _stripMarkdownFences(rawText);
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('AiCurriculumService: request failed: $e');
      return null;
    }
  }

  /// Gemini is instructed not to wrap JSON in markdown fences, but strip
  /// them defensively in case it does anyway (e.g. ```json ... ```).
  static String _stripMarkdownFences(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      text = text.replaceFirst(RegExp(r'```\s*$'), '');
    }
    return text.trim();
  }
}
