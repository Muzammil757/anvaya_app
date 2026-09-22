// database_service.dart
//
// ANVAYA — SQLite offline backbone.
//
// A single local `vocabulary` table backs Lecture Mode, Instruction Mode,
// and the Worksheet Generator, so none of them depend on a live Gemini call
// for their core classroom content. The table is seeded on first run from
// the vocabulary that used to be hardcoded in lecture_screen.dart's
// `_lectureUnits` (10 flashcards: Numbers 1-5 + Our School) and the verified
// routine classroom phrases from ai_curriculum_service.dart's
// `_seedTranslationCache` (used by qna_screen.dart's Interactive Mode board).
//
// `needs_practice` is the adaptive-loop flag: teachers/students flip it via
// [DatabaseService.toggleNeedsPractice] on any item, and the Worksheet
// Generator's [DatabaseService.getRandomItems] prioritizes flagged items so
// worksheets keep circling back to the words a class is struggling with.

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// One row of the `vocabulary` table.
class VocabularyItem {
  const VocabularyItem({
    required this.id,
    required this.category,
    required this.unitName,
    required this.hindiText,
    required this.santaliText,
    required this.transliteration,
    required this.audioPath,
    required this.needsPractice,
  });

  final int id;

  /// 'instruction' (Interactive Mode board) or 'lecture' (Lecture Mode).
  final String category;

  /// e.g. 'Numbers', 'Our School', 'Classroom Commands'.
  final String unitName;

  final String hindiText;

  /// Ol Chiki script.
  final String santaliText;

  final String transliteration;

  /// Relative to the assets/ folder (audioplayers' AssetSource default
  /// prefix), e.g. 'audio/one.wav' -> assets/audio/one.wav. Null when no
  /// pronunciation clip is bundled for this item.
  final String? audioPath;

  final bool needsPractice;

