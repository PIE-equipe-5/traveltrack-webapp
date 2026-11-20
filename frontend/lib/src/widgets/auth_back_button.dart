import 'package:flutter/material.dart';
import 'package:traveltrack/src/constants/app_strings.dart';

/// Flèche retour affichée en haut des écrans d'authentification.
/// [onPressed] à null la désactive (pendant un chargement, par exemple).
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: AppStrings.backButtonTooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}
