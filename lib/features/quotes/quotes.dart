import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/current_day.dart';
import '../../core/util/day.dart';
import '../habits/application/habit_providers.dart' show databaseProvider;

/// Who the user wants to hear from. Multi-select, persisted + synced.
enum QuoteCategory {
  writers('Writers & Poets'),
  philosophers('Philosophers'),
  scientists('Scientists & Inventors'),
  doctors('Doctors & Healers'),
  finance('Business & Finance');

  final String label;
  const QuoteCategory(this.label);
}

class Quote {
  final String text;
  final String author;
  final String field;
  final QuoteCategory category;
  const Quote(this.text, this.author, this.field, this.category);
}

const _w = QuoteCategory.writers;
const _p = QuoteCategory.philosophers;
const _s = QuoteCategory.scientists;
const _d = QuoteCategory.doctors;
const _f = QuoteCategory.finance;

/// ~195 quotes across five voices. With every category enabled (the
/// default) the daily rotation runs 190+ days without a repeat — beyond six
/// months. Narrowing categories narrows the pool proportionally.
const kQuotes = <Quote>[
  // ---- Writers & Poets ----
  Quote('We know what we are, but know not what we may be.', 'William Shakespeare', 'Playwright', _w),
  Quote('It is not in the stars to hold our destiny but in ourselves.', 'William Shakespeare', 'Playwright', _w),
  Quote('Better three hours too soon than a minute too late.', 'William Shakespeare', 'Playwright', _w),
  Quote('Our doubts are traitors, and make us lose the good we oft might win by fearing to attempt.', 'William Shakespeare', 'Playwright', _w),
  Quote('There is nothing to writing. All you do is sit down at a typewriter and bleed.', 'Ernest Hemingway', 'Novelist', _w),
  Quote('We are all in the gutter, but some of us are looking at the stars.', 'Oscar Wilde', 'Writer', _w),
  Quote('Be yourself; everyone else is already taken.', 'Oscar Wilde', 'Writer', _w),
  Quote('The secret of getting ahead is getting started.', 'Mark Twain', 'Writer', _w),
  Quote('Courage is resistance to fear, mastery of fear — not absence of fear.', 'Mark Twain', 'Writer', _w),
  Quote('It is never too late to be what you might have been.', 'George Eliot', 'Novelist', _w),
  Quote('And now that you don’t have to be perfect, you can be good.', 'John Steinbeck', 'Novelist', _w),
  Quote('Beware; for I am fearless, and therefore powerful.', 'Mary Shelley', 'Novelist', _w),
  Quote('There is no greater agony than bearing an untold story inside you.', 'Maya Angelou', 'Poet', _w),
  Quote('You may not control all the events that happen to you, but you can decide not to be reduced by them.', 'Maya Angelou', 'Poet', _w),
  Quote('Hope is the thing with feathers that perches in the soul.', 'Emily Dickinson', 'Poet', _w),
  Quote('Two roads diverged in a wood, and I took the one less traveled by.', 'Robert Frost', 'Poet', _w),
  Quote('The best way out is always through.', 'Robert Frost', 'Poet', _w),
  Quote('Keep your face always toward the sunshine, and shadows will fall behind you.', 'Walt Whitman', 'Poet', _w),
  Quote('Happiness in intelligent people is the rarest thing I know.', 'Ernest Hemingway', 'Novelist', _w),
  Quote('A reader lives a thousand lives before he dies.', 'George R.R. Martin', 'Novelist', _w),
  Quote('It does not do to dwell on dreams and forget to live.', 'J.K. Rowling', 'Novelist', _w),
  Quote('Not all those who wander are lost.', 'J.R.R. Tolkien', 'Novelist', _w),
  Quote('The beginning is always today.', 'Mary Wollstonecraft', 'Writer', _w),
  Quote('If you want to be a writer, you must do two things above all others: read a lot and write a lot.', 'Stephen King', 'Novelist', _w),
  Quote('The world breaks everyone, and afterward, many are strong at the broken places.', 'Ernest Hemingway', 'Novelist', _w),
  Quote('What matters in life is not what happens to you but what you remember and how you remember it.', 'Gabriel García Márquez', 'Novelist', _w),
  Quote('It is only with the heart that one can see rightly; what is essential is invisible to the eye.', 'Antoine de Saint-Exupéry', 'Writer', _w),
  Quote('A goal without a plan is just a wish.', 'Antoine de Saint-Exupéry', 'Writer', _w),
  Quote('Do not go gentle into that good night.', 'Dylan Thomas', 'Poet', _w),
  Quote('We write to taste life twice, in the moment and in retrospect.', 'Anaïs Nin', 'Writer', _w),
  Quote('And the day came when the risk to remain tight in a bud was more painful than the risk it took to blossom.', 'Anaïs Nin', 'Writer', _w),
  Quote('Tomorrow is always fresh, with no mistakes in it yet.', 'L.M. Montgomery', 'Novelist', _w),
  Quote('All that is gold does not glitter.', 'J.R.R. Tolkien', 'Novelist', _w),
  Quote('The man who does not read has no advantage over the man who cannot read.', 'Mark Twain', 'Writer', _w),
  Quote('Perhaps one did not want to be loved so much as to be understood.', 'George Orwell', 'Novelist', _w),
  Quote('Everything you can imagine is real.', 'Pablo Picasso', 'Artist', _w),
  Quote('No tears in the writer, no tears in the reader.', 'Robert Frost', 'Poet', _w),
  Quote('You can make anything by writing.', 'C.S. Lewis', 'Novelist', _w),

  // ---- Philosophers ----
  Quote('The unexamined life is not worth living.', 'Socrates', 'Philosophy', _p),
  Quote('I know that I know nothing.', 'Socrates', 'Philosophy', _p),
  Quote('We are what we repeatedly do. Excellence, then, is not an act, but a habit.', 'Will Durant, on Aristotle', 'Philosophy', _p),
  Quote('It is the mark of an educated mind to be able to entertain a thought without accepting it.', 'Aristotle', 'Philosophy', _p),
  Quote('Knowing yourself is the beginning of all wisdom.', 'Aristotle', 'Philosophy', _p),
  Quote('The happiness of your life depends upon the quality of your thoughts.', 'Marcus Aurelius', 'Stoicism', _p),
  Quote('Waste no more time arguing about what a good man should be. Be one.', 'Marcus Aurelius', 'Stoicism', _p),
  Quote('You have power over your mind — not outside events. Realize this, and you will find strength.', 'Marcus Aurelius', 'Stoicism', _p),
  Quote('We suffer more often in imagination than in reality.', 'Seneca', 'Stoicism', _p),
  Quote('Luck is what happens when preparation meets opportunity.', 'Seneca', 'Stoicism', _p),
  Quote('It is not that we have a short time to live, but that we waste a lot of it.', 'Seneca', 'Stoicism', _p),
  Quote('No man is free who is not master of himself.', 'Epictetus', 'Stoicism', _p),
  Quote('First say to yourself what you would be; and then do what you have to do.', 'Epictetus', 'Stoicism', _p),
  Quote('It does not matter how slowly you go as long as you do not stop.', 'Confucius', 'Philosophy', _p),
  Quote('The man who moves a mountain begins by carrying away small stones.', 'Confucius', 'Philosophy', _p),
  Quote('Our greatest glory is not in never falling, but in rising every time we fall.', 'Confucius', 'Philosophy', _p),
  Quote('A journey of a thousand miles begins with a single step.', 'Laozi', 'Taoism', _p),
  Quote('Nature does not hurry, yet everything is accomplished.', 'Laozi', 'Taoism', _p),
  Quote('Knowing others is intelligence; knowing yourself is true wisdom.', 'Laozi', 'Taoism', _p),
  Quote('He who has a why to live can bear almost any how.', 'Friedrich Nietzsche', 'Philosophy', _p),
  Quote('That which does not kill us makes us stronger.', 'Friedrich Nietzsche', 'Philosophy', _p),
  Quote('There is no path to happiness: happiness is the path.', 'Buddhist teaching', 'Buddhism', _p),
  Quote('What we think, we become.', 'Buddhist teaching', 'Buddhism', _p),
  Quote('No man ever steps in the same river twice.', 'Heraclitus', 'Philosophy', _p),
  Quote('Character is destiny.', 'Heraclitus', 'Philosophy', _p),
  Quote('I think, therefore I am.', 'René Descartes', 'Philosophy', _p),
  Quote('It is not enough to have a good mind; the main thing is to use it well.', 'René Descartes', 'Philosophy', _p),
  Quote('Life can only be understood backwards; but it must be lived forwards.', 'Søren Kierkegaard', 'Existentialism', _p),
  Quote('Anxiety is the dizziness of freedom.', 'Søren Kierkegaard', 'Existentialism', _p),
  Quote('One is not born, but rather becomes, oneself.', 'Simone de Beauvoir', 'Existentialism', _p),
  Quote('In the depth of winter, I finally learned that within me there lay an invincible summer.', 'Albert Camus', 'Existentialism', _p),
  Quote('Real generosity toward the future lies in giving all to the present.', 'Albert Camus', 'Existentialism', _p),
  Quote('The limits of my language mean the limits of my world.', 'Ludwig Wittgenstein', 'Philosophy', _p),
  Quote('The good life is one inspired by love and guided by knowledge.', 'Bertrand Russell', 'Philosophy', _p),
  Quote('Do every act of your life as though it were the very last act of your life.', 'Marcus Aurelius', 'Stoicism', _p),
  Quote('Rule your mind or it will rule you.', 'Horace', 'Philosophy', _p),
  Quote('Freedom is what you do with what’s been done to you.', 'Jean-Paul Sartre', 'Existentialism', _p),
  Quote('Man is condemned to be free.', 'Jean-Paul Sartre', 'Existentialism', _p),

  // ---- Scientists & Inventors ----
  Quote('Life is like riding a bicycle. To keep your balance you must keep moving.', 'Albert Einstein', 'Physics', _s),
  Quote('It’s not that I’m so smart, it’s just that I stay with problems longer.', 'Albert Einstein', 'Physics', _s),
  Quote('The important thing is not to stop questioning. Curiosity has its own reason for existing.', 'Albert Einstein', 'Physics', _s),
  Quote('If I have seen further it is by standing on the shoulders of giants.', 'Isaac Newton', 'Physics', _s),
  Quote('Nothing in life is to be feared, it is only to be understood.', 'Marie Curie', 'Chemistry', _s),
  Quote('Be less curious about people and more curious about ideas.', 'Marie Curie', 'Chemistry', _s),
  Quote('I have not failed. I’ve just found 10,000 ways that won’t work.', 'Thomas Edison', 'Invention', _s),
  Quote('Genius is one percent inspiration and ninety-nine percent perspiration.', 'Thomas Edison', 'Invention', _s),
  Quote('The first principle is that you must not fool yourself — and you are the easiest person to fool.', 'Richard Feynman', 'Physics', _s),
  Quote('What I cannot create, I do not understand.', 'Richard Feynman', 'Physics', _s),
  Quote('Somewhere, something incredible is waiting to be known.', 'Carl Sagan', 'Astronomy', _s),
  Quote('The cosmos is within us. We are made of star-stuff.', 'Carl Sagan', 'Astronomy', _s),
  Quote('A man who dares to waste one hour of time has not discovered the value of life.', 'Charles Darwin', 'Biology', _s),
  Quote('The present is theirs; the future, for which I really worked, is mine.', 'Nikola Tesla', 'Engineering', _s),
  Quote('Measure what is measurable, and make measurable what is not so.', 'Galileo Galilei', 'Astronomy', _s),
  Quote('However difficult life may seem, there is always something you can do and succeed at.', 'Stephen Hawking', 'Astrophysics', _s),
  Quote('Intelligence is the ability to adapt to change.', 'Stephen Hawking', 'Astrophysics', _s),
  Quote('Chance favors the prepared mind.', 'Louis Pasteur', 'Microbiology', _s),
  Quote('The Analytical Engine weaves algebraic patterns, just as the loom weaves flowers and leaves.', 'Ada Lovelace', 'Computing', _s),
  Quote('We can only see a short distance ahead, but we can see plenty there that needs to be done.', 'Alan Turing', 'Computing', _s),
  Quote('The most dangerous phrase in the language is, “We’ve always done it this way.”', 'Grace Hopper', 'Computing', _s),
  Quote('A ship in port is safe, but that is not what ships are built for.', 'Grace Hopper', 'Computing', _s),
  Quote('Nothing is too wonderful to be true, if it be consistent with the laws of nature.', 'Michael Faraday', 'Physics', _s),
  Quote('An expert is a person who has made all the mistakes that can be made in a very narrow field.', 'Niels Bohr', 'Physics', _s),
  Quote('Prediction is very difficult, especially about the future.', 'Niels Bohr', 'Physics', _s),
  Quote('Science is a way of thinking much more than it is a body of knowledge.', 'Carl Sagan', 'Astronomy', _s),
  Quote('Learning never exhausts the mind.', 'Leonardo da Vinci', 'Polymath', _s),
  Quote('Simplicity is the ultimate sophistication.', 'Leonardo da Vinci', 'Polymath', _s),
  Quote('I was taught that the way of progress was neither swift nor easy.', 'Marie Curie', 'Chemistry', _s),
  Quote('Both the man of science and the man of action live always at the edge of mystery, surrounded by it.', 'J. Robert Oppenheimer', 'Physics', _s),
  Quote('If people do not believe that mathematics is simple, it is only because they do not realize how complicated life is.', 'John von Neumann', 'Mathematics', _s),
  Quote('Like what you do, and then you will do your best.', 'Katherine Johnson', 'Mathematics', _s),
  Quote('I just wondered how things were put together.', 'Claude Shannon', 'Computing', _s),
  Quote('The only way to learn a new programming language is by writing programs in it.', 'Dennis Ritchie', 'Computing', _s),
  Quote('There was no choice but to be pioneers.', 'Margaret Hamilton', 'Engineering', _s),
  Quote('To recognize a cat, the machine first has to learn to see.', 'Fei-Fei Li', 'AI', _s),
  Quote('The hottest new programming language is English.', 'Andrej Karpathy', 'AI', _s),
  Quote('The world is its own best model.', 'Rodney Brooks', 'Robotics', _s),
  Quote('Research is what I am doing when I do not know what I am doing.', 'Wernher von Braun', 'Engineering', _s),
  Quote('The brain computes in ways we are only beginning to imitate.', 'Geoffrey Hinton', 'AI', _s),

  // ---- Doctors & Healers ----
  Quote('Wherever the art of medicine is loved, there is also a love of humanity.', 'Hippocrates', 'Medicine', _d),
  Quote('Healing is a matter of time, but it is sometimes also a matter of opportunity.', 'Hippocrates', 'Medicine', _d),
  Quote('Walking is man’s best medicine.', 'Hippocrates', 'Medicine', _d),
  Quote('Everything in excess is opposed to nature.', 'Hippocrates', 'Medicine', _d),
  Quote('The good physician treats the disease; the great physician treats the patient who has the disease.', 'William Osler', 'Medicine', _d),
  Quote('The best preparation for tomorrow is to do today’s work superbly well.', 'William Osler', 'Medicine', _d),
  Quote('Medicine is a science of uncertainty and an art of probability.', 'William Osler', 'Medicine', _d),
  Quote('It is much more important to know what sort of a patient has a disease than what sort of a disease a patient has.', 'William Osler', 'Medicine', _d),
  Quote('I attribute my success to this — I never gave or took any excuse.', 'Florence Nightingale', 'Nursing', _d),
  Quote('Live your life while you have it. Life is a splendid gift.', 'Florence Nightingale', 'Nursing', _d),
  Quote('Rather, ten times, die in the surf, heralding the way to a new world, than stand idly on the shore.', 'Florence Nightingale', 'Nursing', _d),
  Quote('The secret of the care of the patient is in caring for the patient.', 'Francis W. Peabody', 'Medicine', _d),
  Quote('To cure sometimes, to relieve often, to comfort always.', 'Edward Trudeau', 'Medicine', _d),
  Quote('When you hear hoofbeats, think of horses, not zebras.', 'Theodore Woodward', 'Medicine', _d),
  Quote('The aim of medicine is to prevent disease and prolong life; the ideal of medicine is to eliminate the need of a physician.', 'William J. Mayo', 'Medicine', _d),
  Quote('The best interest of the patient is the only interest to be considered.', 'William J. Mayo', 'Medicine', _d),
  Quote('None of us is as smart as all of us.', 'Charles H. Mayo', 'Medicine', _d),
  Quote('It is not the strength of the body that counts, but the strength of the spirit.', 'Albert Schweitzer', 'Medicine', _d),
  Quote('Success is not the key to happiness. Happiness is the key to success.', 'Albert Schweitzer', 'Medicine', _d),
  Quote('The purpose of human life is to serve, and to show compassion and the will to help others.', 'Albert Schweitzer', 'Medicine', _d),
  Quote('In each of us there is another whom we do not know.', 'Carl Jung', 'Psychiatry', _d),
  Quote('I am not what happened to me, I am what I choose to become.', 'Carl Jung', 'Psychiatry', _d),
  Quote('Everything that irritates us about others can lead us to an understanding of ourselves.', 'Carl Jung', 'Psychiatry', _d),
  Quote('When we are no longer able to change a situation, we are challenged to change ourselves.', 'Viktor Frankl', 'Psychiatry', _d),
  Quote('Between stimulus and response there is a space. In that space is our power to choose our response.', 'Viktor Frankl', 'Psychiatry', _d),
  Quote('Those who have a “why” to live can bear with almost any “how”.', 'Viktor Frankl', 'Psychiatry', _d),
  Quote('One sometimes finds what one is not looking for.', 'Alexander Fleming', 'Medicine', _d),
  Quote('Sleep is the golden chain that ties health and our bodies together.', 'Thomas Dekker', 'Medicine', _d),
  Quote('He who has health has hope; and he who has hope has everything.', 'Proverb (healer’s wisdom)', 'Medicine', _d),
  Quote('The greatest medicine of all is to teach people how not to need it.', 'Hippocratic school', 'Medicine', _d),
  Quote('Wherever a doctor cannot do good, he must be kept from doing harm.', 'Hippocrates', 'Medicine', _d),
  Quote('The doctor of the future will interest his patients in the care of the human frame, in diet, and in the cause and prevention of disease.', 'Thomas Edison, on medicine', 'Medicine', _d),
  Quote('Observation, Reason, Human Understanding, Courage; these make the physician.', 'Martin H. Fischer', 'Medicine', _d),
  Quote('A good laugh and a long sleep are the best cures in the doctor’s book.', 'Irish proverb (healer’s wisdom)', 'Medicine', _d),
  Quote('Prevention is better than cure.', 'Desiderius Erasmus', 'Medicine', _d),
  Quote('The art of medicine consists of amusing the patient while nature cures the disease.', 'Voltaire, on medicine', 'Medicine', _d),
  Quote('Where there is love of man, there is also love of the art.', 'Hippocrates', 'Medicine', _d),
  Quote('Cure occasionally, relieve often, console always.', 'Ambroise Paré', 'Medicine', _d),

  // ---- Business & Finance ----
  Quote('Price is what you pay. Value is what you get.', 'Warren Buffett', 'Investing', _f),
  Quote('Someone’s sitting in the shade today because someone planted a tree a long time ago.', 'Warren Buffett', 'Investing', _f),
  Quote('The most important investment you can make is in yourself.', 'Warren Buffett', 'Investing', _f),
  Quote('It takes 20 years to build a reputation and five minutes to ruin it.', 'Warren Buffett', 'Investing', _f),
  Quote('Risk comes from not knowing what you are doing.', 'Warren Buffett', 'Investing', _f),
  Quote('Accounting is the language of business.', 'Warren Buffett', 'Accounting', _f),
  Quote('The big money is not in the buying and selling, but in the waiting.', 'Charlie Munger', 'Investing', _f),
  Quote('Spend each day trying to be a little wiser than you were when you woke up.', 'Charlie Munger', 'Investing', _f),
  Quote('Take a simple idea and take it seriously.', 'Charlie Munger', 'Investing', _f),
  Quote('The investor’s chief problem — and even his worst enemy — is likely to be himself.', 'Benjamin Graham', 'Investing', _f),
  Quote('In the short run, the market is a voting machine but in the long run, it is a weighing machine.', 'Benjamin Graham', 'Investing', _f),
  Quote('An investment in knowledge pays the best interest.', 'Benjamin Franklin', 'Finance', _f),
  Quote('Beware of little expenses; a small leak will sink a great ship.', 'Benjamin Franklin', 'Finance', _f),
  Quote('Well done is better than well said.', 'Benjamin Franklin', 'Finance', _f),
  Quote('The best way to predict the future is to create it.', 'Peter Drucker', 'Management', _f),
  Quote('What gets measured gets managed.', 'Peter Drucker', 'Management', _f),
  Quote('There is nothing so useless as doing efficiently that which should not be done at all.', 'Peter Drucker', 'Management', _f),
  Quote('Whether you think you can, or you think you can’t — you’re right.', 'Henry Ford', 'Industry', _f),
  Quote('Quality means doing it right when no one is looking.', 'Henry Ford', 'Industry', _f),
  Quote('Coming together is a beginning; keeping together is progress; working together is success.', 'Henry Ford', 'Industry', _f),
  Quote('Don’t be afraid to give up the good to go for the great.', 'John D. Rockefeller', 'Industry', _f),
  Quote('I do not think there is any other quality so essential to success as perseverance.', 'John D. Rockefeller', 'Industry', _f),
  Quote('The way to get started is to quit talking and begin doing.', 'Walt Disney', 'Entrepreneurship', _f),
  Quote('Your time is limited, so don’t waste it living someone else’s life.', 'Steve Jobs', 'Entrepreneurship', _f),
  Quote('Innovation distinguishes between a leader and a follower.', 'Steve Jobs', 'Entrepreneurship', _f),
  Quote('Stay hungry, stay foolish.', 'Steve Jobs', 'Entrepreneurship', _f),
  Quote('Time in the market beats timing the market.', 'Investing maxim (Bogleheads)', 'Investing', _f),
  Quote('Don’t look for the needle in the haystack. Just buy the haystack.', 'Jack Bogle', 'Investing', _f),
  Quote('Know what you own, and know why you own it.', 'Peter Lynch', 'Investing', _f),
  Quote('In this business, if you’re good, you’re right six times out of ten.', 'Peter Lynch', 'Investing', _f),
  Quote('Pain plus reflection equals progress.', 'Ray Dalio', 'Investing', _f),
  Quote('He who lives by the crystal ball will eat shattered glass.', 'Ray Dalio', 'Investing', _f),
  Quote('Do not save what is left after spending, but spend what is left after saving.', 'Warren Buffett (attr.)', 'Finance', _f),
  Quote('A budget tells us what we can’t afford, but it doesn’t keep us from buying it.', 'William Feather', 'Finance', _f),
  Quote('High expectations are the key to everything.', 'Sam Walton', 'Retail', _f),
  Quote('Compound interest is the eighth wonder of the world.', 'Attributed to Einstein (finance lore)', 'Finance', _f),
  Quote('He who understands interest, earns it; he who doesn’t, pays it.', 'Proverb of compounding', 'Finance', _f),
  Quote('Opportunities come infrequently. When it rains gold, put out the bucket, not the thimble.', 'Warren Buffett', 'Investing', _f),
];

