/// Document légal affiché dans l'app (conditions d'utilisation, politique de
/// confidentialité…), découpé en sections.
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.lastUpdatedLabel,
    required this.sections,
    required this.isDraft,
  });

  final String title;

  /// Date de dernière mise à jour, déjà formulée pour l'affichage.
  final String lastUpdatedLabel;

  final List<LegalDocumentSection> sections;

  /// Vrai tant que le texte n'a pas été validé par l'équipe : l'écran affiche
  /// alors un bandeau "version provisoire".
  final bool isDraft;
}

class LegalDocumentSection {
  const LegalDocumentSection({required this.heading, required this.body});

  final String heading;
  final String body;
}
