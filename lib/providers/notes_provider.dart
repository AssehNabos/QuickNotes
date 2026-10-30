import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';
import 'core_providers.dart';

/// Number of notes shown in the "Recent" section of the dashboard.
const int recentNotesLimit = 5;

/// Orders notes for the dashboard: pinned first, then newest update first.
/// Returns a new list and leaves [notes] unchanged.
List<Note> sortNotes(Iterable<Note> notes) {
  final list = notes.toList();
  list.sort((a, b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return list;
}

/// Source of truth for all notes.
///
/// Every mutation writes to SQLite first. The in-memory state changes only
/// after that succeeds, so a failed write leaves the list unchanged and the
/// error reaches the UI. Reminders are synced after the write and never
/// block it.
class NotesNotifier extends AsyncNotifier<List<Note>> {
  NoteRepository get _repository => ref.read(noteRepositoryProvider);

  @override
  Future<List<Note>> build() async {
    return sortNotes(await _repository.getAllNotes());
  }

  /// Reloads every note from the database.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () async => sortNotes(await _repository.getAllNotes()),
    );
  }

  Future<Note> createNote({
    required String title,
    required String content,
    String? category,
    int? color,
    DateTime? reminderAt,
  }) async {
    final note = await _repository.createNote(
      title: title,
      content: content,
      category: category ?? AppConstants.fallbackCategory,
      color: color ?? AppConstants.defaultNoteColor,
      reminderAt: reminderAt,
    );
    await ref.read(notificationServiceProvider).syncReminder(note);
    await _applyChange(note);
    return note;
  }

  /// Saves edits. Pass [reminderAt] to set a reminder, or [clearReminder] to
  /// remove one. Omit both to leave the reminder unchanged.
  Future<Note> editNote(
    Note original, {
    String? title,
    String? content,
    String? category,
    int? color,
    DateTime? reminderAt,
    bool clearReminder = false,
  }) async {
    final updated = await _repository.updateNote(
      original,
      title: title,
      content: content,
      category: category,
      color: color,
      reminderAt: reminderAt,
      clearReminder: clearReminder,
    );
    await ref.read(notificationServiceProvider).syncReminder(updated);
    await _applyChange(updated);
    return updated;
  }

  Future<void> deleteNote(String id) async {
    final deleted = await _repository.deleteNote(id);
    if (!deleted) {
      throw const NotFoundException('This note was already deleted.');
    }
    await ref.read(notificationServiceProvider).cancelReminder(id);

    final current = state.valueOrNull;
    if (current == null) {
      await refresh();
      return;
    }
    state = AsyncData(
      current.where((note) => note.id != id).toList(growable: false),
    );
  }

  /// Deletes every note and every scheduled reminder. Returns the count.
  Future<int> deleteAllNotes() async {
    final count = await _repository.deleteAllNotes();
    await ref.read(notificationServiceProvider).cancelAll();
    state = const AsyncData(<Note>[]);
    return count;
  }

  Future<void> togglePinned(Note note) async {
    final value = !note.isPinned;
    await _repository.setPinned(note.id, isPinned: value);
    await _applyChange(note.copyWith(isPinned: value));
  }

  Future<void> toggleFavorite(Note note) async {
    final value = !note.isFavorite;
    await _repository.setFavorite(note.id, isFavorite: value);
    await _applyChange(note.copyWith(isFavorite: value));
  }

  /// Puts [note] into the in-memory list, replacing any note with the same id.
  /// The repository has already stored the note, so it is authoritative.
  Future<void> _applyChange(Note note) async {
    final current = state.valueOrNull;
    if (current == null) {
      // Nothing loaded yet, so a full reload is the simplest correct option.
      await refresh();
      return;
    }
    final others = current.where((n) => n.id != note.id);
    state = AsyncData(sortNotes([...others, note]));
  }
}

final notesProvider = AsyncNotifierProvider<NotesNotifier, List<Note>>(
  NotesNotifier.new,
);

/// Search text typed on the dashboard. Empty means "no search".
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;

  void clear() => state = '';
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// Category chosen on the Categories screen. `null` means "All".
class SelectedCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? category) => state = category;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, String?>(
  SelectedCategoryNotifier.new,
);

/// Notes that are loaded, or an empty list while loading or on error.
/// Screens that need loading or error states should watch [notesProvider].
final allNotesProvider = Provider<List<Note>>((ref) {
  return ref.watch(notesProvider).valueOrNull ?? const <Note>[];
});

/// Notes matching the current search text and category filter.
/// Matching is case-insensitive against title, content and category.
final filteredNotesProvider = Provider<List<Note>>((ref) {
  final notes = ref.watch(allNotesProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final category = ref.watch(selectedCategoryProvider);

  return notes.where((note) {
    if (category != null && note.category != category) return false;
    if (query.isEmpty) return true;
    return note.title.toLowerCase().contains(query) ||
        note.content.toLowerCase().contains(query) ||
        note.category.toLowerCase().contains(query);
  }).toList(growable: false);
});

final pinnedNotesProvider = Provider<List<Note>>((ref) {
  return ref
      .watch(allNotesProvider)
      .where((note) => note.isPinned)
      .toList(growable: false);
});

final favoriteNotesProvider = Provider<List<Note>>((ref) {
  return ref
      .watch(allNotesProvider)
      .where((note) => note.isFavorite)
      .toList(growable: false);
});

/// Most recently updated notes, regardless of pin status.
final recentNotesProvider = Provider<List<Note>>((ref) {
  final sorted = ref.watch(allNotesProvider).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return sorted.take(recentNotesLimit).toList(growable: false);
});

final totalNotesCountProvider = Provider<int>((ref) {
  return ref.watch(allNotesProvider).length;
});

/// Number of notes per category, including default categories with zero.
final categoryCountsProvider = Provider<Map<String, int>>((ref) {
  final counts = <String, int>{
    for (final category in AppConstants.defaultCategories) category: 0,
  };
  for (final note in ref.watch(allNotesProvider)) {
    counts.update(note.category, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
});
