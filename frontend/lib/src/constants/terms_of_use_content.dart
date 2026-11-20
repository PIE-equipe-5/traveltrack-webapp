import 'package:traveltrack/src/models/legal_document.dart';

/// Texte des conditions d'utilisation affiché dans l'app.
///
/// Version provisoire rédigée à partir du périmètre du MVP : elle doit être
/// relue et remplacée par le texte validé par l'équipe avant la mise en
/// production. Passer [LegalDocument.isDraft] à `false` retire le bandeau
/// "version provisoire" de l'écran.
abstract final class TermsOfUseContent {
  static const document = LegalDocument(
    title: 'Conditions d\'utilisation',
    lastUpdatedLabel: 'Dernière mise à jour : novembre 2026',
    isDraft: true,
    sections: [
      LegalDocumentSection(
        heading: '1. Objet',
        body:
            'Les présentes conditions encadrent l\'utilisation de l\'application '
            'TravelTrack, qui propose de découvrir une ville à travers des '
            'quêtes culturelles, gastronomiques et historiques géolocalisées. '
            'En créant un compte, tu acceptes ces conditions.',
      ),
      LegalDocumentSection(
        heading: '2. Création de compte',
        body:
            'Tu dois fournir une adresse email valide et choisir un mot de '
            'passe. Tu es responsable de la confidentialité de tes '
            'identifiants et de toute activité réalisée depuis ton compte.',
      ),
      LegalDocumentSection(
        heading: '3. Quêtes et validation',
        body:
            'Une quête est validée grâce à une photo prise sur place et à la '
            'vérification de ta position GPS. Toute tentative de contourner '
            'ce système (photo qui ne correspond pas au lieu, position '
            'falsifiée…) peut entraîner l\'annulation de la quête ou la '
            'suspension du compte.',
      ),
      LegalDocumentSection(
        heading: '4. Photos publiées',
        body:
            'Tu restes propriétaire des photos que tu envoies. Elles peuvent '
            'être vérifiées par l\'équipe de modération, qui peut retirer '
            'toute photo inappropriée, illégale ou portant atteinte aux droits '
            'd\'autrui. N\'envoie pas de photo où des personnes sont '
            'reconnaissables sans leur accord.',
      ),
      LegalDocumentSection(
        heading: '5. Comportement sur place',
        body:
            'Les quêtes se déroulent dans l\'espace public. Respecte le code '
            'de la route, les lieux visités, leurs règles d\'accès et les '
            'personnes que tu croises. TravelTrack ne peut être tenu '
            'responsable d\'un incident survenu pendant une quête.',
      ),
      LegalDocumentSection(
        heading: '6. Géolocalisation et données personnelles',
        body:
            'Ta position est utilisée uniquement pour afficher les quêtes '
            'autour de toi et valider celles que tu réalises. Elle n\'est '
            'jamais revendue. Tes données sont hébergées dans l\'Union '
            'européenne. Tu peux à tout moment demander l\'export ou la '
            'suppression de tes données.',
      ),
      LegalDocumentSection(
        heading: '7. Suppression du compte',
        body:
            'Tu peux supprimer ton compte quand tu le souhaites. TravelTrack '
            'peut suspendre ou supprimer un compte qui ne respecte pas ces '
            'conditions.',
      ),
      LegalDocumentSection(
        heading: '8. Évolution des conditions',
        body:
            'Ces conditions peuvent évoluer. En cas de changement important, '
            'tu en seras informé dans l\'application avant leur entrée en '
            'vigueur.',
      ),
    ],
  );
}
