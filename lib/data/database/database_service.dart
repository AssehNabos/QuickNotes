import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import 'database_factory.dart';

/// Owns the SQLite connection for QuickNotes.
///
/// Responsibilities:
/// * opening `quicknotes.db` (creating it on first launch),
/// * creating the schema in [_onCreate],
/// * applying incremental migrations in [_onUpgrade].
///
/// The database is opened lazily and cached, so repeated calls are cheap.
class DatabaseService {
  DatabaseService({String? overrideDatabasePath})
      : _overrideDatabasePath = overrideDatabasePath;

  /// Optional explicit path, used by tests (for example with an in-memory
  /// database or a temporary directory).
  final String? _overrideDatabasePath;

  Database? _database;
  Future<Database>? _opening;

  /// Returns the open database, opening it on first use.
  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    // Guard against concurrent first calls opening two connections.
    _opening ??= _open();
    try {
      _database = await _opening!;
      return _database!;
    } finally {
      _opening = null;
    }
  }

  Future<Database> _open() async {
    try {
      configureDatabaseFactory();
      final path = _overrideDatabasePath ??
          p.join(await getDatabasesPath(), AppConstants.databaseName);

      return await openDatabase(
        path,
        version: AppConstants.databaseVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onDowngrade: _onDowngrade,
      );
    } catch (e, st) {
      debugPrint('QuickNotes: failed to open database: $e');
      throw DatabaseException(
        'Could not open the notes database.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Creates the schema for a brand-new installation (version 1).
  Future<void> _onCreate(Database db, int version) async {
    await _createNotesTable(db);
  }

  /// Applies migrations step by step so any older version reaches the latest.
  ///
  /// Add a new `if (oldVersion < N)` block for every future schema change.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Example for future versions:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE notes ADD COLUMN ...');
    // }
    if (oldVersion < 1) {
      await _createNotesTable(db);
    } else if (oldVersion < 2) {
      // v2: reminders. Existing rows get NULL, meaning "no reminder".
      await db.execute(
        'ALTER TABLE ${AppConstants.notesTable} '
        'ADD COLUMN ${AppConstants.colReminderAt} TEXT',
      );
    }
  }

  /// Downgrades are not supported. Dropping data silently would be unsafe, so
  /// the open fails loudly instead.
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    throw DatabaseException(
      'Database version $oldVersion is newer than supported version $newVersion.',
    );
  }

  Future<void> _createNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${AppConstants.notesTable} (
        ${AppConstants.colId} TEXT PRIMARY KEY NOT NULL,
        ${AppConstants.colTitle} TEXT NOT NULL DEFAULT '',
        ${AppConstants.colContent} TEXT NOT NULL DEFAULT '',
        ${AppConstants.colCategory} TEXT NOT NULL DEFAULT '${AppConstants.fallbackCategory}',
        ${AppConstants.colColor} INTEGER NOT NULL DEFAULT ${AppConstants.defaultNoteColor},
        ${AppConstants.colIsPinned} INTEGER NOT NULL DEFAULT 0,
        ${AppConstants.colIsFavorite} INTEGER NOT NULL DEFAULT 0,
        ${AppConstants.colCreatedAt} TEXT NOT NULL,
        ${AppConstants.colUpdatedAt} TEXT NOT NULL,
        ${AppConstants.colReminderAt} TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_notes_updated_at
      ON ${AppConstants.notesTable} (${AppConstants.colUpdatedAt})
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_notes_category
      ON ${AppConstants.notesTable} (${AppConstants.colCategory})
    ''');
  }

  /// Closes the connection. Call when the app is shutting down or in tests.
  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}
