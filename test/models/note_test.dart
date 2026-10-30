import 'package:flutter_test/flutter_test.dart';
import 'package:quicknotes/core/constants/app_constants.dart';
import 'package:quicknotes/core/errors/app_exception.dart';
import 'package:quicknotes/data/models/note.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('Note.validate', () {
    test('rejects a note with neither title nor content', () {
      expect(
        () => Note.validate(title: '   ', content: '  '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('accepts a note that has only content', () {
      expect(
        () => Note.validate(title: '', content: 'Just a thought'),
        returnsNormally,
      );
    });

    test('rejects a title longer than the limit', () {
      expect(
        () => Note.validate(
          title: 'a' * (AppConstants.maxTitleLength + 1),
          content: 'x',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('Note SQLite mapping', () {
    test('round-trips every field, including the reminder', () {
      final reminder = DateTime(2026, 11, 2, 9, 30);
      final original = sampleNote(
        isPinned: true,
        isFavorite: true,
        reminderAt: reminder,
      );

      final restored = Note.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.content, original.content);
      expect(restored.category, original.category);
      expect(restored.color, original.color);
      expect(restored.isPinned, isTrue);
      expect(restored.isFavorite, isTrue);
      expect(restored.createdAt, original.createdAt);
      expect(restored.reminderAt, reminder);
    });

    test('stores pin and favourite flags as 0 or 1', () {
      final map = sampleNote(isPinned: true, isFavorite: false).toMap();
      expect(map[AppConstants.colIsPinned], 1);
      expect(map[AppConstants.colIsFavorite], 0);
    });

    test('stores a missing reminder as null', () {
      final map = sampleNote().toMap();
      expect(map[AppConstants.colReminderAt], isNull);
    });
  });

  group('Note.copyWith', () {
    test('keeps the reminder unless told to clear it', () {
      final reminder = DateTime(2026, 11, 2, 9);
      final note = sampleNote(reminderAt: reminder);

      expect(note.copyWith(title: 'New').reminderAt, reminder);
      expect(note.copyWith(clearReminder: true).reminderAt, isNull);
    });
  });
}
