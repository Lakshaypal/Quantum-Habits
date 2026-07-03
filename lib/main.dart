import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'features/habits/application/habit_providers.dart';
import 'features/sync/application/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Open the DB once and reuse it, so Supabase config (stored in the DB) can be
  // read before the first frame and the rest of the app shares the instance.
  final db = AppDatabase();
  await initSupabaseFromConfig(db);
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const QuantumHabitsApp(),
    ),
  );
}
