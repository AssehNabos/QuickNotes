import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quicknotes/core/constants/app_constants.dart';
import 'package:quicknotes/core/theme/app_theme.dart';
import 'package:quicknotes/data/models/note.dart';
import 'package:quicknotes/providers/core_providers.dart';
import 'package:quicknotes/providers/notes_provider.dart';
import 'package:quicknotes/ui/utils/feedback.dart';
import 'package:quicknotes/ui/utils/formatters.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.note});

  /// `null` creates a new note; a value edits that note.
  final Note? note;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final String _initialTitle;
  late final String _initialContent;
  late final int _initialColor;
  late final String _initialCategory;
  late final DateTime? _initialReminder;

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late int _color;
  late String _category;
  DateTime? _reminderAt;
  bool _saving = false;

  bool get _isEditing => widget.note != null;

  bool get _isDirty {
    return _titleController.text != _initialTitle ||
        _contentController.text != _initialContent ||
        _color != _initialColor ||
        _category != _initialCategory ||
        _reminderAt != _initialReminder;
  }

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _initialTitle = note?.title ?? '';
    _initialContent = note?.content ?? '';
    _initialColor = note?.color ?? AppConstants.defaultNoteColor;
    _initialCategory = note?.category ?? AppConstants.fallbackCategory;
    _initialReminder = note?.reminderAt;

    _titleController = TextEditingController(text: _initialTitle)
      ..addListener(_onFieldChanged);
    _contentController = TextEditingController(text: _initialContent)
      ..addListener(_onFieldChanged);
    _color = _initialColor;
    _category = _initialCategory;
    _reminderAt = _initialReminder;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _setColor(int value) => setState(() => _color = value);

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final category in AppConstants.defaultCategories)
                ListTile(
                  title: Text(category),
                  trailing: category == _category
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(category),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _category = picked);
    }
  }

  /// Date then time picker. Rejects times that are already in the past.
  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final initial = _reminderAt ?? now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final chosen = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!chosen.isAfter(DateTime.now())) {
      showMessage(context, 'Choose a time in the future.', isError: true);
      return;
    }

    final granted =
        await ref.read(notificationServiceProvider).requestPermission();
    if (!granted && mounted) {
      showMessage(
        context,
        'Notifications are off. Enable them in system settings to get reminders.',
        isError: true,
      );
    }
    if (mounted) setState(() => _reminderAt = chosen);
  }

  void _clearReminder() => setState(() => _reminderAt = null);

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved edits will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final notifier = ref.read(notesProvider.notifier);
    // Captured before the screen closes, so the confirmation can still show.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      if (_isEditing) {
        if (_isDirty) {
          final reminderChanged = _reminderAt != _initialReminder;
          await notifier.editNote(
            widget.note!,
            title: _titleController.text,
            content: _contentController.text,
            category: _category,
            color: _color,
            reminderAt: reminderChanged ? _reminderAt : null,
            clearReminder: reminderChanged && _reminderAt == null,
          );
        }
      } else {
        await notifier.createNote(
          title: _titleController.text,
          content: _contentController.text,
          category: _category,
          color: _color,
          reminderAt: _reminderAt,
        );
      }

      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Note saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showMessage(context, errorMessage(e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final background = AppTheme.noteBackground(_color, brightness);
    final foreground = AppTheme.noteForeground(brightness);
    final muted = AppTheme.noteMutedForeground(brightness);
    final note = widget.note;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          foregroundColor: foreground,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () {
              if (_isDirty) {
                _confirmDiscard();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(_isEditing ? 'Edit Note' : 'Create a Note'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note != null
                      ? 'LAST MODIFIED ${formatLastModified(note.updatedAt)}'
                      : 'NEW NOTE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      AppConstants.maxTitleLength,
                    ),
                  ],
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Title',
                    hintStyle: TextStyle(color: muted),
                  ),
                ),
                Divider(height: 24, color: muted.withValues(alpha: 0.4)),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        AppConstants.maxContentLength,
                      ),
                    ],
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foreground,
                      height: 1.5,
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: 'Start writing...',
                      hintStyle: TextStyle(color: muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _EditorToolbar(
          selectedColor: _color,
          category: _category,
          reminderAt: _reminderAt,
          foreground: foreground,
          onColorSelected: _setColor,
          onCategoryTap: _pickCategory,
          onReminderTap: _pickReminder,
          onClearReminder: _clearReminder,
        ),
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.selectedColor,
    required this.category,
    required this.reminderAt,
    required this.foreground,
    required this.onColorSelected,
    required this.onCategoryTap,
    required this.onReminderTap,
    required this.onClearReminder,
  });

  final int selectedColor;
  final String category;
  final DateTime? reminderAt;
  final Color foreground;
  final ValueChanged<int> onColorSelected;
  final VoidCallback onCategoryTap;
  final VoidCallback onReminderTap;
  final VoidCallback onClearReminder;

  @override
  Widget build(BuildContext context) {
    final reminder = reminderAt;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AppConstants.noteColorPalette.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final value = AppConstants.noteColorPalette[index];
                  final isSelected = value == selectedColor;
                  return GestureDetector(
                    onTap: () => onColorSelected(value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(value),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? foreground : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.black87,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: onCategoryTap,
                  icon: const Icon(Icons.label_outline_rounded),
                  label: Text(category),
                  style: TextButton.styleFrom(foregroundColor: foreground),
                ),
                TextButton.icon(
                  onPressed: onReminderTap,
                  icon: Icon(
                    reminder == null
                        ? Icons.alarm_rounded
                        : Icons.alarm_on_rounded,
                  ),
                  label: Text(
                    reminder == null
                        ? 'Remind me'
                        : formatReminder(reminder),
                  ),
                  style: TextButton.styleFrom(foregroundColor: foreground),
                ),
                if (reminder != null)
                  IconButton(
                    tooltip: 'Remove reminder',
                    icon: Icon(Icons.close_rounded, color: foreground),
                    onPressed: onClearReminder,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
