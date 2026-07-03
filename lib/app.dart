import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/journal/application/journal_providers.dart';
import 'features/shell/presentation/root_shell.dart';
import 'features/sync/application/sync_engine.dart';

class QuantumHabitsApp extends ConsumerStatefulWidget {
  const QuantumHabitsApp({super.key});

  @override
  ConsumerState<QuantumHabitsApp> createState() => _QuantumHabitsAppState();
}

class _QuantumHabitsAppState extends ConsumerState<QuantumHabitsApp> {
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
