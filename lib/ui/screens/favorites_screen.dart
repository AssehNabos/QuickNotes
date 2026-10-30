import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quicknotes/providers/notes_provider.dart';
import 'package:quicknotes/ui/widgets/empty_state.dart';
import 'package:quicknotes/ui/widgets/note_grid.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    if (notesAsync.isLoading && !notesAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final favorites = ref.watch(favoriteNotesProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Text(
            'Favorites',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${favorites.length} ${favorites.length == 1 ? 'starred note' : 'starred notes'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (favorites.isEmpty)
            const EmptyState(
              icon: Icons.star_outline_rounded,
              title: 'No favorites yet',
              message:
                  'Star a note from its menu or from the note view to find it here.',
            )
          else
            NoteGrid(notes: favorites),
        ],
      ),
    );
  }
}
