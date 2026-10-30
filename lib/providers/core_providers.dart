import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/notification_service.dart';
import '../core/services/preferences_service.dart';
import '../data/database/database_service.dart';
import '../data/repositories/note_repository.dart';

/// Owns the SQLite connection for the whole app. Closed when the
/// [ProviderScope] is disposed.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final service = DatabaseService();
  ref.onDispose(service.close);
  return service;
});

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(
    databaseService: ref.watch(databaseServiceProvider),
  );
});

/// SharedPreferences instance. It must be overridden in `main.dart` after
/// `SharedPreferences.getInstance()` completes, which keeps reads synchronous.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() before use.',
  );
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService(ref.watch(sharedPreferencesProvider));
});

/// Schedules note reminders. Overridden in `main.dart` after `init()`, and
/// replaced with a fake in tests.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
