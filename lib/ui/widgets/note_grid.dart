import 'package:flutter/material.dart';

import 'package:quicknotes/data/models/note.dart';
import 'package:quicknotes/ui/utils/note_actions.dart';
import 'package:quicknotes/ui/widgets/note_card.dart';

/// Two-column staggered layout. Cards alternate between columns, so their
/// heights vary naturally, as in the reference design.
///
/// Must be placed inside a scrollable parent (for example a `ListView`).
class NoteGrid extends StatelessWidget {
  const NoteGrid({super.key, required this.notes});

  final List<Note> notes;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final left = <Note>[];
    final right = <Note>[];
    for (var i = 0; i < notes.length; i++) {
      (i.isEven ? left : right).add(notes[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _column(context, left)),
        const SizedBox(width: _gap),
        Expanded(child: _column(context, right)),
      ],
    );
  }

  Widget _column(BuildContext context, List<Note> items) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final note in items)
          Padding(
            padding: const EdgeInsets.only(bottom: _gap),
            child: NoteCard(
              note: note,
              onTap: () => openNoteView(context, note),
            ),
          ),
      ],
    );
  }
}