  factory VocabularyItem.fromMap(Map<String, dynamic> map) {
    return VocabularyItem(
      id: map['id'] as int,
      category: map['category'] as String,
      unitName: map['unit_name'] as String,
      hindiText: map['hindi_text'] as String,
      santaliText: map['santali_text'] as String,
      transliteration: map['transliteration'] as String,
      audioPath: map['audio_path'] as String?,
      needsPractice: (map['needs_practice'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'unit_name': unitName,
      'hindi_text': hindiText,
      'santali_text': santaliText,
      'transliteration': transliteration,
      'audio_path': audioPath,
      'needs_practice': needsPractice ? 1 : 0,
    };
  }
}

class DatabaseService {
  DatabaseService._();

  static const String _dbName = 'anvaya_vocabulary.db';
  static const int _dbVersion = 5;
  static const String table = 'vocabulary';

  /// The Archive / Vault screen's activity trail — see
  /// archive_log_service.dart, which owns all reads/writes to this table;
  /// this class only owns its schema/migration, same as [table] above.
  static const String activityLogsTable = 'activity_logs';

  static Database? _database;

  /// Lazily opens (and, on first run, seeds) the shared database. Safe to
  /// call repeatedly/concurrently — sqflite's [openDatabase] itself
  /// serializes concurrent open calls against the same path, so no extra
  /// locking is needed here.
  static Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final opened = await _openDatabase();
    _database = opened;
    return opened;
  }

  static Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createTable(db);
        await _seedDatabase(db);
        await _createActivityLogsTable(db);
      },
      // Dev-stage migration only: seed content is still actively evolving
      // (e.g. Day 2 added/relabeled 'Our School' vocabulary), and there are
      // no deployed users yet, so the simplest correct move is to drop and
      // reseed rather than write a per-version ALTER TABLE migration. This
      // does discard any `needs_practice` flags a tester had already set —
      // once this ships to real classrooms, replace it with a non-destructive
      // migration. [activityLogsTable] is untouched by this drop/reseed —
      // it's a separate table, created (not recreated) with IF NOT EXISTS,
      // so any logged activity survives a `vocabulary`-only migration.
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS $table');
        await _createTable(db);
        await _seedDatabase(db);
        await _createActivityLogsTable(db);
      },
    );
  }

  static Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        unit_name TEXT NOT NULL,
        hindi_text TEXT NOT NULL,
        santali_text TEXT NOT NULL,
        transliteration TEXT NOT NULL,
        audio_path TEXT,
        needs_practice INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  static Future<void> _createActivityLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $activityLogsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        details TEXT,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  /// Closes and forgets the cached [Database] handle. Intended for tests;
  /// the app itself never needs to call this.
  static Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }

  // ---------------------------------------------------------------------
  // Seed data
  // ---------------------------------------------------------------------

  /// Inserts the starter vocabulary in a single batch. Lecture cards are
  /// lifted from lecture_screen.dart's `_lectureUnits` (englishText's Hindi
  /// equivalent added here since the flashcards only ever carried
  /// English/Ol Chiki/phonetic text); instruction phrases are lifted from
  /// ai_curriculum_service.dart's verified `_seedTranslationCache` entries,
  /// which back the Interactive Mode board's offline emergency fallback.
  static Future<void> _seedDatabase(Database db) async {
    final batch = db.batch();

    // --- Lecture Mode: Numbers 1-5 -------------------------------------
    const numbersUnit = 'Numbers';
    _insertLecture(
      batch,
      unitName: numbersUnit,
      hindiText: 'एक',
      santaliText: '᱑ (ᱢᱤᱫ)',
      transliteration: "Mit'",
      audioPath: 'audio/one.wav',
    );
    _insertLecture(
      batch,
      unitName: numbersUnit,
      hindiText: 'दो',
      santaliText: '᱒ (ᱵᱟᱨ)',
      transliteration: 'Bar',
      audioPath: 'audio/two.wav',
    );
    _insertLecture(
      batch,
      unitName: numbersUnit,
      hindiText: 'तीन',
      santaliText: '᱓ (ᱯᱮ)',
      transliteration: 'Pe',
      audioPath: 'audio/three.wav',
    );
    _insertLecture(
      batch,
      unitName: numbersUnit,
      hindiText: 'चार',
      santaliText: '᱔ (ᱯᱳᱱ)',
      transliteration: 'Pon',
      audioPath: 'audio/four.wav',
    );
    _insertLecture(
      batch,
      unitName: numbersUnit,
      hindiText: 'पांच',
      santaliText: '᱕ (ᱢᱚᱬᱮ)',
      transliteration: 'More',
      audioPath: 'audio/five.wav',
    );

    // --- Lecture Mode: Our School ---------------------------------------
    const ourSchoolUnit = 'Our School';
    _insertLecture(
      batch,
      unitName: ourSchoolUnit,
      hindiText: 'किताब',
      santaliText: 'ᱯᱩᱛᱷᱤ',
      transliteration: 'Puthi',
      audioPath: 'audio/book.wav',
    );
    // Reused as the Interactive Classroom Scene's "Pencil" hotspot.
    _insertLecture(
      batch,
      unitName: ourSchoolUnit,
      hindiText: 'पेंसिल',
      santaliText: 'ᱯᱮᱱᱥᱤᱞ',
      transliteration: 'Pensil',
      audioPath: 'audio/pencil.wav',
    );
    _insertLecture(
      batch,
      unitName: ourSchoolUnit,
      hindiText: 'छात्र',
      santaliText: 'ᱯᱟᱹᱴᱷᱩᱣᱟᱹ',
      transliteration: 'Pathua',
      audioPath: 'audio/student.wav',
    );
    _insertLecture(
      batch,
      unitName: ourSchoolUnit,
      hindiText: 'शिक्षक',
      santaliText: 'ᱢᱟᱪᱮᱛ',
      transliteration: 'Machet',
      audioPath: 'audio/teacher.wav',
    );
    _insertLecture(
      batch,
      unitName: ourSchoolUnit,
      hindiText: 'कक्षा',
      santaliText: 'ᱚᱲᱟᱜ',
      transliteration: "Orak'",
      audioPath: 'audio/classroom.wav',
    );
    // "Blackboard" and "School Bag" below are new for the Interactive
    // Classroom Scene's 5 hotspots (Day 2) — no pronunciation clip is
    // bundled yet for either, so audioPath is left null (the sheet's audio
    // button shows a "coming soon" message instead of failing silently on
    // a missing asset). Their Santali text is a best-effort placeholder
    // (a plausible loanword rendering), consistent with this file's other
    // unverified Ol Chiki entries — see the file-level seeding note.
    _insertLecture(
      batch,
      unitName: ourSchoolUnit,
      hindiText: 'श्यामपट्ट',
      santaliText: 'ᱵᱞᱮᱠ ᱵᱚᱨᱰ',
      transliteration: 'Blek bord',
      audioPath: null,
    );
    _insertLecture(
      batch,
      unitName: ourSchoolUnit,
      hindiText: 'बस्ता',
      santaliText: 'ᱥᱠᱩᱞ ᱵᱮᱜ',
      transliteration: 'Skul beg',
      audioPath: null,
    );

    // --- Instruction Mode: essential classroom commands ------------------
    const commandsUnit = 'Classroom Commands';
    _insertInstruction(
      batch,
      unitName: commandsUnit,
      hindiText: 'अपनी किताब खोलिए',
      santaliText: 'ᱟᱢᱟᱜ ᱯᱩᱛᱷᱤ ᱡᱷᱤᱡᱽ ᱢᱮ',
      transliteration: 'Amag puthi jhij me',
    );
    _insertInstruction(
      batch,
      unitName: commandsUnit,
      hindiText: '1 से 20 तक गिनती लिखकर लाएं',
      santaliText: '᱑ ᱠᱷᱚᱱ ᱒᱐ ᱦᱟᱹᱵᱤᱡ ᱞᱮᱠᱷᱟ ᱚᱞ ᱢᱮ',
      transliteration: '1 khon 20 habij lekha ol me',
    );
    _insertInstruction(
      batch,
      unitName: commandsUnit,
      hindiText: 'शांत होकर बैठिए',
      santaliText: 'ᱛᱷᱤᱨ ᱠᱟᱛᱮ ᱫᱩᱲᱩᱵ ᱢᱮ',
      transliteration: 'Thir kate durup me',
    );
    _insertInstruction(
      batch,
      unitName: commandsUnit,
      hindiText: 'ध्यान से सुनिए',
      santaliText: 'ᱫᱷᱮᱭᱟᱱ ᱛᱮ ᱟᱧᱡᱚᱢ ᱢᱮ',
      transliteration: 'Dheyan te anjom me',
    );
    _insertInstruction(
      batch,
      unitName: commandsUnit,
      hindiText: 'अपना गृह कार्य कीजिए',
      santaliText: 'ᱚᱲᱟᱜ ᱠᱟᱹᱢᱤ ᱛᱮᱭᱟᱨ ᱢᱮ',
      transliteration: 'Orak kami teyar me',
    );

    await batch.commit(noResult: true);
  }

  static void _insertLecture(
    Batch batch, {
    required String unitName,
    required String hindiText,
    required String santaliText,
    required String transliteration,
    required String? audioPath,
  }) {
    batch.insert(table, {
      'category': 'lecture',
      'unit_name': unitName,
      'hindi_text': hindiText,
      'santali_text': santaliText,
      'transliteration': transliteration,
      'audio_path': audioPath,
      'needs_practice': 0,
    });
  }

  static void _insertInstruction(
    Batch batch, {
    required String unitName,
    required String hindiText,
    required String santaliText,
    required String transliteration,
  }) {
    batch.insert(table, {
      'category': 'instruction',
      'unit_name': unitName,
      'hindi_text': hindiText,
      'santali_text': santaliText,
      'transliteration': transliteration,
      'audio_path': null,
      'needs_practice': 0,
    });
  }

  // ---------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------

  /// All 'lecture' cards belonging to [unitName] (e.g. 'Numbers',
  /// 'Our School'), in insertion order — i.e. the order Lecture Mode's
  /// slideshow should present them.
  static Future<List<VocabularyItem>> getLectureCards(String unitName) async {
    final db = await database;
    final rows = await db.query(
      table,
      where: 'category = ? AND unit_name = ?',
      whereArgs: ['lecture', unitName],
      orderBy: 'id ASC',
    );
    return rows.map(VocabularyItem.fromMap).toList();
  }

  /// All 'instruction' phrases (the Interactive Mode board's offline
  /// vocabulary), in insertion order.
  static Future<List<VocabularyItem>> getAllInstructions() async {
    final db = await database;
    final rows = await db.query(
      table,
      where: 'category = ?',
      whereArgs: ['instruction'],
      orderBy: 'id ASC',
    );
    return rows.map(VocabularyItem.fromMap).toList();
  }

  /// Looks up an 'instruction' item by the Hindi the teacher spoke/typed,
  /// for the offline fallback path when a live Gemini translation isn't
  /// available. Tries an exact (case/whitespace-insensitive) match first;
  /// if none is found, falls back to a keyword match — any stored
  /// instruction whose Hindi text contains one of [spokenHindi]'s words (or
  /// vice versa) — since exact phrasing spoken under pressure rarely
  /// matches a stored phrase word-for-word. Returns null if nothing matches.
  static Future<VocabularyItem?> matchInstructionByHindi(
    String spokenHindi,
  ) async {
    final normalized = spokenHindi.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final db = await database;

    final exactRows = await db.query(
      table,
      where: 'category = ? AND LOWER(TRIM(hindi_text)) = ?',
      whereArgs: ['instruction', normalized],
      limit: 1,
    );
    if (exactRows.isNotEmpty) {
      return VocabularyItem.fromMap(exactRows.first);
    }

    final instructions = await getAllInstructions();
    if (instructions.isEmpty) return null;

    // Substring match: the whole spoken phrase against each stored phrase,
    // either direction (handles both a longer spoken sentence containing a
    // short stored command, and a stored phrase containing extra words
    // relative to a terse spoken fragment).
    for (final item in instructions) {
      final stored = item.hindiText.trim().toLowerCase();
      if (stored.isEmpty) continue;
      if (normalized.contains(stored) || stored.contains(normalized)) {
        return item;
      }
    }

    // Word-level fallback: any individual word (2+ chars, to skip
    // negligible particles) shared between the spoken text and a stored
    // phrase counts as a match.
    final spokenWords = normalized
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .toSet();
    if (spokenWords.isEmpty) return null;

    for (final item in instructions) {
      final storedWords = item.hindiText
          .trim()
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 1);
      if (storedWords.any(spokenWords.contains)) {
        return item;
      }
    }

    return null;
  }

  /// Flags (or unflags) a vocabulary item for the adaptive practice loop.
  static Future<void> toggleNeedsPractice(int id, bool status) async {
    final db = await database;
    await db.update(
      table,
      {'needs_practice': status ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Every item currently flagged for practice, across both categories —
  /// what a "needs work" review screen would show.
  static Future<List<VocabularyItem>> getItemsForPractice() async {
    final db = await database;
    final rows = await db.query(
      table,
      where: 'needs_practice = 1',
      orderBy: 'id ASC',
    );
    return rows.map(VocabularyItem.fromMap).toList();
  }

  /// Picks [limit] items for the Worksheet Generator.
  ///
  /// When [prioritizePractice] is true (the default), items flagged
  /// `needs_practice` are drawn first — so worksheets keep circling back to
  /// the vocabulary a class is struggling with — and only topped up with
  /// random non-flagged items if there aren't enough practice items to fill
  /// [limit]. When false, [limit] items are drawn uniformly at random from
  /// the whole table.
  static Future<List<VocabularyItem>> getRandomItems(
    int limit, {
    bool prioritizePractice = true,
  }) async {
    if (limit <= 0) return [];
    final db = await database;

    if (!prioritizePractice) {
      final rows = await db.query(
        table,
        orderBy: 'RANDOM()',
        limit: limit,
      );
      return rows.map(VocabularyItem.fromMap).toList();
    }

    final practiceRows = await db.query(
      table,
      where: 'needs_practice = 1',
      orderBy: 'RANDOM()',
      limit: limit,
    );

    final remaining = limit - practiceRows.length;
    if (remaining <= 0) {
      return practiceRows.map(VocabularyItem.fromMap).toList();
    }

    final excludedIds = practiceRows.map((row) => row['id'] as int).toList();
    final placeholders = List.filled(excludedIds.length, '?').join(', ');
    final fillerRows = await db.query(
      table,
      where: excludedIds.isEmpty ? null : 'id NOT IN ($placeholders)',
      whereArgs: excludedIds.isEmpty ? null : excludedIds,
      orderBy: 'RANDOM()',
      limit: remaining,
    );

    return [...practiceRows, ...fillerRows]
        .map(VocabularyItem.fromMap)
        .toList();
  }
}
