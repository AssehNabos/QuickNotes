import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quicknotes/providers/notes_provider.dart';
import 'package:quicknotes/providers/theme_provider.dart';
import 'package:quicknotes/ui/utils/feedback.dart';
import 'package:quicknotes/ui/widgets/app_logo.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const String _appVersion = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mode = ref.watch(themeModeProvider);
    final total = ref.watch(totalNotesCountProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Text(
            'Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),

          _SettingsSection(
            title: 'Appearance',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_rounded),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (selection) => runWithFeedback(
                      context,
                      () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(selection.first),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _SettingsSection(
            title: 'Data',
            children: [
              ListTile(
                leading: const Icon(Icons.notes_rounded),
                title: const Text('Total notes'),
                trailing: Text(
                  '$total',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: scheme.error),
                title: Text(
                  'Delete all notes',
                  style: TextStyle(color: scheme.error),
                ),
                enabled: total > 0,
                onTap: () => _confirmDeleteAll(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const _SettingsSection(
            title: 'About',
            children: [
              ListTile(
                leading: AppLogo(size: 32),
                title: Text('QuickNotes'),
                subtitle: Text('A simple, private place for your notes.'),
              ),
              ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Version'),
                trailing: Text(_appVersion),
              ),
              ListTile(
                leading: Icon(Icons.storage_rounded),
                title: Text('Storage'),
                subtitle: Text('Notes are saved on this device only.'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete all notes?'),
          content: const Text(
            'Every note will be permanently deleted. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete all'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    await runWithFeedback(context, () async {
      final count = await ref.read(notesProvider.notifier).deleteAllNotes();
      if (context.mounted) {
        showMessage(context, '$count ${count == 1 ? 'note' : 'notes'} deleted');
      }
    });
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}
