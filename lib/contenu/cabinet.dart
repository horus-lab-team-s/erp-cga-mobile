/// Les coordonnées du cabinet, en un seul endroit.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ RECOPIÉES DE LA VITRINE, PAS ÉCRITES ICI.
///
/// La source est `erp-cga-vitrine/messages/fr/pages.json`, clé `contact.canaux`,
/// et `vitrine.json`, clés `cta` et `pied`. Un numéro qui diffère d'un canal à
/// l'autre, et l'adhérent appelle celui qui ne répond pas : il en conclut que le
/// cabinet ne décroche jamais.
///
/// Quand la vitrine change un numéro, ce fichier doit changer le même jour.
/// ─────────────────────────────────────────────────────────────────────────────
abstract final class Cabinet {
  static const nom = 'CGA Broad Range Consulting Group';

  /// « Le canal le plus utilisé par nos clients », dit la vitrine.
  static const whatsapp = '699 902 184';

  /// ⚠️ L'indicatif 237 est EXIGÉ par le lien : sans lui, WhatsApp ouvre une
  /// discussion avec un numéro qui n'existe pas, et ne le dit pas.
  static final whatsappLien = Uri.parse('https://wa.me/237699902184');

  static const telephone = '+237 233 42 48 47';
  static final telephoneLien = Uri.parse('tel:+237233424847');

  static const courriel = 'contact@cga-brcgroup.com';
  static final courrielLien = Uri.parse('mailto:contact@cga-brcgroup.com');

  static const ville = 'Douala';

  /// La mention d'agrément, telle que la vitrine la porte en pied de page.
  static const agrement =
      'Agréé par le ministre des Finances, arrêté n° 00000048 du 28 janvier '
      '2020.';
}
