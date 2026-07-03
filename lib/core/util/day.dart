/// Normalizes a [DateTime] to local midnight — the canonical key for a "day".
DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whether two timestamps fall on the same local calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Start of the ISO week (Monday) containing [d].
DateTime startOfWeek(DateTime d) {
  final k = dayKey(d);
  return k.subtract(Duration(days: k.weekday - DateTime.monday));
}
