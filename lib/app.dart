import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quicknotes/core/constants/app_constants.dart';
import 'package:quicknotes/core/theme/app_theme.dart';
import 'package:quicknotes/providers/theme_provider.dart';
import 'package:quicknotes/ui/screens/home_shell.dart';

class QuickNotesApp extends ConsumerWidget {
  const QuickNotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      home: const HomeShell(),
    );
  }
}
