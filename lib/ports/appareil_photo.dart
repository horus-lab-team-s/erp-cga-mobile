/// De quoi vient une image.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI UN PORT POUR QUELQUE CHOSE D'AUSSI SIMPLE
///
/// Parce que la règle qui suit la prise de vue — recopier le fichier à un
/// endroit durable, poser un identifiant, entrer dans la file — est exactement
/// celle qu'on ne peut pas éprouver sur un poste : il n'y a pas d'appareil
/// photo, et il n'y en aura pas davantage dans la chaîne d'intégration.
///
/// Le port rend cette règle vérifiable avec une source d'images feinte, et
/// l'appareil réel n'est alors plus qu'un adaptateur de quinze lignes.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class AppareilPhoto {
  /// Prend une photo et rend le chemin du fichier obtenu.
  ///
  /// ⚠️ Rend `null` quand la personne **renonce**, et ce cas n'est pas une
  /// erreur : on ferme l'appareil photo par réflexe, bien plus souvent qu'on ne
  /// le croit. Le traiter comme un échec afficherait un message d'erreur à
  /// quelqu'un qui vient simplement de changer d'avis.
  ///
  /// ⚠️ Le fichier rendu est **provisoire**. Le système le range dans un cache
  /// qu'il peut reprendre à tout moment, et il le fait sans prévenir dès que la
  /// place manque. Personne ne doit conserver ce chemin : voir `PriseDeVue`.
  Future<String?> photographier();
}
