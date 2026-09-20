import '../domaine/echeance.dart';
import '../domaine/preuve.dart';
import '../domaine/piece_remise.dart';

/// Ce que les écrans attendent du serveur, et rien de plus.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI CE PORT EXISTE, ALORS QUE `ClientApi` SUFFISAIT
///
/// Il ne suffisait pas : il rendait les écrans **invérifiables**. `ClientApi`
/// ouvre une connexion réseau dès sa construction ; un cas d'essai qui en
/// fabrique un ouvre donc une connexion, et un écran qui en dépend ne peut être
/// éprouvé qu'avec un serveur en face.
///
/// Résultat, et il était visible dans les comptes : trente-cinq cas, et pas un
/// seul sur un écran. Tout ce que l'adhérent voit — le message de refus, le
/// bouton qui se désactive, le compte qui se met à jour — n'était vérifié par
/// personne. Ce sont pourtant les seules choses qu'il touche.
///
/// Le port ne déclare que les trois gestes dont les écrans ont besoin. Il tient
/// en dix lignes, et c'est ce qui permet d'en écrire une doublure en cinq.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class ServiceDeSession {
  /// Rend vrai si le serveur a reconnu le compte.
  Future<bool> ouvrirUneSession(String courriel, String motDePasse);

  /// Ferme la session côté serveur, puis l'oublie.
  Future<void> fermerLaSession();

  /// Les dossiers que ce compte a le droit de déposer.
  Future<List<String>> mesDossiers();

  /// Les pièces que le CABINET détient pour ce dossier, avec leur avancement.
  ///
  /// ⚠️ Un quatrième geste, et il a fallu le justifier : le port tient sa valeur
  /// de sa brièveté. Celui-ci la mérite parce que l'écran d'historique en dépend
  /// entièrement, et qu'un écran qui dépend d'un `ClientApi` est un écran que
  /// personne ne peut éprouver sans serveur en face — ce que l'en-tête de ce
  /// fichier raconte déjà pour les trois autres.
  Future<Historique> mesPieces(String dossier);

  /// Ce que l'adhérent doit, et quand.
  ///
  /// ⚠️ Une obligation par carte, telle que le serveur la rend. Il réduit
  /// volontairement : sur le dossier d'essai, la liste complète compterait
  /// soixante-dix lignes. Recomposer ici ce qu'il a réduit là-bas rendrait
  /// l'écran illisible et ferait diverger les deux surfaces.
  Future<Echeancier> mesEcheances(String dossier);

  /// « J'ai déjà payé » : dépose la quittance, puis dit ce qu'elle acquitte.
  ///
  /// ⚠️ Deux actes en un seul geste, et l'ordre compte. La quittance est
  /// d'abord déposée comme une pièce ordinaire ; c'est seulement ensuite qu'on
  /// la rattache à l'obligation. L'inverse serait impossible : on ne peut pas
  /// désigner une pièce qui n'existe pas encore.
  Future<Preuve> envoyerLaPreuve({
    required String dossier,
    required Echeance echeance,
    required String cheminDeLaPhoto,
  });
}
