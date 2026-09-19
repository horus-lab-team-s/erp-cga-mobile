import 'dart:convert';
import 'dart:io';

import '../domaine/depot.dart';
import '../ports/magasin.dart';

/// La file, écrite sur l'appareil, qui survit à la fermeture de l'application.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI L'ÉCRITURE EST ATOMIQUE, ET POURQUOI CE N'EST PAS UNE PRÉCAUTION
/// DÉCORATIVE
///
/// `writeAsString` écrit par-dessus le fichier existant. Si le système arrête
/// l'application au milieu — et il le fait, sans prévenir, dès que la mémoire
/// manque ou que l'écran s'éteint —, il reste sur le disque un JSON **tronqué**.
/// Au redémarrage suivant, il ne se relit pas, et la file entière est perdue.
///
/// Pas le dépôt en cours : **toute** la file, y compris les pièces déposées la
/// semaine précédente. C'est exactement ce que cette application existe pour ne
/// pas perdre, et le défaut ne se produit jamais sur un poste de développement,
/// où rien n'arrête le processus au mauvais moment.
///
/// On écrit donc à côté, puis on renomme. Le renommage est atomique sur le
/// système de fichiers : à tout instant, le fichier de la file est soit l'ancien
/// entier, soit le nouveau entier, jamais un mélange des deux.
///
/// ⚠️ ET UN FICHIER ILLISIBLE NE FAIT PAS DISPARAÎTRE LA FILE EN SILENCE
///
/// Si malgré tout le contenu ne se relit pas — une version future qui change le
/// format, un disque abîmé —, le fichier est **mis de côté** sous un autre nom
/// au lieu d'être écrasé. L'application redémarre sur une file vide, ce qui est
/// inévitable, mais la matière reste sur l'appareil et une version ultérieure
/// peut la récupérer. Écraser serait transformer un incident en perte définitive.
/// ─────────────────────────────────────────────────────────────────────────────
class MagasinDeFichier implements MagasinDeDepots {
  MagasinDeFichier(this.dossier);

  /// Où écrire. ⚠️ Passé de l'extérieur, et non demandé au système ici : c'est
  /// ce qui rend ce magasin vérifiable sur un poste, dans un dossier temporaire,
  /// sans émulateur ni appareil branché.
  final Directory dossier;

  static const String _nom = 'file-des-depots.json';

  File get _fichier => File('${dossier.path}/$_nom');
  File get _provisoire => File('${dossier.path}/$_nom.en-cours');

  /// La file en mémoire, lue une seule fois puis tenue à jour.
  Map<String, Depot>? _cache;

  Future<Map<String, Depot>> _charger() async {
    final connu = _cache;
    if (connu != null) {
      return connu;
    }
    final charges = <String, Depot>{};
    if (await _fichier.exists()) {
      try {
        final brut = jsonDecode(await _fichier.readAsString()) as List<dynamic>;
        for (final entree in brut) {
          final depot = Depot.depuisJson(entree as Map<String, dynamic>);
          charges[depot.identifiant] = depot;
        }
      } on Object {
        await _mettreDeCote();
      }
    }
    _cache = charges;
    return charges;
  }

  Future<void> _mettreDeCote() async {
    final horodatage = DateTime.now().millisecondsSinceEpoch;
    try {
      await _fichier.rename('${dossier.path}/$_nom.illisible-$horodatage');
    } on Object {
      // Si même le renommage échoue, il n'y a plus rien à tenter ici : mieux
      // vaut démarrer sur une file vide que refuser de démarrer.
    }
  }

  Future<void> _ecrire(Map<String, Depot> depots) async {
    final ordonnes = depots.values.toList()
      ..sort((a, b) => a.prisLe.compareTo(b.prisLe));
    final texte = jsonEncode([for (final d in ordonnes) d.versJson()]);
    await dossier.create(recursive: true);
    await _provisoire.writeAsString(texte, flush: true);
    // ⚠️ `flush: true` ci-dessus, et le renommage ici. Sans le vidage, le
    // renommage peut précéder l'écriture réelle des octets, et l'on renomme un
    // fichier vide par-dessus une file pleine.
    await _provisoire.rename(_fichier.path);
  }

  @override
  Future<List<Depot>> tous() async {
    final depots = await _charger();
    return depots.values.toList()..sort((a, b) => a.prisLe.compareTo(b.prisLe));
  }

  @override
  Future<void> ranger(Depot depot) async {
    final depots = await _charger();
    depots[depot.identifiant] = depot;
    await _ecrire(depots);
  }

  @override
  Future<void> oublier(String identifiant) async {
    final depots = await _charger();
    depots.remove(identifiant);
    await _ecrire(depots);
  }
}
