import '../domaine/mon_mois.dart';

/// Ce que l'accueil connecté demande au serveur, en plus des écrans existants.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ UN PORT À PART, ET NON TROIS MÉTHODES DE PLUS SUR CELUI DE LA SESSION.
///
/// Le port de session a sept doublures de test, une par écran. Y ajouter trois
/// méthodes obligeait à retoucher les sept, pour trois gestes qu'un seul écran
/// emploie. Un port par besoin : l'accueil dépend de celui-ci, les autres
/// écrans n'en savent rien.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class ServiceDuTableauDeBord {
  /// Le nom de la personne connectée, pour la saluer. `null` s'il n'est pas
  /// connu : l'écran dit alors « Bonjour » sans nom, plutôt qu'un identifiant.
  Future<String?> monNom();

  /// Le mois en cours du dossier : ce qui manque, ou que tout est complet.
  Future<MonMois> monMois(String dossier);

  /// Répond à une demande du cabinet par une réponse toute faite.
  Future<SortDeLaReponse> repondre({
    required String demande,
    required NatureDeReponse nature,
  });
}
