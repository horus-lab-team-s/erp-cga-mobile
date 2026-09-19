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
}
