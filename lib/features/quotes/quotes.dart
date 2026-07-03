import 'package:flutter_riverpod/flutter_riverpod.dart';

class Quote {
  final String text;
  final String author;
  final String field;
  const Quote(this.text, this.author, this.field);
}

/// Seed set spanning the scientists & fields in the spec. Daily-rotating;
/// user-extensible later.
const kQuotes = <Quote>[
  Quote('The important thing is not to stop questioning. Curiosity has its own reason for existing.',
      'Albert Einstein', 'Physics'),
  Quote('The first principle is that you must not fool yourself — and you are the easiest person to fool.',
      'Richard Feynman', 'Physics'),
  Quote('Somewhere, something incredible is waiting to be known.', 'Carl Sagan', 'Astrophysics'),
  Quote('Both the man of science and the man of action live always at the edge of mystery, surrounded by it.',
      'J. Robert Oppenheimer', 'Physics'),
  Quote('The present is theirs; the future, for which I really worked, is mine.',
      'Nikola Tesla', 'Engineering'),
  Quote('We can only see a short distance ahead, but we can see plenty there that needs to be done.',
      'Alan Turing', 'Computing'),
  Quote("The most dangerous phrase in the language is, 'We've always done it this way.'",
      'Grace Hopper', 'Computing'),
  Quote('If people do not believe that mathematics is simple, it is only because they do not realize how complicated life is.',
      'John von Neumann', 'Mathematics'),
  Quote('Like what you do, and then you will do your best.', 'Katherine Johnson', 'Mathematics'),
  Quote('I just wondered how things were put together.', 'Claude Shannon', 'Computing'),
  Quote('The only way to learn a new programming language is by writing programs in it.',
      'Dennis Ritchie', 'Computing'),
  Quote('There was no choice but to be pioneers.', 'Margaret Hamilton', 'Engineering'),
  Quote('The Analytical Engine weaves algebraic patterns, just as the loom weaves flowers and leaves.',
      'Ada Lovelace', 'Computing'),
  Quote('To recognize a cat, the machine first has to learn to see.', 'Fei-Fei Li', 'AI'),
  Quote('The hottest new programming language is English.', 'Andrej Karpathy', 'AI'),
  Quote('The world is its own best model.', 'Rodney Brooks', 'Robotics'),
  Quote('Research is what I am doing when I do not know what I am doing.',
      'Wernher von Braun', 'Engineering'),
  Quote('Intelligence is the ability to adapt to change.', 'Stephen Hawking', 'Astrophysics'),
  Quote('The brain computes in ways we are only beginning to imitate.', 'Geoffrey Hinton', 'AI'),
];

/// Deterministic per-day rotation so the quote is stable across a calendar day.
final quoteOfTheDayProvider = Provider<Quote>((ref) {
  final now = DateTime.now();
  final dayOfYear = now.difference(DateTime(now.year)).inDays;
  return kQuotes[dayOfYear % kQuotes.length];
});
