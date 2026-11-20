import 'package:traveltrack/src/constants/terms_of_use_content.dart';
import 'package:traveltrack/src/models/legal_document.dart';

/// Fournit à l'écran le texte des conditions d'utilisation. Le texte est
/// embarqué dans l'app : il n'y a ni chargement ni erreur possible.
class TermsOfUseViewModel {
  const TermsOfUseViewModel();

  LegalDocument get termsOfUse => TermsOfUseContent.document;
}
