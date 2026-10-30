import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quicknotes/core/constants/app_constants.dart';
import 'package:quicknotes/core/errors/app_exception.dart';
import 'package:quicknotes/data/database/database_service.dart';
import 'package:quicknotes/data/repositories/note_repository.dart';

import '../helpers/test_helpers.dart';

void main() {
  initDatabaseFactoryForTests();

  late Directory tempDir;
  late String dbPath;
  late DatabaseService dbService;
  late NoteRepository repo;
  late DateTime now;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quicknotes_test_');
    dbPath = p.join(tempDir.path, AppConstants.databaseName);
    dbService = DatabaseService(overrideDatabasePath: dbPath);
    now = DateTime(2026, 10, 1, 9);
    repo = NoteRepository(databaseService: dbService, clock: () => now);
  });

  tearDown(() async {
    await dbService.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> createSample({
    String title = '',
    String content = '',
    String category = 'Personal',
  }) {
    return repo.createNote(
      title: title,
      content: content,
      category: category,
      color: AppConstants.defaultNoteColor,
    );
  }

  group('CRUD', () {
    test('creates a note and reads it back', () async {
      final created = await repo.createNote(
        title: 'Groceries',
        content: 'Milk, eggs',
        category: 'Personal',
        color: AppConstants.noteColorPalette[1],
      );

      final fetched = await repo.getNoteById(created.id);

      expect(fetched, isNotNull);
      expect(fetched!.title, 'Groceries');
      expect(fetched.content, 'Milk, eggs');
      expect(fetched.color, AppConstants.noteColorPalette[1]);
    });

    test('rejects an empty note and stores nothing', () async {
      await expectLater(
        repo.createNote(
          title: '',
          content: '',
          category: 'Personal',
          color: AppConstants.defaultNoteColor,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(await repo.getAllNotes(), isEmpty);
    });

    test('creates several notes', () async {
      await createSample(title: 'One');
      await createSample(title: 'Two');
      await createSample(title: 'Three');

      expect(await repo.getTotalCount(), 3);
    });

    test('editing updates the content and refreshes updated_at', () async {
      final created = await repo.createNote(
        title: 'Draft',
        content: 'First version',
        category: 'Work',
        color: AppConstants.defaultNoteColor,
      );

      now = DateTime(2026, 10, 2, 12);
      final updated = await repo.updateNote(
        created,
        title: 'Final',
        content: 'Second version',
      );

      final fetched = await repo.getNoteById(created.id);
      expect(updated.title, 'Final');
      expect(fetched!.title, 'Final');
      expect(fetched.content, 'Second version');
      expect(fetched.updatedAt, DateTime(2026, 10, 2, 12));
      expect(fetched.createdAt, DateTime(2026, 10, 1, 9));
    });

    test('deleted notes disappear', () async {
      final created = await repo.createNote(
        title: 'Temporary',
        content: '',
        category: 'Others',
        color: AppConstants.defaultNoteColor,
      );

      expect(await repo.deleteNote(created.id), isTrue);
      expect(await repo.getNoteById(created.id), isNull);
      expect(await repo.getAllNotes(), isEmpty);
    });

    test('deleting a missing note returns false', () async {
      expect(await repo.deleteNote('does-not-exist'), isFalse);
    });

    test('deleteAllNotes removes everything', () async {
      await createSample(title: 'A');
      await createSample(title: 'B');

      expect(await repo.deleteAllNotes(), 2);
      expect(await repo.getAllNotes(), isEmpty);
    });
  });

  group('Search', () {
    setUp(() async {
      await repo.createNote(
        title: 'Groceries',
        content: 'Milk and eggs',
        category: 'Personal',
        color: AppConstants.defaultNoteColor,
      );
      await repo.createNote(
        title: 'Sprint review',
        content: 'Demo the login flow',
        category: 'Work',
        color: AppConstants.defaultNoteColor,
      );
    });

    test('matches the title, ignoring case', () async {
      final results = await repo.searchNotes('GROCER');
      expect(results.map((n) => n.title), ['Groceries']);
    });

    test('matches the content', () async {
      final results = await repo.searchNotes('login');
      expect(results.map((n) => n.title), ['Sprint review']);
    });

    test('matches the category', () async {
      final results = await repo.searchNotes('work');
      expect(results.map((n) => n.title), ['Sprint review']);
    });

    test('an empty query returns every note', () async {
      expect(await repo.searchNotes('   '), hasLength(2));
    });

    test('a query with no matches returns an empty list', () async {
      expect(await repo.searchNotes('zzz-no-match'), isEmpty);
    });

    test('treats % and _ as ordinary characters', () async {
      await createSample(title: 'Progress 100% done');
      await createSample(title: 'Progress 100 done');

      final results = await repo.searchNotes('100%');
      expect(results.map((n) => n.title), ['Progress 100% done']);
    });
  });

  group('Persistence across restarts', () {
    test('notes, pin, favourite and reminder survive reopening the database',
        () async {
      final reminder = DateTime(2026, 11, 2, 9, 30);
      final created = await repo.createNote(
        title: 'Important',
        content: 'Renew passport',
        category: 'Important',
        color: AppConstants.defaultNoteColor,
        reminderAt: reminder,
      );
      await repo.setPinned(created.id, isPinned: true);
      await repo.setFavorite(created.id, isFavorite: true);

      // Simulate closing and restarting the app.
      await dbService.close();
      dbService = DatabaseService(overrideDatabasePath: dbPath);
      repo = NoteRepository(databaseService: dbService, clock: () => now);

      final restored = await repo.getNoteById(created.id);
      expect(restored, isNotNull);
      expect(restored!.title, 'Important');
      expect(restored.isPinned, isTrue);
      expect(restored.isFavorite, isTrue);
      expect(restored.reminderAt, reminder);
    });

    test('a missing note reports NotFound when pinning', () async {
      await expectLater(
        repo.setPinned('missing', isPinned: true),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('rejects a reminder in the past', () async {
      await expectLater(
        repo.createNote(
          title: 'Late',
          content: '',
          category: 'Others',
          color: AppConstants.defaultNoteColor,
          reminderAt: now.subtract(const Duration(minutes: 1)),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
