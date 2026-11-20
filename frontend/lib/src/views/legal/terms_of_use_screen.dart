import 'package:flutter/material.dart';
import 'package:traveltrack/src/viewmodels/terms_of_use_viewmodel.dart';
import 'package:traveltrack/src/widgets/legal_document_view.dart';

/// Affiche les conditions d'utilisation. Ouvert par-dessus l'écran précédent
/// (création de compte, profil…), la flèche retour y ramène.
class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({
    super.key,
    this.termsOfUseViewModel = const TermsOfUseViewModel(),
  });

  final TermsOfUseViewModel termsOfUseViewModel;

  @override
  Widget build(BuildContext context) {
    final termsOfUse = termsOfUseViewModel.termsOfUse;
    return Scaffold(
      appBar: AppBar(title: Text(termsOfUse.title)),
      body: SafeArea(child: LegalDocumentView(legalDocument: termsOfUse)),
    );
  }
}
