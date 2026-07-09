import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'core/db/mac_data_migration.dart';
import 'features/habits/application/habit_providers.dart';
import 'features/research/application/research_providers.dart'
    show dedupeResearchTemplates;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Move the DB out of the old macOS sandbox container before opening it
  // (v2.2.0 dropped the sandbox so updates can self-install). No-op elsewhere.
  await migrateMacSandboxDataIfNeeded();
  // Open the DB once and reuse it so config reads happen before first frame
  // and the whole app shares the instance.
  final db = AppDatabase();
  // Self-heal installs where template metrics were seeded on several devices
  // with random ids and multiplied through sync (fire-and-forget; no-op when
  // there's nothing to repair).
  unawaited(dedupeResearchTemplates(db).catchError((_) {}));
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const QuantumHabitsApp(),
    ),
  );
}
