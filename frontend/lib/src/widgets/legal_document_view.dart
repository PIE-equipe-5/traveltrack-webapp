import 'package:flutter/material.dart';
import 'package:traveltrack/src/constants/app_strings.dart';
import 'package:traveltrack/src/models/legal_document.dart';

/// Contenu défilant d'un document légal : bandeau "version provisoire" si
/// besoin, date de mise à jour, puis chaque section avec son titre. Sert aux
/// conditions d'utilisation, et pourra servir aux mentions légales et à la
/// politique de confidentialité.
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({super.key, required this.legalDocument});

  final LegalDocument legalDocument;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        if (legalDocument.isDraft) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              AppStrings.legalDocumentDraftNotice,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onTertiaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          legalDocument.lastUpdatedLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        for (final section in legalDocument.sections) ...[
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(
              section.heading,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(section.body, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}
