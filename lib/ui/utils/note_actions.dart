import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quicknotes/data/models/note.dart';
import 'package:quicknotes/providers/notes_provider.dart';
import 'package:quicknotes/ui/screens/note_editor_screen.dart';
import 'package:quicknotes/ui/screens/note_view_screen.dart';
import 'package:quicknotes/ui/utils/feedback.dart';

/// Opens the editor. Pass [note] to edit it, or omit it to create a new note.
void openNoteEditor(BuildContext context, {Note? note}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NoteEditorScreen(note: note),
    ),
  );
}

/// Opens the read-only view of a note.
void openNoteView(BuildContext context, Note note) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NoteViewScreen(note: note),
    ),
  );
}

/// Asks for confirmation, then permanently deletes [note].
///
/// Returns `true` only if the note was deleted, so callers can close the
/// screen that was showing it.
Future<bool> deleteNoteWithConfirmation(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete note?'),
        content: Text(
          '"${note.title.trim().isEmpty ? 'Untitled' : note.title.trim()}" '
          'will be permanently deleted. This cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed != true) return false;

  try {
    await ref.read(notesProvider.notifier).deleteNote(note.id);
    if (context.mounted) showMessage(context, 'Note deleted');
    return true;
  } catch (e) {
    if (context.mounted) showMessage(context, errorMessage(e), isError: true);
    return false;
  }
}
