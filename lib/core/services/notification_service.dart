import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/note.dart';

/// Schedules local reminders for notes.
///
/// Reminders are best-effort. Every platform call is wrapped so that a
/// notification failure is logged and never stops a note from being saved.
///
/// Times are scheduled as absolute instants (UTC-based), so no device
/// timezone lookup is needed for one-off reminders.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  tz.Location? _utc;

  static const String _channelId = 'quicknotes_reminders';
  static const String _channelName = 'Note reminders';
  static const String _channelDescription = 'Reminders you set on your notes';

  bool get isInitialized => _initialized;

  /// Sets up the plugin. Safe to call more than once.
  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      _utc = tz.getLocation('UTC');

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: darwin),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('QuickNotes: notifications unavailable: $e');
    }
  }

  /// Asks the user for notification permission (Android 13+ and iOS).
  ///
  /// Returns `false` if permission was refused or could not be requested.
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    try {
      final android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final ios =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      final androidGranted =
          await android?.requestNotificationsPermission() ?? true;
      final iosGranted = await ios?.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ??
          true;
      return androidGranted && iosGranted;
    } catch (e) {
      debugPrint('QuickNotes: permission request failed: $e');
      return false;
    }
  }

  /// Makes the scheduled reminder match [note].
  ///
  /// Schedules a reminder if the note has a future reminder time. Otherwise
  /// cancels any existing one. Call after every create or edit.
  Future<void> syncReminder(Note note) async {
    final reminderAt = note.reminderAt;
    if (reminderAt == null || !reminderAt.isAfter(DateTime.now())) {
      await cancelReminder(note.id);
      return;
    }
    if (!_initialized || _utc == null) return;

    try {
      await _plugin.zonedSchedule(
        _notificationIdFor(note.id),
        'Reminder',
        _bodyFor(note),
        tz.TZDateTime.from(reminderAt.toUtc(), _utc!),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: note.id,
      );
    } catch (e) {
      debugPrint('QuickNotes: could not schedule reminder: $e');
    }
  }

  /// Cancels the reminder for [noteId], if there is one.
  Future<void> cancelReminder(String noteId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(_notificationIdFor(noteId));
    } catch (e) {
      debugPrint('QuickNotes: could not cancel reminder: $e');
    }
  }

  /// Cancels every scheduled reminder. Used by "Delete all notes".
  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('QuickNotes: could not cancel reminders: $e');
    }
  }

  static String _bodyFor(Note note) {
    final title = note.title.trim();
    if (title.isNotEmpty) return title;
    final content = note.content.trim();
    if (content.isEmpty) return 'Tap to open your note.';
    return content.split('\n').first;
  }

  /// Stable 31-bit FNV-1a hash of the note id.
  ///
  /// Must be stable across app launches so a reminder scheduled in one
  /// session can still be cancelled in the next. `String.hashCode` is not
  /// guaranteed to be stable, so it is not used here.
  static int _notificationIdFor(String noteId) {
    var hash = 0x811c9dc5;
    for (final unit in noteId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
