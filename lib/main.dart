import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'features/habits/application/habit_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Open the DB once and reuse it so config reads happen before first frame
  // and the whole app shares the instance.
  final db = AppDatabase();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const QuantumHabitsApp(),
    ),
  );
}