const _kQuoteCatsKey = 'pref_quote_cats';

/// Selected quote categories. Persisted in KeyValues (so it syncs) and kept
/// live across devices via watchKV.
final quoteCategoriesProvider =
    NotifierProvider<QuoteCategoriesNotifier, Set<QuoteCategory>>(
        QuoteCategoriesNotifier.new);

class QuoteCategoriesNotifier extends Notifier<Set<QuoteCategory>> {
  @override
  Set<QuoteCategory> build() {
    final sub = ref
        .read(databaseProvider)
        .watchKV(_kQuoteCatsKey)
        .listen((v) => state = decodeCats(v));
    ref.onDispose(sub.cancel);
    return QuoteCategory.values.toSet();
  }

  Future<void> toggle(QuoteCategory cat) async {
    final next = {...state};
    if (next.contains(cat)) {
      if (next.length == 1) return; // never allow an empty pool
      next.remove(cat);
    } else {
      next.add(cat);
    }
    state = next;
    await ref
        .read(databaseProvider)
        .setKV(_kQuoteCatsKey, next.map((c) => c.name).join(','));
  }

  static Set<QuoteCategory> decodeCats(String? csv) {
    if (csv == null || csv.trim().isEmpty) return QuoteCategory.values.toSet();
    final names = csv.split(',').map((s) => s.trim()).toSet();
    final cats =
        QuoteCategory.values.where((c) => names.contains(c.name)).toSet();
    return cats.isEmpty ? QuoteCategory.values.toSet() : cats;
  }
}

