import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quicknotes/core/constants/app_constants.dart';
import 'package:quicknotes/data/database/database_service.dart';
import 'package:sqflite/sqflite.dart';

import '../helpers/test_helpers.dart';

void main() {
  initDatabaseFactoryForTests();

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quicknotes_migration_');
    dbPath = p.join(tempDir.path, AppConstants.databaseName);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('upgrades a version 1 database to version 2 without losing notes',
      () async {
    // Create a database exactly as the v1 app would have left it.
    final legacy = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async => db.execute(schemaV1),
    );
    await legacy.insert('notes', {
      'id': 'legacy-1',
      'title': 'Kept after upgrade',
      'content': 'Still here',
      'category': 'Ideas',
      'color': 0xFFFFFFFF,
      'is_pinned': 1,
      'is_favorite': 0,
      'created_at': DateTime(2026, 9, 1).toIso8601String(),
      'updated_at': DateTime(2026, 9, 2).toIso8601String(),
    });
    await legacy.close();

    // Open with the current app, which should run the v2 migration.
    final service = DatabaseService(overrideDatabasePath: dbPath);
    final upgraded = await service.database;

    expect(await upgraded.getVersion(), 2);

    final columns = await upgraded.rawQuery('PRAGMA table_info(notes)');
    final columnNames = columns.map((c) => c['name']).toList();
    expect(columnNames, contains(AppConstants.colReminderAt));

    final rows = await upgraded.query(AppConstants.notesTable);
    expect(rows, hasLength(1));
    expect(rows.single['title'], 'Kept after upgrade');
    expect(rows.single['is_pinned'], 1);
    expect(rows.single[AppConstants.colReminderAt], isNull);

    await service.close();
  });

  test('a brand-new install creates the current schema directly', () async {
    final service = DatabaseService(overrideDatabasePath: dbPath);
    final db = await service.database;

    expect(await db.getVersion(), 2);
    final columns = await db.rawQuery('PRAGMA table_info(notes)');
    expect(
      columns.map((c) => c['name']),
      contains(AppConstants.colReminderAt),
    );

    await service.close();
  });
}
