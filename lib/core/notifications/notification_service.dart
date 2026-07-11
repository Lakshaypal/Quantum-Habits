import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/habits/data/habit_schedule.dart';
import '../../features/quotes/quotes.dart';
import '../db/database.dart';
import '../util/day.dart';

/// Local notifications: the daily quote at 5 AM and 5 PM, plus update
/// alerts. Everything is best-effort — a platform without notification
/// support (or a denied permission) must never break the app.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Id ranges: quotes 5000–5279, update alert 9001, habit reminders
  /// 20000–29999, task reminders 30000–39999. Each range is cleared
  /// independently before rescheduling.
  static const _updateId = 9001;
  static const _daysAhead = 14;
  static const _habitBase = 20000;
  static const _habitRange = 10000;
  static const _taskBase = 30000;
  static const _taskRange = 10000;

  static Future<bool> init() async {
    if (_ready) return true;
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const linux = LinuxInitializationSettings(defaultActionName: 'Open');
      const windows = WindowsInitializationSettings(
        appName: 'Quantum Habits',
        appUserModelId: 'com.quantumhabits.quantumHabits',
        guid: '8f4a9c51-2b7e-4d31-9a64-3c61a2b7e905',
      );
      await _plugin.initialize(
        settings: const InitializationSettings(
            android: android, macOS: darwin, iOS: darwin,
            linux: linux, windows: windows),
      );
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      _ready = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          'quotes',
          'Daily quotes',
          channelDescription: 'Quote of the day at 5 AM and 5 PM',
          importance: Importance.defaultImportance,
        ),
        macOS: DarwinNotificationDetails(),
        iOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      );

  /// (Re)schedules the next [_daysAhead] days of quote notifications — call
  /// on every launch/resume so the rolling window stays topped up as long as
  /// the app is opened at least once every two weeks.
  static Future<void> scheduleQuotes({
    required bool enabled,
    required Set<QuoteCategory> cats,
  }) async {
    if (!await init()) return;
    try {
      // Clear previously scheduled quote slots (never the update alert).
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id != _updateId) await _plugin.cancel(id: p.id);
      }
      if (!enabled) return;

      final now = DateTime.now();
      for (var i = 0; i < _daysAhead; i++) {
        final day = addDays(dayKey(now), i);
        final quote = quoteForDay(day, cats);
        for (final (slot, hour, title) in [
          (0, 5, 'Quote of the day'),
          (1, 17, 'Evening reflection'),
        ]) {
          final when = DateTime(day.year, day.month, day.day, hour);
          if (!when.isAfter(now)) continue;
          // Absolute instants need no timezone database lookups: local
          // wall-clock → UTC instant → schedule.
          final at = tz.TZDateTime.from(when.toUtc(), tz.UTC);
          await _plugin.zonedSchedule(
            id: 5000 + i * 10 + slot,
            title: title,
            body: '“${quote.text}” — ${quote.author}',
            scheduledDate: at,
            notificationDetails: _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    } catch (_) {/* platform quirks must never crash the app */}
  }

  static NotificationDetails get _reminderDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_reminders',
          'Habit reminders',
          channelDescription: 'Per-habit reminders at the time you chose',
          importance: Importance.high,
        ),
        macOS: DarwinNotificationDetails(),
        iOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      );

  /// (Re)schedules the next [_daysAhead] days of per-habit reminders. Each
  /// habit with a reminder time fires only on its scheduled days. Call on
  /// launch/resume and whenever habits change.
  static Future<void> scheduleHabitReminders(List<Habit> habits) async {
    if (!await init()) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= _habitBase && p.id < _habitBase + _habitRange) {
          await _plugin.cancel(id: p.id);
        }
      }
      final now = DateTime.now();
      final withReminders = habits
          .where((h) =>
              h.deletedAt == null &&
              !h.archived &&
              h.reminderMinutes != null)
          .toList();
      for (var idx = 0; idx < withReminders.length && idx < 700; idx++) {
        final h = withReminders[idx];
        final sched = scheduleOf(h);
        final mins = h.reminderMinutes!;
        for (var d = 0; d < _daysAhead; d++) {
          final day = addDays(dayKey(now), d);
          if (!sched.isDueOn(day)) continue;
          final when =
              DateTime(day.year, day.month, day.day, mins ~/ 60, mins % 60);
          if (!when.isAfter(now)) continue;
          final at = tz.TZDateTime.from(when.toUtc(), tz.UTC);
          await _plugin.zonedSchedule(
            id: _habitBase + idx * _daysAhead + d,
            title: h.name,
            body: 'Time for ${h.name} — tap to log it.',
            scheduledDate: at,
            notificationDetails: _reminderDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    } catch (_) {/* platform quirks must never crash the app */}
  }

  static NotificationDetails get _taskDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task reminders',
          channelDescription: 'Due tasks, at the time you set',
          importance: Importance.high,
        ),
        macOS: DarwinNotificationDetails(),
        iOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      );

  /// (Re)schedules reminders for open tasks with a due date. Tasks with a due
  /// time fire at that moment; date-only tasks fire at 9 AM on the due day.
  static Future<void> scheduleTaskReminders(List<Task> tasks) async {
    if (!await init()) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.id >= _taskBase && p.id < _taskBase + _taskRange) {
          await _plugin.cancel(id: p.id);
        }
      }
      final now = DateTime.now();
      var id = _taskBase;
      final upcoming = tasks
          .where((t) => !t.done && !t.deleted && t.dueDate != null)
          .toList()
        ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
      for (final task in upcoming.take(200)) {
        final due = task.dueDate!;
        final mins = task.dueMinutes ?? 9 * 60;
        final when =
            DateTime(due.year, due.month, due.day, mins ~/ 60, mins % 60);
        if (!when.isAfter(now)) continue;
        final at = tz.TZDateTime.from(when.toUtc(), tz.UTC);
        await _plugin.zonedSchedule(
          id: id++,
          title: task.title,
          body: task.dueMinutes == null
              ? 'Due today — tap to open your tasks.'
              : 'Due now — tap to open your tasks.',
          scheduledDate: at,
          notificationDetails: _taskDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {/* platform quirks must never crash the app */}
  }

  /// Immediate "a new version exists" alert.
  static Future<void> notifyUpdate(String version, {required bool willAuto}) async {
    if (!await init()) return;
    try {
      await _plugin.show(
        id: _updateId,
        title: 'Quantum Habits $version is available',
        body: willAuto
            ? 'It will install itself the next time you leave the app.'
            : 'Open the app and tap Update to install it.',
        notificationDetails: _details,
      );
    } catch (_) {}
  }
}
