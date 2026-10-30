import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quicknotes/app.dart';
import 'package:quicknotes/data/models/note.dart';
import 'package:quicknotes/providers/core_providers.dart';
import 'package:quicknotes/providers/notes_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

Future<Widget> _app(List<Note> notes) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      notesProvider.overrideWith(() => FakeNotesNotifier(notes)),
    ],
    child: const QuickNotesApp(),
  );
}

void main() {
  testWidgets('shows the empty state when there are no notes', (tester) async {
    await tester.pumpWidget(await _app(const []));
    await tester.pumpAndSettle();

    expect(find.text('No notes yet'), findsWidgets);
    expect(find.text('You have 0 notes.'), findsNothing);
    expect(find.text('Capture your first idea.'), findsOneWidget);
  });

  testWidgets('shows saved notes on the dashboard', (tester) async {
    await tester.pumpWidget(
      await _app([
        sampleNote(id: '1', title: 'Groceries'),
        sampleNote(id: '2', title: 'Sprint review', category: 'Work'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsWidgets);
    expect(find.text('Sprint review'), findsWidgets);
    expect(find.text('You have 2 notes.'), findsOneWidget);
  });

  testWidgets('search shows matching results', (tester) async {
    await tester.pumpWidget(
      await _app([
        sampleNote(id: '1', title: 'Groceries'),
        sampleNote(id: '2', title: 'Budget meeting', category: 'Work'),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'budget');
    await tester.pumpAndSettle();

    expect(find.text('Results'), findsOneWidget);
    expect(find.text('No matching notes'), findsNothing);
  });

  testWidgets('search with no matches shows a clear message', (tester) async {
    await tester.pumpWidget(
      await _app([sampleNote(id: '1', title: 'Groceries')]),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz-no-match');
    await tester.pumpAndSettle();

    expect(find.text('No matching notes'), findsOneWidget);
  });

  testWidgets('bottom navigation switches between tabs', (tester) async {
    await tester.pumpWidget(await _app(const []));
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);

    await tester.tap(
      find.descendant(of: navBar, matching: find.text('Settings')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(
      find.descendant(of: navBar, matching: find.text('Favorites')),
    );
    await tester.pumpAndSettle();
    expect(find.text('No favorites yet'), findsOneWidget);
  });
}
