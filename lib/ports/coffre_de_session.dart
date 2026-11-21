/// Où la session survit à la fermeture de l'application (19 octobre 2026).
///
/// ⚠️ LE COFFRE DU SYSTÈME, JAMAIS UN FICHIER EN CLAIR. La session était gardée en
/// mémoire seulement, faute de magasin protégé : l'adhérent retapait courriel et mot de
/// passe à chaque ouverture, en 3G, sur un clavier de téléphone. Le coffre (le Keystore
/// d'Android) chiffre la valeur avec une clé que l'appareil ne livre pas. Le serveur
/// garde la main : la session expire au bout de douze heures, et se révoque à distance.
abstract class CoffreDeSession {
  Future<String?> lire();
  Future<void> ecrire(String session);
  Future<void> effacer();
}
