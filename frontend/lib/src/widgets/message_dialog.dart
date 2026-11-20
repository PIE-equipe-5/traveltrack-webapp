import 'package:flutter/material.dart';
import 'package:traveltrack/src/constants/app_strings.dart';

/// Affiche une popup d'information avec un titre, un message et un seul
/// bouton de fermeture. Se termine quand l'utilisateur ferme la popup.
Future<void> showMessageDialog({
  required BuildContext context,
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(AppStrings.messageDialogCloseButton),
        ),
      ],
    ),
  );
}
