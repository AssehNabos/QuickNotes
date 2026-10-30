import 'package:intl/intl.dart';

/// Short date for note cards: "TODAY" or "SAT, 04 JUNE 24".
String formatCardDate(DateTime date) {
  final now = DateTime.now();
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  if (isToday) return 'TODAY';
  return DateFormat('EEE, dd MMM yy').format(date).toUpperCase();
}

/// Label used in the editor header: "24 MAY, 24".
String formatLastModified(DateTime date) {
  return DateFormat('dd MMM, yy').format(date).toUpperCase();
}

/// Full timestamp used on the note view screen: "4 Jun 2026, 9:41 AM".
String formatFullDate(DateTime date) {
  return DateFormat('d MMM yyyy, h:mm a').format(date);
}

/// Reminder label used in the editor and note view: "Mon, 2 Nov · 9:00 AM".
String formatReminder(DateTime date) {
  return DateFormat('EEE, d MMM · h:mm a').format(date);
}
