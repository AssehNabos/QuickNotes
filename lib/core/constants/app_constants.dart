/// Application-wide constants.
///
/// Centralising these values keeps the database schema, the repository and
/// the UI in agreement with one another.
class AppConstants {
  AppConstants._();

  static const String appName = 'QuickNotes';

  // Database
  static const String databaseName = 'quicknotes.db';
  static const int databaseVersion = 2;

  // Table and columns
  static const String notesTable = 'notes';
  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colContent = 'content';
  static const String colCategory = 'category';
  static const String colColor = 'color';
  static const String colIsPinned = 'is_pinned';
  static const String colIsFavorite = 'is_favorite';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';
  static const String colReminderAt = 'reminder_at';

  // Limits
  static const int maxTitleLength = 120;
  static const int maxContentLength = 100000;

  /// Default categories offered to the user.
  static const List<String> defaultCategories = [
    'Personal',
    'School',
    'Work',
    'Ideas',
    'Important',
    'Others',
  ];

  /// Default category assigned when none is selected.
  static const String fallbackCategory = 'Others';

  /// Preset note background colours (ARGB ints) offered in the colour picker.
  static const List<int> noteColorPalette = [
    0xFFFFFFFF, // White
    0xFFFFF3C4, // Butter
    0xFFFFD6D6, // Rose
    0xFFD7F5DD, // Mint
    0xFFD6E9FF, // Sky
    0xFFE6DAFF, // Lavender
    0xFFFFE3C2, // Peach
    0xFFE5E7EB, // Slate
    0xFF3B6CF6, // Blue
  ];

  /// Default note colour.
  static const int defaultNoteColor = 0xFFFFFFFF;
}
