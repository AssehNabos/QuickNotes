import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quicknotes/core/theme/app_theme.dart';
import 'package:quicknotes/data/models/note.dart';
import 'package:quicknotes/providers/notes_provider.dart';
import 'package:quicknotes/ui/utils/feedback.dart';
import 'package:quicknotes/ui/utils/formatters.dart';
import 'package:quicknotes/ui/utils/note_actions.dart';

class NoteViewScreen extends ConsumerWidget {
  const NoteViewScreen({super.key, required this.note});

  /// The note as it was when opened. The screen then follows the live copy
  /// from [allNotesProvider], so edits and pin or favourite changes appear
  /// immediately.
  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = _findById(ref.watch(allNotesProvider), note.id) ?? note;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final background = AppTheme.noteBackground(latest.color, brightness);
    final foreground = AppTheme.noteForeground(brightness);
    final muted = AppTheme.noteMutedForeground(brightness);
    final hasTitle = latest.title.trim().isNotEmpty;
    final hasContent = latest.content.trim().isNotEmpty;
    final notifier = ref.read(notesProvider.notifier);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        foregroundColor: foreground,
        actions: [
          IconButton(
            tooltip: latest.isFavorite
                ? 'Remove from favorites'
                : 'Add to favorites',
            icon: Icon(
              latest.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
            ),
            onPressed: () => runWithFeedback(
              context,
              () => notifier.toggleFavorite(latest),
            ),
          ),
          IconButton(
            tooltip: latest.isPinned ? 'Unpin' : 'Pin',
            icon: Icon(
              latest.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
            ),
            onPressed: () => runWithFeedback(
              context,
              () => notifier.togglePinned(latest),
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openNoteEditor(context, note: latest),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final deleted =
                  await deleteNoteWithConfirmation(context, ref, latest);
              if (deleted && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: foreground.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                latest.category,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SelectableText(
            hasTitle ? latest.title : 'Untitled',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Created ${formatFullDate(latest.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          Text(
            'Modified ${formatFullDate(latest.updatedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          if (latest.reminderAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Reminder ${formatFullDate(latest.reminderAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
          Divider(height: 40, color: muted.withValues(alpha: 0.4)),
          SelectableText(
            hasContent ? latest.content : 'No content',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: hasContent ? foreground : muted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Note? _findById(List<Note> notes, String id) {
    for (final candidate in notes) {
      if (candidate.id == id) return candidate;
    }
    return null;
  }
}
