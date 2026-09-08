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
// error/timeout, rate limiting, malformed response) the method returns null
// and logs a warning via debugPrint, rather than throwing. [lastError] holds
// a short human-readable reason for that failure — callers are expected to
// handle a null result (e.g. show it in a SnackBar or error label) instead
// of crashing the UI.
//
// HTTP requests time out after 15s (translateDialogue) or 45s
// (generateWorksheet). A 429 (rate limited) response is retried exactly
// ONCE after a 2.5s wait; if it's still 429 after that, the call gives up
// immediately (returns null) rather than retrying further or trying a
// fallback model, so the caller can fall back to its offline vault without
// a long hang. A 503 (transiently unavailable) response is retried once,
// after a 1.5s delay.
//
// Model routing: translateDialogue (live, latency-sensitive) and
// generateWorksheet (heavier, less latency-sensitive) are routed to
// different Gemini models and endpoints entirely, so a burst of live
// classroom instructions can never drain the quota bucket a worksheet
// generation needs. The two model families also disagree on whether
// generationConfig.thinkingConfig is legal — translateDialogue's lite model
// rejects it with a 400, while generateWorksheet's model needs it (disabled)
// to stop hidden reasoning tokens from eating its output budget — so
// _postToGemini's `disableThinking` flag is opt-in per call, not global.
//
// translateDialogue also keeps a small in-memory cache keyed by the
// normalized input text — pre-seeded with a handful of verified routine
// classroom phrases so those are 0ms/0-API-calls from a cold start, and
// growing as new instructions are successfully translated live.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiCurriculumService {
  AiCurriculumService._();

  static String _endpointFor(String model) =>
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

  // translateDialogue: fast + cheap models only — a live mic/typed
  // instruction must never compete for the same quota bucket as worksheet
  // generation. gemini-2.0-flash-lite has been deprecated/shut down by
  // Google and is deliberately NOT in this list — a 404 from it would just
  // waste a retry. Falls back to gemini-2.5-flash-lite if the primary
  // 3.5 model ever 404s (e.g. not yet available for this API key/region).
  static const List<String> _translateModels = [
    'gemini-3.5-flash-lite',
    'gemini-2.5-flash-lite',
  ];

  // generateWorksheet: the heavier flash model — worksheets are generated
  // far less often than live instructions, so latency matters less here.
  // Falls back to gemini-2.5-flash if the primary 3.5 model 404s.
  static const List<String> _worksheetModels = [
    'gemini-3.5-flash',
    'gemini-2.5-flash',
  ];

  /// Supply the real key at build/run time with:
  ///   flutter run --dart-define=GEMINI_API_KEY=your_key_here
  static const String _geminiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '<YOUR_KEY_HERE>',
  );

  /// A short, human-readable reason for the most recent failure from
  /// [translateDialogue] or [generateWorksheet] — e.g. "Rate limit reached",
  /// "Network timeout", "Malformed response". Null if the last call
  /// succeeded, or none has been made yet. Callers should read this right
  /// after getting a null result back, to show the user something more
  /// specific than a generic error.
  static String? lastError;

  /// In-memory cache of successful [translateDialogue] results, keyed by
  /// the normalized (trimmed, lowercased) input text. Repeating the same
  /// instruction — a common classroom pattern ("open your books" every
  /// period) — returns instantly with zero additional API calls, and saves
  /// quota. Pre-seeded with a handful of verified routine classroom phrases
  /// (see [_seedTranslationCache]); grows as new instructions are
  /// successfully translated live. Cleared only when the app process
  /// restarts.
  static final Map<String, Map<String, dynamic>> _translationCache =
      _seedTranslationCache();

  static Map<String, dynamic> _cacheEntry({
    required String hindi,
    required String santali,
    required String phonetic,
  }) => {
        'source_text': hindi,
        'translated_text': santali,
        'hindi_meaning': hindi,
        'transliteration': phonetic,
        'role': 'Offline Cache',
      };

  static Map<String, Map<String, dynamic>> _seedTranslationCache() {
    final openBooks = _cacheEntry(
      hindi: 'अपनी किताब खोलिए',
      santali: 'ᱟᱢᱟᱜ ᱯᱩᱛᱷᱤ ᱡᱷᱤᱡᱽ ᱢᱮ',
      phonetic: 'Amag puthi jhij me',
    );
    final countTo20 = _cacheEntry(
      hindi: '1 से 20 तक गिनती लिखकर लाएं',
      santali: '᱑ ᱠᱷᱚᱱ ᱒᱐ ᱦᱟᱹᱵᱤᱡ ᱞᱮᱠᱷᱟ ᱚᱞ ᱢᱮ',
      phonetic: '1 khon 20 habij lekha ol me',
    );
    final sitQuietly = _cacheEntry(
      hindi: 'शांत होकर बैठिए',
      santali: 'ᱛᱷᱤᱨ ᱠᱟᱛᱮ ᱫᱩᱲᱩᱵ ᱢᱮ',
      phonetic: 'Thir kate durup me',
    );
    final listenCarefully = _cacheEntry(
      hindi: 'ध्यान से सुनिए',
      santali: 'ᱫᱷᱮᱭᱟᱱ ᱛᱮ ᱟᱧᱡᱚᱢ ᱢᱮ',
      phonetic: 'Dheyan te anjom me',
    );

    return {
      'kitab kholo': openBooks,
      'अपनी किताब खोलो': openBooks,
      'अपनी किताबें खोलिए': openBooks,
      '1 se 20 tak ginti likho': countTo20,
      '1 से 20 तक गिनती लिखकर आओ': countTo20,
      'ginti likho': countTo20,
      'shant raho': sitQuietly,
      'शांत बैठो': sitQuietly,
      'chup raho': sitQuietly,
      'dhyan se suno': listenCarefully,
      'ध्यान से सुनो': listenCarefully,
    };
  }

  /// A best-effort emergency fallback for when a *live* AI call fails
  /// outright (not just a cache miss) — used by qna_screen.dart so the
  /// teacher gets a usable card instead of a bare error when the mic/typed
  /// instruction clearly matches one of these routine classroom commands.
  /// Matches loosely (substring, case-insensitive, Hindi or Hinglish) since
  /// the exact phrasing spoken/typed under pressure rarely matches a cache
  /// key exactly.
  ///
  /// The "homework" entry is a best-effort placeholder — unlike the other
  /// three (lifted straight from the verified [_seedTranslationCache]
  /// entries), it has NOT been checked by a native Santali speaker. Flag it
  /// for review before relying on it in a real classroom.
  static Map<String, dynamic>? emergencyFallbackFor(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('kitab') || lower.contains('किताब')) {
      return _translationCache['kitab kholo'];
    }
    if (lower.contains('ginti') || lower.contains('गिनती')) {
      return _translationCache['ginti likho'];
    }
    if (lower.contains('shant') ||
        lower.contains('chup') ||
        lower.contains('शांत')) {
      return _translationCache['shant raho'];
    }
    if (lower.contains('homework') ||
        lower.contains('गृहकार्य') ||
        lower.contains('होमवर्क')) {
      return _cacheEntry(
        hindi: 'अपना गृह कार्य कीजिए',
        santali: 'ᱚᱲᱟᱜ ᱠᱟᱹᱢᱤ ᱛᱮᱭᱟᱨ ᱢᱮ',
        phonetic: 'Orak kami teyar me',
      );
    }
    return null;
  }

  /// Simulates a Class 3 Student's side of a live QnA Walkie-Talkie
  /// exchange, given the Teacher's [text] (spoken in [fromLang]).
  ///
  /// If the Teacher's line is a question or a pedagogical math/literacy
  /// prompt (e.g. "5 + 2 kitna hota hai?"), Gemini is instructed to answer
  /// it AS an authentic Class 3 student would — working out the correct
  /// answer itself — rather than merely translating the question word for
  /// word. Otherwise (a statement, greeting, instruction, etc.) it responds
  /// with a faithful [toLang] translation instead. Santali output is
  /// required to be authentic Ol Chiki Unicode (U+1C50-U+1C7F), never
  /// Devanagari or Roman transliteration.
  ///
  /// Returns a map shaped like:
  /// {
  ///   "source_text": "...",
  ///   "translated_text": "...",
  ///   "hindi_meaning": "...",
  ///   "transliteration": "...",
  ///   "role": "Student (Santali)"
  /// }
  ///
  /// Checks [_translationCache] first (keyed by the normalized [text]) and
  /// returns a cached result immediately, with no network call, on a hit.
  /// If the live call fails, falls back to [emergencyFallbackFor] (or a
  /// generic offline placeholder) instead of returning null — the UI is
  /// meant to always get a renderable card, never a bare "AI translation
  /// failed" error. (Still technically nullable for defensive callers, but
  /// in practice this should not return null.)
  static Future<Map<String, dynamic>?> translateDialogue({
    required String text,
    required String fromLang,
    required String toLang,
  }) async {
    final key = text.trim().toLowerCase();
    final cached = _translationCache[key];
    if (cached != null) {
      debugPrint(
        'AiCurriculumService: cache hit for "$key" — 0ms, no API call',
      );
      return cached;
    }

    final prompt = '''
You are simulating an authentic Class 3 Foundational Literacy and Numeracy
(FLN) classroom exchange for the ANVAYA offline learning platform, between a
$fromLang-speaking Teacher and a $toLang-speaking Student.

The Teacher just said (in $fromLang): "$text"

The teacher input may be in Hindi (Devanagari script), Hinglish (Romanized
Hindi like "kitab kholo"), or English. First understand the intended
classroom instruction, then translate it directly into authentic Santali
(Ol Chiki Unicode) with its romanized phonetic pronunciation.

If this is a question or a pedagogical math/literacy prompt (e.g. asking the
student to solve a sum, recall a word, or answer a curriculum question),
respond AS the Student: work out the correct answer yourself and reply with
an authentic, age-appropriate Class 3 student's answer. For example, if asked
"5 + 2 kitna hota hai?", the student's reply should mean "The answer is 7" —
not a literal word-for-word translation of the teacher's question.

If it is not a question (e.g. a statement, greeting, or instruction), instead
translate it faithfully into $toLang.

The Student's reply MUST be written in authentic Ol Chiki Unicode script
(U+1C50-U+1C7F) in the "translated_text" field — never Devanagari and never a
Roman transliteration there.

Respond with STRICTLY raw JSON only — no markdown code fences, no commentary —
matching exactly this schema:
{
  "source_text": "the Teacher's original $fromLang sentence",
  "translated_text": "the Student's reply, in authentic Ol Chiki Unicode",
  "hindi_meaning": "the Hindi meaning of the Student's reply",
  "transliteration": "a Roman transliteration of the Student's reply",
  "role": "Student (Santali)"
}
''';
    final result = await _generate(
      prompt,
      models: _translateModels,
      timeout: const Duration(seconds: 15),
      maxOutputTokens: 250,
      // disableThinking intentionally omitted (defaults to false) —
      // gemini-3.5-flash-lite rejects generationConfig.thinkingConfig
      // outright with a 400. See _postToGemini's doc.
    );
    if (result != null) {
      _translationCache[key] = result;
      return result;
    }

    // The live call failed outright (400/429/timeout/malformed response —
    // see lastError for the specific reason). Never surface that as a bare
    // error to the caller: fall back to a known routine-command match if
    // the text has one, or an honest "unavailable offline" placeholder
    // otherwise, so the UI always has a card to render instead of an "AI
    // translation failed" SnackBar.
    debugPrint(
      'AiCurriculumService: translateDialogue failed ($lastError) — '
      'falling back to emergencyFallbackFor.',
    );
    return emergencyFallbackFor(text) ?? _genericOfflineFallback(text);
  }

  /// Last-resort fallback for [translateDialogue] when the live call fails
  /// AND the instruction doesn't match any of [emergencyFallbackFor]'s
  /// known keywords. Deliberately does NOT fabricate new, unverified Ol
  /// Chiki content for arbitrary text — it echoes the Hindi instruction
  /// faithfully and says plainly that the Santali translation isn't
  /// available offline, rather than guessing.
  static Map<String, dynamic> _genericOfflineFallback(String text) {
    return {
      'source_text': text,
      'translated_text': '(Santali translation unavailable offline)',
      'hindi_meaning': text,
      'transliteration': '',
      'role': 'Offline (unavailable)',
    };
  }

  /// Generates 3 bilingual (Hindi + Ol Chiki Santali) Class 3 FLN
  /// math/literacy questions on [topic], matching the schema used by
  /// assets/data/worksheet_content.json.
  ///
  /// Kept deliberately short (3 concise questions, each field under 12
  /// words, capped output tokens) so generation finishes quickly — a longer
  /// 45s timeout is still used as headroom since this is the token-heaviest
  /// of the two AI calls. Routed to the heavier 'gemini-2.5-flash' model —
  /// see [_worksheetModels] — kept entirely separate from the lite model(s)
  /// translateDialogue uses, so a burst of live instructions can never
  /// starve worksheet generation of quota.
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
  }) async {
    final prompt = '''
Create a Class 3 FLN (Foundational Literacy and Numeracy) practice worksheet
for the ANVAYA offline bilingual platform, on the topic: "$topic".

Generate exactly 3 short, high-contrast, age-appropriate primary-grade
math/literacy questions. Keep "question_hindi", "question_santali", and
"visual_hint" each under 12 words — no long explanations. Santali text MUST
be authentic Ol Chiki Unicode (U+1C50-U+1C7F), never Devanagari or a Roman
transliteration.

Respond strictly with pure JSON. Do not include markdown fences, comments, or
explanations. Ensure all strings are properly escaped. Match exactly this
schema:
{
  "worksheet_title": "short title",
  "class_level": "Class 3",
  "subject": "Mathematics",
  "lesson": "$topic",
  "questions": [
    {
      "question_number": 1,
      "question_hindi": "question in Hindi (Devanagari), under 12 words",
      "question_santali": "same question, authentic Ol Chiki, under 12 words",
      "santali_verified": false,
      "visual_hint": "visual/numeric hint, under 12 words"
    }
  ]
}
The "questions" array must contain exactly 3 items, numbered 1 to 3.
''';
    final result = await _generate(
      prompt,
      models: _worksheetModels,
      // 45s is headroom for a slow network, not the expected duration.
      timeout: const Duration(seconds: 45),
      // gemini-2.5-flash/gemini-3.5-flash think by default, and those
      // hidden reasoning tokens count against maxOutputTokens — that was
      // exhausting the budget before the model finished writing the JSON,
      // truncating it mid-word (e.g. "lesson": "Counting 1-...). Disabling
      // thinking here frees the whole budget for the actual output.
      // (Unlike the lite model translateDialogue uses, which rejects this
      // parameter outright — see disableThinking's doc.)
      disableThinking: true,
      // Ol Chiki Unicode runs 3-4 bytes/char, and 3 questions' worth of
      // Hindi + Santali + hints needs real headroom even with thinking
      // disabled.
      maxOutputTokens: 2500,
    );

    if (result == null && lastError == 'Malformed response') {
      debugPrint(
        'Worksheet generation truncated or invalid JSON, falling back to '
        'vault.',
      );
    }
    return result;
  }

  /// Runs [prompt] against the first working model in [models] (falling
  /// back to the next one only on a 404 "model not found" response), with
  /// 429/503 retry handling, then defensively parses the result.
  static Future<Map<String, dynamic>?> _generate(
    String prompt, {
    required List<String> models,
    Duration timeout = const Duration(seconds: 15),
    int? maxOutputTokens,
    bool disableThinking = false,
  }) async {
    lastError = null;

    if (_geminiKey.isEmpty || _geminiKey == '<YOUR_KEY_HERE>') {
      lastError = 'Gemini API key not configured';
      debugPrint(
        'AiCurriculumService: $lastError — pass '
        '--dart-define=GEMINI_API_KEY=your_key at build/run time.',
      );
      return null;
    }

    late http.Response response;
    for (var i = 0; i < models.length; i++) {
      final model = models[i];
      final isLastModel = i == models.length - 1;

      try {
        response = await _postToGemini(
          prompt,
          model: model,
          timeout: timeout,
          maxOutputTokens: maxOutputTokens,
          disableThinking: disableThinking,
        );

        if (response.statusCode == 429) {
          // Rate limited — wait once, retry once. If it's STILL 429 after
          // that single retry, give up immediately rather than trying
          // again or falling back to another model: quota exhaustion isn't
          // fixed by a model swap, and the caller is expected to fall back
          // to its own offline vault instead of hanging around.
          debugPrint('Gemini transient error 429, retrying in 2.5s...');
          await Future<void>.delayed(const Duration(milliseconds: 2500));
          response = await _postToGemini(
            prompt,
            model: model,
            timeout: timeout,
            maxOutputTokens: maxOutputTokens,
            disableThinking: disableThinking,
          );
          if (response.statusCode == 429) {
            lastError = 'Rate limit reached';
            debugPrint(
              'AiCurriculumService: still rate limited (429) after retry — '
              'giving up so the caller can use its offline fallback.',
            );
            return null;
          }
        } else if (response.statusCode == 503) {
          // Transiently unavailable — wait briefly and retry exactly once
          // before failing.
          debugPrint('Gemini transient error 503, retrying in 1.5s...');
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          response = await _postToGemini(
            prompt,
            model: model,
            timeout: timeout,
            maxOutputTokens: maxOutputTokens,
            disableThinking: disableThinking,
          );
        }
      } on TimeoutException {
        lastError = 'Network timeout';
        debugPrint(
          'AiCurriculumService: request timed out after ${timeout.inSeconds}s',
        );
        return null;
      } catch (e) {
        lastError = 'Network error';
        debugPrint('AiCurriculumService: request failed: $e');
        return null;
      }

      if (response.statusCode == 404 && !isLastModel) {
        debugPrint(
          'AiCurriculumService: model "$model" unavailable (404), falling '
          'back to "${models[i + 1]}"...',
        );
        continue;
      }
      break;
    }

    if (response.statusCode != 200) {
      lastError = switch (response.statusCode) {
        503 => 'Service temporarily unavailable',
        _ => 'Gemini error ${response.statusCode}',
      };
      debugPrint('Gemini Error ${response.statusCode}: ${response.body}');
      return null;
    }

    final String rawText;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw const FormatException('no candidates in response');
      }
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final text = (parts != null && parts.isNotEmpty)
          ? parts.first['text'] as String?
          : null;
      if (text == null) {
        throw const FormatException('no text in response');
      }
      rawText = text;
    } catch (e) {
      lastError = 'Malformed response';
      debugPrint('AiCurriculumService: could not read Gemini envelope: $e');
      debugPrint('Raw API Response: ${response.body}');
      return null;
    }

    final result = _extractJson(rawText);
    if (result == null) {
      lastError = 'Malformed response';
      return null;
    }
    return result;
  }

  static Future<http.Response> _postToGemini(
    String prompt, {
    required String model,
    required Duration timeout,
    int? maxOutputTokens,
    // Only pass true for models confirmed to accept this field.
    // gemini-3.5-flash-lite (translateDialogue's model) rejects it outright
    // with a 400 INVALID_ARGUMENT ("Request contains an invalid argument"),
    // so translateDialogue must never set this. gemini-2.5-flash /
    // gemini-3.5-flash (generateWorksheet's models) think by default, and
    // those hidden reasoning tokens count against maxOutputTokens — without
    // disabling it, worksheet generation was exhausting the token budget on
    // invisible reasoning and returning JSON truncated mid-word.
    bool disableThinking = false,
  }) {
    return http
        .post(
          Uri.parse('${_endpointFor(model)}?key=$_geminiKey'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              // Ask Gemini to constrain output to raw JSON directly, on top
              // of the prompt instructions — belt and braces against
              // markdown fences.
              'responseMimeType': 'application/json',
              'maxOutputTokens': maxOutputTokens ?? 2500,
              'temperature': 0.2,
              if (disableThinking) 'thinkingConfig': {'thinkingBudget': 0},
            },
          }),
        )
        .timeout(timeout);
  }

  /// Defensively extracts and parses a JSON object out of Gemini's raw text
  /// response. Never runs `jsonDecode` on the raw text directly — instead:
  ///  1. Strips markdown code fences (```json / ```), in case Gemini adds
  ///     them despite being told not to.
  ///  2. Locates the JSON object between the first '{' and the last '}',
  ///     tolerating any stray commentary before/after it.
  ///  3. Only then attempts to decode that substring.
  /// Logs the raw response and returns null if no valid JSON object can be
  /// recovered this way.
  static Map<String, dynamic>? _extractJson(String rawResponse) {
    final stripped = rawResponse.replaceAll(RegExp(r'```json|```'), '').trim();

    final start = stripped.indexOf('{');
    final end = stripped.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) {
      debugPrint('AiCurriculumService: no JSON object found in response');
      debugPrint('Raw API Response: $rawResponse');
      return null;
    }

    try {
      final jsonBlock = stripped.substring(start, end + 1);
      return jsonDecode(jsonBlock) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('AiCurriculumService: JSON decode failed: $e');
      debugPrint('Raw API Response: $rawResponse');
      return null;
    }
  }
}
