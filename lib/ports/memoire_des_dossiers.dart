/// Les derniers dossiers lus sur le serveur, gardés sur l'appareil (19 octobre 2026).
///
/// ⚠️ POUR LE SEUL DÉPÔT HORS LIGNE. Sans elle, un démarrage sans réseau laissait la
/// liste vide : l'onglet de dépôt refusait la photo, alors que la file est faite
/// précisément pour ce cas. La liste gardée n'autorise rien : le serveur juge chaque
/// remise, et refuse un dossier qu'on aurait perdu entre-temps.
abstract class MemoireDesDossiers {
  Future<List<String>?> lire();
  Future<void> retenir(List<String> dossiers);
}
