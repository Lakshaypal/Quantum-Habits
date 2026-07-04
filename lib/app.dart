import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/habits/application/habit_providers.dart'
    show databaseProvider;
import 'features/journal/application/journal_providers.dart';
import 'features/quotes/quotes.dart';
import 'features/shell/presentation/root_shell.dart';
import 'features/sync/application/sync_engine.dart';
import 'features/updates/update_service.dart';

class QuantumHabitsApp extends ConsumerStatefulWidget {
  const QuantumHabitsApp({super.key});

  @override
  ConsumerState<QuantumHabitsApp> createState() => _QuantumHabitsAppState();
}

class _QuantumHabitsAppState extends ConsumerState<QuantumHabitsApp> {
  UpdateInfo? _pendingAutoInstall;
  bool _installing = false;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // Bring the sync engine to life at launch (it self-connects from stored
    // credentials) and let pulled data reset security-sensitive journal state:
    // a vault from another device may carry a new salt/verifier, so cached
    // "has passphrase" state must refresh and the session must re-lock.
    final engine = ref.read(syncEngineProvider.notifier);
    engine.onRemoteApplied = (applied) {
      final keysChanged =
          applied.keyValues.any((kv) => kv.key.startsWith('journal_'));
      if (keysChanged) {
        ref.read(journalSessionProvider.notifier).lock();
        ref.invalidate(hasPassphraseProvider);
      }
    };

    // Quote notifications: top up the rolling 14-day schedule on launch and
    // resume, and reschedule whenever the categories or the toggle change.
    Future.delayed(const Duration(seconds: 2), _rescheduleQuotes);
    ref.listenManual(quoteCategoriesProvider, (_, _) => _rescheduleQuotes());
    ref.listenManual(quoteNotificationsProvider, (_, _) => _rescheduleQuotes());
    _lifecycle = AppLifecycleListener(
      onResume: _rescheduleQuotes,
      // "Updates itself without asking": the silent install runs the moment
      // the user switches away, so the restart never interrupts them.
      onInactive: _maybeAutoInstall,
      onHide: _maybeAutoInstall,
    );

    // Self-updates: quietly look for a newer release shortly after launch
    // (throttled inside autoCheck); notify, and on desktop with automatic
    // updates on, arm the silent install.
    Future.delayed(const Duration(seconds: 4), () async {
      if (!mounted) return;
      final found = await ref
          .read(updateServiceProvider)
          .autoCheck(ref.read(databaseProvider));
      if (found == null || !mounted) return;
      final auto = ref.read(autoUpdateProvider) &&
          (Platform.isMacOS || Platform.isWindows);
      ref.read(pendingUpdateProvider.notifier).set(found);
      if (auto) _pendingAutoInstall = found.update;
      unawaited(NotificationService.notifyUpdate(found.update.version,
          willAuto: auto));
    });
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  void _rescheduleQuotes() {
    unawaited(NotificationService.scheduleQuotes(
      enabled: ref.read(quoteNotificationsProvider),
      cats: ref.read(quoteCategoriesProvider),
    ));
  }

  void _maybeAutoInstall() {
    final update = _pendingAutoInstall;
    if (update == null || _installing) return;
    _installing = true;
    _pendingAutoInstall = null;
    // Desktop-only path: downloads in the background, then the installer
    // swaps the app and relaunches it. Failure falls back to the release
    // page next time the user taps the banner.
    unawaited(ref
        .read(updateServiceProvider)
        .downloadAndInstall(update, silent: true)
        .catchError((_) {})
        .whenComplete(() => _installing = false));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantum Habits',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const RootShell(),
    );
  }
}
