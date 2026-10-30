import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';

/// Immutable representation of a single note.
@immutable
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.isFavorite = false,
    this.reminderAt,
  });

  final String id;
  final String title;
  final String content;
  final String category;

  /// ARGB colour value used as the card background.
  final int color;
  final bool isPinned;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// When the user wants to be reminded about this note. `null` means none.
  final DateTime? reminderAt;

  /// Builds a note from a SQLite row.
  factory Note.fromMap(Map<String, Object?> map) {
    try {
      final rawReminder = map[AppConstants.colReminderAt] as String?;
      return Note(
        id: map[AppConstants.colId] as String,
        title: (map[AppConstants.colTitle] as String?) ?? '',
        content: (map[AppConstants.colContent] as String?) ?? '',
        category: (map[AppConstants.colCategory] as String?) ??
            AppConstants.fallbackCategory,
        color: (map[AppConstants.colColor] as int?) ??
            AppConstants.defaultNoteColor,
        isPinned: ((map[AppConstants.colIsPinned] as int?) ?? 0) == 1,
        isFavorite: ((map[AppConstants.colIsFavorite] as int?) ?? 0) == 1,
        createdAt: DateTime.parse(map[AppConstants.colCreatedAt] as String),
        updatedAt: DateTime.parse(map[AppConstants.colUpdatedAt] as String),
        reminderAt: rawReminder == null ? null : DateTime.parse(rawReminder),
      );
    } catch (e, st) {
      throw DatabaseException(
        'Corrupted note record could not be read.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Converts this note into a SQLite row.
  Map<String, Object?> toMap() {
    return {
      AppConstants.colId: id,
      AppConstants.colTitle: title,
      AppConstants.colContent: content,
      AppConstants.colCategory: category,
      AppConstants.colColor: color,
      AppConstants.colIsPinned: isPinned ? 1 : 0,
      AppConstants.colIsFavorite: isFavorite ? 1 : 0,
      AppConstants.colCreatedAt: createdAt.toIso8601String(),
      AppConstants.colUpdatedAt: updatedAt.toIso8601String(),
      AppConstants.colReminderAt: reminderAt?.toIso8601String(),
    };
  }

  /// Returns a modified copy.
  ///
  /// Pass [clearReminder] as `true` to remove the reminder. A plain `null`
  /// for [reminderAt] means "keep the current reminder".
  Note copyWith({
    String? title,
    String? content,
    String? category,
    int? color,
    bool? isPinned,
    bool? isFavorite,
    DateTime? updatedAt,
    DateTime? reminderAt,
    bool clearReminder = false,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
    );
  }

  /// Validates user-editable text fields. Throws [ValidationException].
  static void validate({
    required String title,
    required String content,
  }) {
    final trimmedTitle = title.trim();
    final trimmedContent = content.trim();

    if (trimmedTitle.isEmpty && trimmedContent.isEmpty) {
      throw const ValidationException(
        'A note needs a title or some content before it can be saved.',
      );
    }
    if (trimmedTitle.length > AppConstants.maxTitleLength) {
      throw const ValidationException(
        'Title must be ${AppConstants.maxTitleLength} characters or fewer.',
      );
    }
    if (trimmedContent.length > AppConstants.maxContentLength) {
      throw const ValidationException(
        'Content must be ${AppConstants.maxContentLength} characters or fewer.',
      );
    }
  }

  @override
  String toString() => 'Note(id: $id, title: $title)';
}
