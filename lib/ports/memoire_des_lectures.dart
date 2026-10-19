/// Une lecture du serveur gardée sur l'appareil : le corps tel qu'il est arrivé, et
/// l'instant où il est arrivé.
class LectureGardee {
  const LectureGardee({required this.corps, required this.lueLe});

  /// Le JSON reçu, tel quel. ⚠️ Le corps BRUT, et non l'objet du domaine : c'est le
  /// même décodage qui le relit, et une règle de lecture ne s'écrit qu'une fois.
  final String corps;
  final DateTime lueLe;
}

/// Les dernières lectures réussies, gardées pour la lecture hors ligne (20 octobre 2026).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI : L'ÉCRAN VIDE ÉTAIT LE PIRE DES DEUX MENSONGES.
///
/// Sans réseau, l'accueil, les échéances, les documents, les honoraires, la DSF et
/// la paie disaient « Pas de réseau » et rien d'autre. Or l'adhérent qui ouvre
/// l'application dans une boutique sans 3G veut savoir ce qu'il doit, et ce qu'il
/// savait il y a deux heures vaut bien mieux que rien — À CONDITION DE LE DIRE.
/// L'écran montre donc la dernière lecture, sous un bandeau « Hors ligne · mis à
/// jour il y a 2 h ». Jamais une copie sans sa date.
///
/// ⚠️ ELLE N'AUTORISE RIEN. Comme la mémoire des dossiers, elle ne sert qu'à lire :
/// un paiement ou un envoi part toujours au serveur, qui juge.
///
/// ⚠️ ELLE SE VIDE À LA DÉCONNEXION. Le téléphone d'une boutique passe de main en
/// main ; les honoraires d'un adhérent n'ont pas à rester lisibles après lui.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class MemoireDesLectures {
  Future<LectureGardee?> lire(String cle);
  Future<void> retenir(String cle, String corps, DateTime lueLe);
  Future<void> oublierTout();
}
