import '../../../core/util/day.dart';

/// A rotating daily writing prompt. 40 prompts → the same one won't recur for
/// well over a month, and it's deterministic per calendar day.
const kJournalPrompts = <String>[
  'What went well today, and what did you do to make it happen?',
  'What is one thing you are grateful for right now?',
  'What drained your energy today? What restored it?',
  'What would make tomorrow a good day?',
  'What did you learn today — about the world or yourself?',
  'Where did you show up as the person you want to be?',
  'What are you avoiding, and what is it costing you?',
  'Describe a small moment today you want to remember.',
  'What is on your mind that you haven’t said out loud?',
  'What would you tell a friend in your exact situation?',
  'What are you proud of this week?',
  'What is one habit that is quietly shaping your life?',
  'If today had a title, what would it be?',
  'What do you need less of? What do you need more of?',
  'Who or what are you taking for granted?',
  'What felt hard today, and how did you handle it?',
  'What are you looking forward to?',
  'What is a belief you are starting to outgrow?',
  'When did you feel most like yourself today?',
  'What would “enough” look like for you right now?',
  'What is a fear you could name and shrink by writing it down?',
  'What did your body tell you today that your mind ignored?',
  'What is one decision you are glad you made?',
  'What would you do differently if no one were watching?',
  'What is a story you keep telling yourself? Is it true?',
  'What gave you a spark of joy today?',
  'What is weighing on you? Set it down here.',
  'What does your ideal ordinary day look like?',
  'What are you curious about lately?',
  'Who did you help today, and how did it feel?',
  'What is one thing you can forgive yourself for?',
  'What would the calmest version of you do next?',
  'What did you resist that turned out fine?',
  'What is a win so small you almost missed it?',
  'What relationship deserves more of your attention?',
  'What is something you want to remember in a year?',
  'What are you building, one day at a time?',
  'What would you say yes to if you trusted yourself more?',
  'What is the kindest thing you can do for tomorrow-you?',
  'Where is your attention going that you wish it wouldn’t?',
];

/// Today's prompt (rolls at midnight, deterministic across devices).
String promptForDay(DateTime day) {
  final idx = daysBetween(DateTime(2024, 1, 1), dayKey(day)) % kJournalPrompts.length;
  return kJournalPrompts[idx < 0 ? idx + kJournalPrompts.length : idx];
}
