import 'package:sqflite/sqflite.dart' hide DatabaseException;
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../database/database_service.dart';
import '../models/note.dart';

/// Single point of access for note persistence.
///
/// All SQL uses parameterised arguments (`whereArgs`), never string
/// interpolation of user input. Every failure is rethrown as a
/// [DatabaseException] so the UI deals with one error type.
class NoteRepository {
  NoteRepository({
    required DatabaseService databaseService,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _dbService = databaseService,
        _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final DatabaseService _dbService;
  final Uuid _uuid;
  final DateTime Function() _clock;

  static const String _table = AppConstants.notesTable;

  /// Default ordering: pinned notes first, then most recently updated.
  static const String _defaultOrder =
      '${AppConstants.colIsPinned} DESC, ${AppConstants.colUpdatedAt} DESC';

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Validates and inserts a new note, returning the stored [Note].
  Future<Note> createNote({
    required String title,
    required String content,
    required String category,
    required int color,
    DateTime? reminderAt,
  }) async {
    Note.validate(title: title, content: content);
    final now = _clock();
    _checkReminder(reminderAt, now);
    final note = Note(
      id: _uuid.v4(),
      title: title.trim(),
      content: content.trim(),
      category: category,
      color: color,
      createdAt: now,
      updatedAt: now,
      reminderAt: reminderAt,
    );

    try {
      final db = await _dbService.database;
      await db.insert(
        _table,
        note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return note;
    } catch (e, st) {
      throw DatabaseException(
        'Could not save the note.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns every note in default order.
  Future<List<Note>> getAllNotes() async {
    try {
      final db = await _dbService.database;
      final rows = await db.query(_table, orderBy: _defaultOrder);
      return rows.map(Note.fromMap).toList(growable: false);
    } catch (e, st) {
      throw DatabaseException(
        'Could not load your notes.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Returns a single note by id, or `null` if it does not exist.
  Future<Note?> getNoteById(String id) async {
    try {
      final db = await _dbService.database;
      final rows = await db.query(
        _table,
        where: '${AppConstants.colId} = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Note.fromMap(rows.first);
    } catch (e, st) {
      throw DatabaseException(
        'Could not open the note.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Returns notes in [category], in default order.
  Future<List<Note>> getNotesByCategory(String category) async {
    try {
      final db = await _dbService.database;
      final rows = await db.query(
        _table,
        where: '${AppConstants.colCategory} = ?',
        whereArgs: [category],
        orderBy: _defaultOrder,
      );
      return rows.map(Note.fromMap).toList(growable: false);
    } catch (e, st) {
      throw DatabaseException(
        'Could not load notes for "$category".',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Returns only favourited notes.
  Future<List<Note>> getFavoriteNotes() async {
    try {
      final db = await _dbService.database;
      final rows = await db.query(
        _table,
        where: '${AppConstants.colIsFavorite} = ?',
        whereArgs: [1],
        orderBy: _defaultOrder,
      );
      return rows.map(Note.fromMap).toList(growable: false);
    } catch (e, st) {
      throw DatabaseException(
        'Could not load favourite notes.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Returns only pinned notes, most recently updated first.
  Future<List<Note>> getPinnedNotes() async {
    try {
      final db = await _dbService.database;
      final rows = await db.query(
        _table,
        where: '${AppConstants.colIsPinned} = ?',
        whereArgs: [1],
        orderBy: '${AppConstants.colUpdatedAt} DESC',
      );
      return rows.map(Note.fromMap).toList(growable: false);
    } catch (e, st) {
      throw DatabaseException(
        'Could not load pinned notes.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Searches title, content and category. Case-insensitive for ASCII.
  ///
  /// An empty or whitespace-only [query] returns all notes.
  Future<List<Note>> searchNotes(String query) async {
    final term = query.trim();
    if (term.isEmpty) return getAllNotes();

    final pattern = '%${_escapeLike(term)}%';
    try {
      final db = await _dbService.database;
      final rows = await db.query(
        _table,
        where: '${AppConstants.colTitle} LIKE ? ESCAPE \'\\\' '
            'OR ${AppConstants.colContent} LIKE ? ESCAPE \'\\\' '
            'OR ${AppConstants.colCategory} LIKE ? ESCAPE \'\\\'',
        whereArgs: [pattern, pattern, pattern],
        orderBy: _defaultOrder,
      );
      return rows.map(Note.fromMap).toList(growable: false);
    } catch (e, st) {
      throw DatabaseException(
        'Search failed. Please try again.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Returns the total number of notes.
  Future<int> getTotalCount() async {
    try {
      final db = await _dbService.database;
      final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, st) {
      throw DatabaseException(
        'Could not count notes.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Returns a map of category name to note count, for categories that have
  /// at least one note.
  Future<Map<String, int>> getCategoryCounts() async {
    try {
      final db = await _dbService.database;
      final rows = await db.rawQuery(
        'SELECT ${AppConstants.colCategory} AS category, COUNT(*) AS count '
        'FROM $_table GROUP BY ${AppConstants.colCategory}',
      );
      return {
        for (final row in rows)
          row['category'] as String: (row['count'] as int?) ?? 0,
      };
    } catch (e, st) {
      throw DatabaseException(
        'Could not load category counts.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  /// Saves edits to an existing note and refreshes its `updated_at` timestamp.
  Future<Note> updateNote(
    Note note, {
    String? title,
    String? content,
    String? category,
    int? color,
    DateTime? reminderAt,
    bool clearReminder = false,
  }) async {
    final now = _clock();
    _checkReminder(reminderAt, now);
    final updated = note.copyWith(
      title: title?.trim() ?? note.title,
      content: content?.trim() ?? note.content,
      category: category ?? note.category,
      color: color ?? note.color,
      reminderAt: reminderAt,
      clearReminder: clearReminder,
      updatedAt: now,
    );
    Note.validate(title: updated.title, content: updated.content);

    try {
      final db = await _dbService.database;
      final count = await db.update(
        _table,
        updated.toMap(),
        where: '${AppConstants.colId} = ?',
        whereArgs: [updated.id],
      );
      if (count == 0) {
        throw const NotFoundException('This note no longer exists.');
      }
      return updated;
    } on AppException {
      rethrow;
    } catch (e, st) {
      throw DatabaseException(
        'Could not update the note.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Sets the pinned state without changing `updated_at`.
  Future<void> setPinned(String id, {required bool isPinned}) =>
      _updateFlag(id, AppConstants.colIsPinned, isPinned);

  /// Sets the favourite state without changing `updated_at`.
  Future<void> setFavorite(String id, {required bool isFavorite}) =>
      _updateFlag(id, AppConstants.colIsFavorite, isFavorite);

  Future<void> _updateFlag(String id, String column, bool value) async {
    try {
      final db = await _dbService.database;
      final count = await db.update(
        _table,
        {column: value ? 1 : 0},
        where: '${AppConstants.colId} = ?',
        whereArgs: [id],
      );
      if (count == 0) {
        throw const NotFoundException('This note no longer exists.');
      }
    } on AppException {
      rethrow;
    } catch (e, st) {
      throw DatabaseException(
        'Could not update the note.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Permanently removes every note. Returns the number of notes deleted.
  Future<int> deleteAllNotes() async {
    try {
      final db = await _dbService.database;
      return await db.delete(_table);
    } catch (e, st) {
      throw DatabaseException(
        'Could not delete all notes.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Permanently removes a note. Returns `true` if a row was deleted.
  Future<bool> deleteNote(String id) async {
    try {
      final db = await _dbService.database;
      final count = await db.delete(
        _table,
        where: '${AppConstants.colId} = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e, st) {
      throw DatabaseException(
        'Could not delete the note.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Escapes SQL LIKE wildcards so that user input such as `100%` is matched
  /// literally. Used together with `ESCAPE '\'` in [searchNotes].
  /// A reminder must point at a moment that has not happened yet.
  static void _checkReminder(DateTime? reminderAt, DateTime now) {
    if (reminderAt != null && !reminderAt.isAfter(now)) {
      throw const ValidationException(
        'Reminder must be set to a time in the future.',
      );
    }
  }

  static String _escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
