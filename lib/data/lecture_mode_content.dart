// lecture_mode_content.dart
//
// ANVAYA — Lecture Mode's static content: subjects, chant units/cards, and
// Q&A items. Plain data only, no widgets — shared by lecture_mode_screen.dart,
// subject_detail_screen.dart, and flashcard_player_screen.dart.
//
// SANTALI CONTENT CAVEAT: the Latin-script Santali numerals (multiplication
// answers) below are still best-effort placeholders, in the same spirit as
// database_service.dart's seeded Ol Chiki content — they have NOT been
// checked by a native Santali speaker or FLN curriculum expert. Verify
// before this ships to a real classroom. The weekday names in
// languageChantUnits, by contrast, were supplied directly and are treated
// as confirmed-correct.
//
// Math tables are deliberately capped at x5 — Santali numerals past 20
// require compound vigesimal forms ("isi songe...") that would be
// invented with much lower confidence than the single-digit words this
// content is anchored on.

/// The two top-level subjects on [LectureModeScreen].
enum LectureSubject { math, language }

/// One flashcard's content for the Rhythmic Chant player: an English
/// headline (equation or day name) and the Santali translation shown
/// beneath it.
class ChantCard {
  const ChantCard({required this.english, required this.santali, this.audioPath});

  final String english;
  final String santali;

  /// Filename under assets/audio/ (e.g. 'math_4x1.wav'), or null for a
  /// card that doesn't have a recorded clip yet — [FlashcardPlayerScreen]'s
  /// Play button treats null as "nothing to play" rather than erroring.
  final String? audioPath;
}

/// One selectable unit in a subject's Rhythmic Chant tab — opens
/// [FlashcardPlayerScreen] with its [cards].
class ChantUnit {
  const ChantUnit({required this.title, required this.cards});

  final String title;
  final List<ChantCard> cards;
}

const List<ChantUnit> mathChantUnits = [
  ChantUnit(
    title: 'Unit 1: 4 Table',
    cards: [
      ChantCard(english: '4 x 1 = 4', santali: 'Pon', audioPath: 'math_4x1.wav'),
      ChantCard(english: '4 x 2 = 8', santali: 'Iral', audioPath: 'math_4x2.wav'),
      ChantCard(english: '4 x 3 = 12', santali: 'Gel Bar', audioPath: 'math_4x3.wav'),
      ChantCard(english: '4 x 4 = 16', santali: 'Gel Turi', audioPath: 'math_4x4.wav'),
      ChantCard(english: '4 x 5 = 20', santali: 'Isi', audioPath: 'math_4x5.wav'),
    ],
  ),
  ChantUnit(
    title: 'Unit 2: 5 Table',
    cards: [
      ChantCard(english: '5 x 1 = 5', santali: 'Mone', audioPath: 'math_5x1.wav'),
      ChantCard(english: '5 x 2 = 10', santali: 'Gel', audioPath: 'math_5x2.wav'),
      ChantCard(english: '5 x 3 = 15', santali: 'Gel Mone', audioPath: 'math_5x3.wav'),
      ChantCard(english: '5 x 4 = 20', santali: 'Isi', audioPath: 'math_5x4.wav'),
      ChantCard(english: '5 x 5 = 25', santali: 'Isi Songe Mone', audioPath: 'math_5x5.wav'),
    ],
  ),
];

const List<ChantUnit> languageChantUnits = [
  ChantUnit(
    title: 'Unit 1: Days of the Week',
    cards: [
      ChantCard(english: 'Monday', santali: 'Ote maha', audioPath: 'day_monday.wav'),
      ChantCard(english: 'Tuesday', santali: 'Bae maha', audioPath: 'day_tuesday.wav'),
      ChantCard(english: 'Wednesday', santali: 'Sagen maha', audioPath: 'day_wednesday.wav'),
      ChantCard(english: 'Thursday', santali: 'Sardi maha', audioPath: 'day_thursday.wav'),
      ChantCard(english: 'Friday', santali: 'Jarum maha', audioPath: 'day_friday.wav'),
      ChantCard(english: 'Saturday', santali: 'Nuhum maha', audioPath: 'day_saturday.wav'),
      ChantCard(english: 'Sunday', santali: 'Sing maha', audioPath: 'day_sunday.wav'),
    ],
  ),
];

