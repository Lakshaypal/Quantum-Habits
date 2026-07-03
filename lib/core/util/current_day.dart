import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'day.dart';

/// The current local calendar day, kept honest across midnight and app
/// resume. Anything that means "today" must watch this instead of calling
/// `DateTime.now()` once at build time — otherwise an app left open past
/// midnight keeps writing and reading yesterday.
final currentDayProvider =
    NotifierProvider<CurrentDayNotifier, DateTime>(CurrentDayNotifier.new);

class CurrentDayNotifier extends Notifier<DateTime> {
  Timer? _midnight;
  AppLifecycleListener? _lifecycle;

  @override
  DateTime build() {
    ref.onDispose(() {
      _midnight?.cancel();
      _lifecycle?.dispose();
    });
    _lifecycle ??= AppLifecycleListener(onResume: _refresh);
    _armMidnightTimer();
    return dayKey(DateTime.now());
  }

  void _refresh() {
    final now = dayKey(DateTime.now());
    if (now != state) state = now;
    _armMidnightTimer();
  }

  void _armMidnightTimer() {
    _midnight?.cancel();
    final now = DateTime.now();
    // A minute past midnight to be safely on the new day's side of any
    // clock fuzziness.
    final next = addDays(dayKey(now), 1).add(const Duration(minutes: 1));
    _midnight = Timer(next.difference(now), _refresh);
  }
}
