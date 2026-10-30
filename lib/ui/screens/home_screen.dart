import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quicknotes/providers/notes_provider.dart';
import 'package:quicknotes/ui/utils/feedback.dart';
import 'package:quicknotes/ui/widgets/app_logo.dart';
import 'package:quicknotes/ui/widgets/empty_state.dart';
import 'package:quicknotes/ui/widgets/note_grid.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);

    if (notesAsync.isLoading && !notesAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notesAsync.hasError && !notesAsync.hasValue) {
      return SafeArea(
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load your notes',
          message: errorMessage(notesAsync.error!),
          action: FilledButton.icon(
            onPressed: () => ref.read(notesProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
      );
    }

    final query = ref.watch(searchQueryProvider);
    final isSearching = query.trim().isNotEmpty;
    final total = ref.watch(totalNotesCountProvider);
    final pinned = ref.watch(pinnedNotesProvider);
    final recent = ref
        .watch(recentNotesProvider)
        .where((note) => !note.isPinned)
        .toList(growable: false);
    final results = ref.watch(filteredNotesProvider);
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => ref.read(notesProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            Row(
              children: [
                const AppLogo(),
                const SizedBox(width: 12),
                Text(
                  'QuickNotes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome back!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              total == 0
                  ? 'Capture your first idea.'
                  : 'You have $total ${total == 1 ? 'note' : 'notes'}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) =>
                  ref.read(searchQueryProvider.notifier).update(value),
              decoration: InputDecoration(
                hintText: 'Search by title, content or category',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: isSearching
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            if (isSearching && results.isEmpty)
              const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matching notes',
                message:
                    'Try a different word, or search by title, content or category.',
              ),
            if (isSearching && results.isNotEmpty) ...[
              _SectionHeader(
                title: 'Results',
                count: results.length,
              ),
              NoteGrid(notes: results),
            ],

            if (!isSearching && total == 0)
              const EmptyState(
                icon: Icons.note_add_outlined,
                title: 'No notes yet',
                message: 'Tap the + button to write your first note.',
              ),

            if (!isSearching && total > 0) ...[
              if (pinned.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Pinned',
                  icon: Icons.push_pin_rounded,
                  count: pinned.length,
                ),
                NoteGrid(notes: pinned),
                const SizedBox(height: 12),
              ],
              if (recent.isNotEmpty) ...[
                const _SectionHeader(title: 'Recent'),
                NoteGrid(notes: recent),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.icon, this.count});

  final String title;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: muted),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}
