// lecture_mode_content.dart
//
// ANVAYA — Lecture Mode's static content: subjects, chant units/cards, and
// Q&A items. Plain data only, no widgets — shared by lecture_mode_screen.dart,
// subject_detail_screen.dart, and flashcard_player_screen.dart.
//
// SANTALI CONTENT CAVEAT: the Latin-script Santali numerals (multiplication
// answers) and weekday names below are best-effort placeholders, in the
// same spirit as database_service.dart's seeded Ol Chiki content — they
// have NOT been checked by a native Santali speaker or FLN curriculum
// expert. Verify before this ships to a real classroom.
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
  const ChantCard({required this.english, required this.santali});

  final String english;
  final String santali;
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
      ChantCard(english: '4 x 1 = 4', santali: 'Pon'),
      ChantCard(english: '4 x 2 = 8', santali: 'Iral'),
      ChantCard(english: '4 x 3 = 12', santali: 'Gel Bar'),
      ChantCard(english: '4 x 4 = 16', santali: 'Gel Turi'),
      ChantCard(english: '4 x 5 = 20', santali: 'Isi'),
    ],
  ),
  ChantUnit(
    title: 'Unit 2: 5 Table',
    cards: [
      ChantCard(english: '5 x 1 = 5', santali: 'Mone'),
      ChantCard(english: '5 x 2 = 10', santali: 'Gel'),
      ChantCard(english: '5 x 3 = 15', santali: 'Gel Mone'),
      ChantCard(english: '5 x 4 = 20', santali: 'Isi'),
      ChantCard(english: '5 x 5 = 25', santali: 'Isi Songe Mone'),
    ],
  ),
];

const List<ChantUnit> languageChantUnits = [
  ChantUnit(
    title: 'Unit 1: Days of the Week',
    cards: [
      ChantCard(english: 'Monday', santali: 'Sombar'),
      ChantCard(english: 'Tuesday', santali: 'Mangalbar'),
      ChantCard(english: 'Wednesday', santali: 'Budhbar'),
      ChantCard(english: 'Thursday', santali: 'Brihaspatibar'),
      ChantCard(english: 'Friday', santali: 'Sukurbar'),
      ChantCard(english: 'Saturday', santali: 'Sanibar'),
      ChantCard(english: 'Sunday', santali: 'Rabibar'),
    ],
  ),
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
  });

  final int index;
  final String question;
  final String answer;
}

const List<LanguageQnAItem> languageQnAItems = [
  LanguageQnAItem(index: 1, question: 'Which animal gives us milk?', answer: 'Cow'),
  LanguageQnAItem(index: 2, question: 'What is the color of tree leaves?', answer: 'Green'),
  LanguageQnAItem(index: 3, question: 'What gives us heat and light during the day?', answer: 'Sun'),
  LanguageQnAItem(index: 4, question: 'What do we drink when we are thirsty?', answer: 'Water'),
  LanguageQnAItem(index: 5, question: 'How many legs does a dog have?', answer: 'Four'),
  LanguageQnAItem(index: 6, question: 'What is the color of the sky?', answer: 'Blue'),
];
