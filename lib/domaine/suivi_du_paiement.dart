/// Ce qui suit une demande de débit mobile money envoyée (20 octobre 2026).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ « ENVOYÉE » N'EST TOUJOURS PAS « PAYÉE », MAIS L'ÉCRAN NE SE TAISAIT PLUS.
///
/// La feuille se refermait sur « Validez sur votre téléphone », et la carte
/// reprenait sa place, inchangée, avec son bouton « Payer ». L'adhérent qui venait
/// de composer son code voyait la même carte qu'avant, concluait que rien n'était
/// passé, et payait une seconde fois — ou appelait.
///
/// La carte dit donc « Paiement en attente de validation » dès la demande partie,
/// et l'écran relit le serveur trois fois, à dix secondes d'intervalle : c'est le
/// temps habituel d'une validation, et la notification de l'opérateur arrive le
/// plus souvent dans la minute. Si la période passe à « Réglée », il le dit. Sinon
/// la carte garde sa mention, et la prochaine lecture tranchera.
///
/// ⚠️ Trois lectures, pas une boucle : un adhérent qui a refermé la demande sans
/// valider ne doit pas laisser son téléphone interroger le serveur sans fin.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// Combien de fois relire, et à quel intervalle.
const lecturesApresUnPaiement = 3;
const intervalleApresUnPaiement = Duration(seconds: 10);

/// Relit jusqu'à ce que [estRegle] le dise, au plus [lectures] fois.
///
/// Rend vrai dès que le règlement est constaté. [continuer] faux (l'écran est
/// fermé) arrête tout sans rien relire.
Future<bool> suivreLePaiement({
  required Future<bool> Function() estRegle,
  required bool Function() continuer,
  int lectures = lecturesApresUnPaiement,
  Duration intervalle = intervalleApresUnPaiement,
}) async {
  for (var i = 0; i < lectures; i++) {
    await Future<void>.delayed(intervalle);
    if (!continuer()) return false;
    if (await estRegle()) return true;
  }
  return false;
}
