import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quicknotes/core/constants/app_constants.dart';
import 'package:quicknotes/providers/notes_provider.dart';
import 'package:quicknotes/ui/widgets/empty_state.dart';
import 'package:quicknotes/ui/widgets/note_grid.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    if (notesAsync.isLoading && !notesAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final selected = ref.watch(selectedCategoryProvider);
    final counts = ref.watch(categoryCountsProvider);
    final all = ref.watch(allNotesProvider);
    final notes = selected == null
        ? all
        : all.where((note) => note.category == selected).toList(growable: false);
    final notifier = ref.read(selectedCategoryProvider.notifier);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Text(
            'Categories',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Filter your notes by category.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('All (${all.length})'),
                selected: selected == null,
                onSelected: (_) => notifier.select(null),
              ),
              for (final category in AppConstants.defaultCategories)
                ChoiceChip(
                  label: Text('$category (${counts[category] ?? 0})'),
                  selected: selected == category,
                  onSelected: (_) => notifier.select(category),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (notes.isEmpty)
            EmptyState(
              icon: Icons.folder_open_rounded,
              title: selected == null
                  ? 'No notes yet'
                  : 'No notes in $selected',
              message: 'Notes you assign to this category will appear here.',
            )
          else
            NoteGrid(notes: notes),
        ],
      ),
    );
  }
}