/// English-focused weekday word-puzzle prompts for the "Week 1: Language"
/// worksheet in lecture_assessments_list_screen.dart — replaced that
/// worksheet's earlier "Translate to Santali: `day`" prompts (derived from
/// [languageChantUnits]), since a fill-in/rearrange puzzle exercises
/// English weekday spelling directly rather than translation.
const List<String> languageWeekdayPuzzleQuestions = [
  'Fill in the blank: M _ N D _ Y',
  'What day comes directly after Friday?\n_________________',
  'Rearrange the letters to form a weekday: uesTday -> ________',
];

/// One Math Q&A Practice row.
class MathQnAItem {
  const MathQnAItem({
    required this.index,
    required this.verb,
    required this.equation,
    required this.answerNumber,
    required this.answerSantali,
  });

  final int index;

  /// 'Divide' or 'Multiply'.
  final String verb;
  final String equation;
  final String answerNumber;
  final String answerSantali;
}

/// "Unit 1: Division Practice" on the Math Q&A tab. Numbered 1-4 within
/// its own unit, independent of [mathMultiplicationQnAItems]'s numbering.
const List<MathQnAItem> mathDivisionQnAItems = [
  MathQnAItem(index: 1, verb: 'Divide', equation: '15 ÷ 3', answerNumber: '5', answerSantali: 'Mone'),
  MathQnAItem(index: 2, verb: 'Divide', equation: '20 ÷ 4', answerNumber: '5', answerSantali: 'Mone'),
  MathQnAItem(index: 3, verb: 'Divide', equation: '10 ÷ 2', answerNumber: '5', answerSantali: 'Mone'),
  MathQnAItem(index: 4, verb: 'Divide', equation: '16 ÷ 4', answerNumber: '4', answerSantali: 'Pon'),
];

/// "Unit 2: Multiplication Practice" on the Math Q&A tab.
const List<MathQnAItem> mathMultiplicationQnAItems = [
  MathQnAItem(index: 1, verb: 'Multiply', equation: '4 x 3', answerNumber: '12', answerSantali: 'Gel Bar'),
  MathQnAItem(index: 2, verb: 'Multiply', equation: '5 x 2', answerNumber: '10', answerSantali: 'Gel'),
];

/// One Language (EVS) Q&A Practice row.
class LanguageQnAItem {
  const LanguageQnAItem({
    required this.index,
    required this.question,
    required this.answer,
    this.questionAudioPath,
    this.answerAudioPath,
  });

  final int index;
  final String question;
  final String answer;

  /// Filenames under assets/audio/, or null if that clip doesn't exist
  /// yet — [_LanguageQnARow]'s play buttons dim/disable rather than
  /// erroring when null.
  final String? questionAudioPath;
  final String? answerAudioPath;
}

const List<LanguageQnAItem> languageQnAItems = [
  LanguageQnAItem(
    index: 1,
    question: 'Which animal gives us milk?',
    answer: 'Cow',
    questionAudioPath: 'evs_q1_question.wav',
    answerAudioPath: 'evs_q1_answer.wav',
  ),
  LanguageQnAItem(
    index: 2,
    question: 'What is the color of tree leaves?',
    answer: 'Green',
    questionAudioPath: 'evs_q2_question.wav',
    answerAudioPath: 'evs_q2_answer.wav',
  ),
  LanguageQnAItem(
    index: 3,
    question: 'What gives us heat and light during the day?',
    answer: 'Sun',
    questionAudioPath: 'evs_q3_question.wav',
    answerAudioPath: 'evs_q3_answer.wav',
  ),
  LanguageQnAItem(
    index: 4,
    question: 'What do we drink when we are thirsty?',
    answer: 'Water',
    questionAudioPath: 'evs_q4_question.wav',
    answerAudioPath: 'evs_q4_answer.wav',
  ),
  LanguageQnAItem(
    index: 5,
    question: 'How many legs does a dog have?',
    answer: 'Four',
    questionAudioPath: 'evs_q5_question.wav',
    answerAudioPath: 'evs_q5_answer.wav',
  ),
  LanguageQnAItem(
    index: 6,
    question: 'What is the color of the sky?',
    answer: 'Blue',
    questionAudioPath: 'evs_q6_question.wav',
    answerAudioPath: 'evs_q6_answer.wav',
  ),
];