const _kQuoteNotifsKey = 'pref_quote_notifs';

/// Whether the 5 AM / 5 PM quote notifications are on (per-device).
final quoteNotificationsProvider =
    NotifierProvider<QuoteNotificationsNotifier, bool>(
        QuoteNotificationsNotifier.new);

class QuoteNotificationsNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref
        .read(databaseProvider)
        .getKV(_kQuoteNotifsKey)
        .then((v) => state = v != '0');
    return true;
  }

  Future<void> set(bool on) async {
    state = on;
    await ref.read(databaseProvider).setKV(_kQuoteNotifsKey, on ? '1' : '0');
  }
}

/// Deterministic pool for a category selection — same order on every device.
List<Quote> quotePool(Set<QuoteCategory> cats) =>
    kQuotes.where((q) => cats.contains(q.category)).toList();

/// The quote for an arbitrary calendar day. Days step through the pool one
/// by one from a fixed epoch, so within any window up to the pool's size
/// (190+ days with all categories on) no quote repeats — and future days are
/// computable ahead of time for scheduled notifications.
Quote quoteForDay(DateTime day, Set<QuoteCategory> cats) {
  final pool = quotePool(cats);
  final idx = daysBetween(DateTime(2024, 1, 1), dayKey(day)) % pool.length;
  return pool[idx < 0 ? idx + pool.length : idx];
}

/// Today's quote — rolls at midnight, reacts to category changes.
final quoteOfTheDayProvider = Provider<Quote>((ref) {
  final today = ref.watch(currentDayProvider);
  final cats = ref.watch(quoteCategoriesProvider);
  return quoteForDay(today, cats);
});
