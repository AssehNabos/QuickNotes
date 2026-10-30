import 'package:quicknotes/core/services/notification_service.dart';
import 'package:quicknotes/data/models/note.dart';
import 'package:quicknotes/providers/notes_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Switches sqflite to the FFI implementation so tests run on the host
/// machine without a device. Call once from `main()` in each test file.
void initDatabaseFactoryForTests() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Records notification calls instead of talking to the platform.
class FakeNotificationService extends NotificationService {
  final List<String> synced = [];
  final List<String> cancelled = [];
  int cancelAllCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> syncReminder(Note note) async {
    synced.add(note.id);
  }

  @override
  Future<void> cancelReminder(String noteId) async {
    cancelled.add(noteId);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
  }
}

/// Serves a fixed list of notes, so widget tests need no database.
class FakeNotesNotifier extends NotesNotifier {
  FakeNotesNotifier(this._notes);

  final List<Note> _notes;

  @override
  Future<List<Note>> build() async => sortNotes(_notes);
}

/// Builds a note with sensible defaults for tests.
Note sampleNote({
  String id = 'note-1',
  String title = 'Groceries',
  String content = 'Milk, eggs, bread',
  String category = 'Personal',
  int color = 0xFFFFFFFF,
  bool isPinned = false,
  bool isFavorite = false,
  DateTime? reminderAt,
  DateTime? updatedAt,
}) {
  final when = updatedAt ?? DateTime(2026, 10, 1, 9);
  return Note(
    id: id,
    title: title,
    content: content,
    category: category,
    color: color,
    isPinned: isPinned,
    isFavorite: isFavorite,
    createdAt: when,
    updatedAt: when,
    reminderAt: reminderAt,
  );
}

/// The `notes` table as it existed in schema version 1, before reminders.
const String schemaV1 = '''
  CREATE TABLE notes (
    id TEXT PRIMARY KEY NOT NULL,
    title TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL DEFAULT 'Others',
    color INTEGER NOT NULL DEFAULT 4294967295,
    is_pinned INTEGER NOT NULL DEFAULT 0,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
''';
