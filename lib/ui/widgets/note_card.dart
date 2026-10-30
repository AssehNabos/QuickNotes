import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quicknotes/core/theme/app_theme.dart';
import 'package:quicknotes/data/models/note.dart';
import 'package:quicknotes/providers/notes_provider.dart';
import 'package:quicknotes/ui/utils/feedback.dart';
import 'package:quicknotes/ui/utils/formatters.dart';
import 'package:quicknotes/ui/utils/note_actions.dart';

class NoteCard extends ConsumerWidget {
  const NoteCard({super.key, required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final background = AppTheme.noteBackground(note.color, brightness);
    final foreground = AppTheme.noteForeground(brightness);
    final muted = AppTheme.noteMutedForeground(brightness);
    final hasTitle = note.title.trim().isNotEmpty;
    final hasContent = note.content.trim().isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: brightness == Brightness.dark ? 0.35 : 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 6, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          hasTitle ? note.title : 'Untitled',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (note.isPinned)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 2),
                        child: Icon(Icons.push_pin_rounded, size: 14, color: muted),
                      ),
                    _CardMenu(note: note, color: muted),
                  ],
                ),
                if (hasContent) ...[
                  const SizedBox(height: 6),
                  Text(
                    note.content,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatCardDate(note.updatedAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (note.reminderAt != null) ...[
                      Icon(Icons.alarm_rounded, size: 14, color: muted),
                      const SizedBox(width: 6),
                    ],
                    if (note.isFavorite)
                      Icon(Icons.star_rounded, size: 14, color: muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _NoteAction { edit, pin, favorite, delete }

class _CardMenu extends ConsumerWidget {
  const _CardMenu({required this.note, required this.color});

  final Note note;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_NoteAction>(
      tooltip: 'Note options',
      icon: Icon(Icons.more_horiz_rounded, color: color),
      onSelected: (action) => _handle(context, ref, action),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _NoteAction.edit,
          child: _MenuRow(icon: Icons.edit_outlined, label: 'Edit'),
        ),
        PopupMenuItem(
          value: _NoteAction.pin,
          child: _MenuRow(
            icon: note.isPinned
                ? Icons.push_pin_outlined
                : Icons.push_pin_rounded,
            label: note.isPinned ? 'Unpin' : 'Pin',
          ),
        ),
        PopupMenuItem(
          value: _NoteAction.favorite,
          child: _MenuRow(
            icon: note.isFavorite
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            label: note.isFavorite ? 'Remove from favorites' : 'Add to favorites',
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _NoteAction.delete,
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: Colors.redAccent,
          ),
        ),
      ],
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _NoteAction action,
  ) async {
    switch (action) {
      case _NoteAction.edit:
        openNoteEditor(context, note: note);
      case _NoteAction.pin:
        await runWithFeedback(
          context,
          () => ref.read(notesProvider.notifier).togglePinned(note),
        );
      case _NoteAction.favorite:
        await runWithFeedback(
          context,
          () => ref.read(notesProvider.notifier).toggleFavorite(note),
        );
      case _NoteAction.delete:
        await deleteNoteWithConfirmation(context, ref, note);
    }
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
