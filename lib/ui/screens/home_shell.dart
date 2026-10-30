import 'package:flutter/material.dart';

import 'package:quicknotes/ui/screens/categories_screen.dart';
import 'package:quicknotes/ui/screens/favorites_screen.dart';
import 'package:quicknotes/ui/screens/home_screen.dart';
import 'package:quicknotes/ui/screens/settings_screen.dart';
import 'package:quicknotes/ui/utils/note_actions.dart';

/// Hosts the four main tabs. [IndexedStack] keeps each tab's state (scroll
/// position, search text) alive when switching between them.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const int _settingsIndex = 3;

  int _index = 0;

  static const List<Widget> _pages = [
    HomeScreen(),
    CategoriesScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: _index == _settingsIndex
          ? null
          : FloatingActionButton(
              tooltip: 'New note',
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              onPressed: () => openNoteEditor(context),
              child: const Icon(Icons.add_rounded, size: 30),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
