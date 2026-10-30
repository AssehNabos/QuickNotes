import 'package:flutter/material.dart';

import 'package:quicknotes/core/errors/app_exception.dart';

const String genericErrorMessage = 'Something went wrong. Please try again.';

/// User-facing text for any error. App exceptions carry their own safe
/// message; anything else gets a generic one so internals are never shown.
String errorMessage(Object error) {
  return error is AppException ? error.message : genericErrorMessage;
}

/// Shows a floating snackbar. Call it while [context] is still mounted.
void showMessage(BuildContext context, String text, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? scheme.error : null,
      ),
    );
}

/// Runs [action] and shows any error as a snackbar instead of crashing.
Future<void> runWithFeedback(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      showMessage(context, errorMessage(e), isError: true);
    }
  }
}
