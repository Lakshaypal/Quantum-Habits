import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/quotes/quotes.dart';
import '../util/day.dart';

/// Local notifications: the daily quote at 5 AM and 5 PM, plus update
/// alerts. Everything is best-effort — a platform without notification
/// support (or a denied permission) must never break the app.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Ids: 5xx0 = morning of day-offset x, 5xx1 = evening. Update alert = 9001.
  static const _updateId = 9001;
  static const _daysAhead = 14;

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
