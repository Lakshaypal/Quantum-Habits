/// Normalizes a [DateTime] to local midnight — the canonical key for a "day".
DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whether two timestamps fall on the same local calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Steps [day] by [n] calendar days. DST-safe: unlike
/// `add(Duration(days: n))`, this always lands on local midnight (Dart
/// normalizes day overflow), so map lookups keyed by [dayKey] keep working
/// across daylight-saving transitions.
DateTime addDays(DateTime day, int n) =>
    DateTime(day.year, day.month, day.day + n);

/// Calendar-day distance from [a] to [b] (positive when b is later).
/// Computed in UTC so DST can't make a "day" 23 or 25 hours.
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

/// Start of the ISO week (Monday) containing [d].
DateTime startOfWeek(DateTime d) {
  final k = dayKey(d);
  return addDays(k, -(k.weekday - DateTime.monday));
}
