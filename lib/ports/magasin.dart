import '../domaine/depot.dart';

/// Où la file survit à la fermeture de l'application.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI C'EST UN PORT, ET PAS DIRECTEMENT UNE BASE SQLITE
///
/// La règle de renvoi — quoi partir, dans quel ordre, combien de fois — est ce
/// qu'il y a de plus délicat dans cette application, et c'est aussi ce qu'on ne
/// peut pas vérifier à la main : il faudrait couper le réseau au bon moment,
/// vingt fois de suite. Elle doit donc être éprouvée par des tests, et des tests
/// qui ouvrent une vraie base sur un vrai appareil ne s'exécutent ni vite ni
/// partout.
///
/// La file parle donc à ce port. En essai, un magasin en mémoire ; sur
/// l'appareil, un magasin durable. La règle, elle, est la même, et c'est elle
/// qu'on vérifie.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class MagasinDeDepots {
  /// Tous les dépôts connus, dans l'ordre où ils ont été pris.
  Future<List<Depot>> tous();

  /// Range un dépôt, ou remplace celui qui porte le même identifiant.
  Future<void> ranger(Depot depot);

  /// Oublie un dépôt remis. ⚠️ Le fichier photographié, lui, est effacé par
  /// l'appelant : le magasin ne connaît pas le disque.
  Future<void> oublier(String identifiant);
}
