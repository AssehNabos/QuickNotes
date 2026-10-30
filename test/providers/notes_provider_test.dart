import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknotes/core/constants/app_constants.dart';
import 'package:quicknotes/data/database/database_service.dart';
import 'package:quicknotes/providers/core_providers.dart';
import 'package:quicknotes/providers/notes_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../helpers/test_helpers.dart';

void main() {
  initDatabaseFactoryForTests();

  late DatabaseService dbService;
  late FakeNotificationService notifications;
  late ProviderContainer container;

  setUp(() {
    dbService = DatabaseService(overrideDatabasePath: inMemoryDatabasePath);
    notifications = FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        databaseServiceProvider.overrideWithValue(dbService),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await dbService.close();
  });

  NotesNotifier notifier() => container.read(notesProvider.notifier);

  Future<void> loadNotes() => container.read(notesProvider.future);

  test('create and edit update the visible list', () async {
    await loadNotes();

    final note = await notifier().createNote(
      title: 'Plan',
      content: 'Ship it',
      category: 'Work',
      color: AppConstants.defaultNoteColor,
    );
    expect(container.read(allNotesProvider).map((n) => n.title), ['Plan']);

    await notifier().editNote(note, title: 'Plan v2');
    expect(container.read(allNotesProvider).single.title, 'Plan v2');
  });

  test('deleting removes the note from the list and cancels its reminder',
      () async {
    await loadNotes();
    final note = await notifier().createNote(
      title: 'Gone soon',
      content: '',
      category: 'Others',
      color: AppConstants.defaultNoteColor,
      reminderAt: DateTime.now().add(const Duration(hours: 1)),
    );

    expect(notifications.synced, [note.id]);

    await notifier().deleteNote(note.id);

    expect(container.read(allNotesProvider), isEmpty);
    expect(notifications.cancelled, contains(note.id));
  });

  test('pin and favourite toggles update the derived lists', () async {
    await loadNotes();
    final note = await notifier().createNote(
      title: 'Star me',
      content: '',
      category: 'Ideas',
      color: AppConstants.defaultNoteColor,
    );

    await notifier().togglePinned(note);
    expect(container.read(pinnedNotesProvider).map((n) => n.id), [note.id]);

    final pinned = container.read(allNotesProvider).single;
    await notifier().toggleFavorite(pinned);
    expect(container.read(favoriteNotesProvider), hasLength(1));

    final favourite = container.read(allNotesProvider).single;
    await notifier().togglePinned(favourite);
    expect(container.read(pinnedNotesProvider), isEmpty);
    expect(container.read(favoriteNotesProvider), hasLength(1));
  });

  test('clearing a reminder cancels it through an edit', () async {
    await loadNotes();
    final note = await notifier().createNote(
      title: 'Remind me',
      content: '',
      category: 'Personal',
      color: AppConstants.defaultNoteColor,
      reminderAt: DateTime.now().add(const Duration(hours: 2)),
    );

    final cleared = await notifier().editNote(note, clearReminder: true);

    expect(cleared.reminderAt, isNull);
    expect(notifications.synced.last, note.id);
  });

  test('search and category filters combine', () async {
    await loadNotes();
    await notifier().createNote(
      title: 'Budget review',
      content: '',
      category: 'Work',
      color: AppConstants.defaultNoteColor,
    );
    await notifier().createNote(
      title: 'Budget trip',
      content: '',
      category: 'Personal',
      color: AppConstants.defaultNoteColor,
    );

    container.read(searchQueryProvider.notifier).update('budget');
    expect(container.read(filteredNotesProvider), hasLength(2));

    container.read(selectedCategoryProvider.notifier).select('Work');
    final filtered = container.read(filteredNotesProvider);
    expect(filtered.map((n) => n.title), ['Budget review']);
  });

  test('category counts include default categories with zero notes',
      () async {
    await loadNotes();
    await notifier().createNote(
      title: 'Only one',
      content: '',
      category: 'School',
      color: AppConstants.defaultNoteColor,
    );

    final counts = container.read(categoryCountsProvider);
    expect(counts['School'], 1);
    expect(counts['Work'], 0);
    expect(counts.keys, containsAll(AppConstants.defaultCategories));
  });

  test('deleteAllNotes clears the list and cancels every reminder', () async {
    await loadNotes();
    await notifier().createNote(
      title: 'A',
      content: '',
      category: 'Others',
      color: AppConstants.defaultNoteColor,
    );

    final count = await notifier().deleteAllNotes();

    expect(count, 1);
    expect(container.read(allNotesProvider), isEmpty);
    expect(notifications.cancelAllCount, 1);
  });
}
