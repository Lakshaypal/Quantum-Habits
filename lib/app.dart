import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/presentation/root_shell.dart';

class QuantumHabitsApp extends StatelessWidget {
  const QuantumHabitsApp({super.key});

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
