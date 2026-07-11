import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/habits/application/habit_providers.dart';
import '../../features/habits/data/habit_schedule.dart';
import '../../features/habits/data/habit_type.dart';
import '../../features/tasks/application/task_providers.dart';
import '../util/current_day.dart';

/// The desktop "widget": a menu-bar (macOS) / system-tray (Windows/Linux)
/// presence showing today at a glance — due habits and tasks, each one click
/// from being logged/completed without opening the window.
///
/// This is the widget approach that works for a directly-distributed app:
/// true macOS WidgetKit widgets require an embedded Swift extension signed
/// with an Apple Developer identity, which unsigned builds can't load.
class TrayService with TrayListener {
  TrayService(this._ref);
  final Ref _ref;
  Timer? _debounce;
  bool _ready = false;

  static bool get supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  Future<void> init() async {
    if (!supported || _ready) return;
    try {
      trayManager.addListener(this);
      await trayManager.setIcon(
        Platform.isWindows
            ? 'assets/tray/tray_icon.ico'
            : 'assets/tray/tray_icon.png',
        isTemplate: true, // macOS recolors for light/dark menu bars
      );
      _ready = true;
      refresh();
    } catch (_) {/* tray is a bonus surface — never break the app for it */}
  }

  /// Debounced rebuild of the tray menu from current data.
  void refresh() {
    if (!_ready) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _rebuild);
  }

  Future<void> _rebuild() async {
    try {
      final today = _ref.read(currentDayProvider);
      final habits =
          _ref.read(activeHabitsProvider).asData?.value ?? const [];
      final entries =
          _ref.read(todayEntriesProvider).asData?.value ?? const [];
      final buckets = _ref.read(taskBucketsProvider);
      final entryByHabit = {for (final e in entries) e.habitId: e};

      final dueHabits = habits
          .where((h) =>
              scheduleOf(h).isDueOn(today) || entryByHabit.containsKey(h.id))
          .toList();
      final doneCount = dueHabits
          .where((h) => entryByHabit[h.id]?.completed ?? false)
          .length;

      final items = <MenuItem>[
        MenuItem(
          label:
              'Today · $doneCount of ${dueHabits.length} habits · ${buckets.overdue.length + buckets.today.length} tasks due',
          disabled: true,
        ),
        MenuItem.separator(),
      ];

      for (final h in dueHabits.take(8)) {
        final entry = entryByHabit[h.id];
        final done = entry?.completed ?? false;
        items.add(MenuItem(
          label: '${done ? '✓' : '○'}  ${h.name}',
          disabled: done,
          onClick: (_) async {
            final service = _ref.read(habitServiceProvider);
            final now = DateTime.now();
            if (HabitTypeX.fromIndex(h.type) == HabitType.binary) {
              await service.toggleBinary(h, now);
            } else {
              await service.increment(h, now);
            }
          },
        ));
      }

      final dueTasks = [...buckets.overdue, ...buckets.today];
      if (dueTasks.isNotEmpty) {
        items.add(MenuItem.separator());
        for (final task in dueTasks.take(6)) {
          items.add(MenuItem(
            label: '☐  ${task.title}',
            onClick: (_) =>
                _ref.read(taskServiceProvider).setDone(task.id, true),
          ));
        }
      }

      items.addAll([
        MenuItem.separator(),
        MenuItem(
          label: 'Open Quantum Habits',
          onClick: (_) => _showWindow(),
        ),
        MenuItem(label: 'Quit', onClick: (_) => exit(0)),
      ]);

      await trayManager.setContextMenu(Menu(items: items));
      await trayManager.setToolTip(
          'Quantum Habits — $doneCount/${dueHabits.length} today');
    } catch (_) {/* keep the app alive regardless of tray errors */}
  }

  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  @override
  void onTrayIconMouseDown() {
    // Left-click: pop the menu on all platforms (macOS does this natively
    // for right-click; make left-click behave the same everywhere).
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  void dispose() {
    _debounce?.cancel();
    if (_ready) trayManager.removeListener(this);
  }
}

final trayServiceProvider = Provider<TrayService>((ref) {
  final service = TrayService(ref);
  ref.onDispose(service.dispose);
  return service;
});
