import 'depot.dart';
import '../ports/magasin.dart';

/// Ce que le serveur répond à une tentative de remise.
enum Reponse {
  /// Reçu. Le dépôt sort de la file.
  accepte,

  /// Refusé pour une raison qui ne changera pas : pièce illisible, dossier
  /// inconnu, mois déjà clos. ⚠️ Ne jamais réessayer : la file tournerait
  /// indéfiniment contre un serveur qui dira toujours non, en vidant la batterie
  /// et le forfait de l'adhérent.
  refuse,

  /// Rien n'a abouti : pas de réseau, serveur injoignable, délai dépassé. On
  /// réessaiera.
  indisponible,
}

/// La file des dépôts qui attendent leur tour.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// LES TROIS RÈGLES, ET CE QUI ARRIVE QUAND ON LES OUBLIE
///
/// 1. **L'ordre est celui de la prise de vue.** Une file qui part dans le
///    désordre fait arriver la facture du 3 après celle du 17, et le
///    collaborateur qui suit le dossier voit une chronologie fausse.
///
/// 2. **Un refus sort de la file, une indisponibilité y reste.** Confondre les
///    deux donne l'un des deux pires défauts possibles : soit une pièce valable
///    jetée parce que le réseau a manqué, soit une file qui ne se vide jamais.
///
/// 3. **La remise est idempotente**, par l'identifiant posé sur l'appareil. Une
///    réponse perdue en route fait rejouer l'envoi ; sans identifiant stable, la
///    même facture entrerait deux fois dans la comptabilité.
/// ─────────────────────────────────────────────────────────────────────────────
class FileDAttente {
  FileDAttente(this._magasin);

  final MagasinDeDepots _magasin;

  /// ⚠️ Au-delà, on cesse d'essayer tout seul et on le montre à l'adhérent.
  ///
  /// Une file qui réessaie sans fin sur un appareil hors réseau vide la batterie
  /// en une nuit, et l'adhérent ne comprend ni pourquoi ni depuis quand. Six
  /// tentatives espacées couvrent une coupure de plusieurs heures ; au-delà, ce
  /// n'est plus une coupure, c'est quelque chose qui demande un geste.
  static const int tentativesMaximales = 6;

  /// Ajoute un dépôt à la file.
  Future<void> ajouter(Depot depot) => _magasin.ranger(depot);

  /// Ce qui attend de partir, dans l'ordre de la prise de vue.
  Future<List<Depot>> enAttente() async {
    final tous = await _magasin.tous();
    return tous.where((d) => d.etat == EtatDuDepot.enAttente).toList();
  }

  /// Ce que l'adhérent doit reprendre lui-même.
  Future<List<Depot>> refuses() async {
    final tous = await _magasin.tous();
    return tous.where((d) => d.etat == EtatDuDepot.refuse).toList();
  }

  /// Tente de vider la file, en s'arrêtant à la première indisponibilité.
  ///
  /// ⚠️ **S'arrêter et non continuer.** Si le réseau manque pour le premier, il
  /// manque pour les suivants : insister ferait vingt tentatives inutiles et
  /// perdrait l'ordre de remise. On rend la main, le prochain réveil reprendra
  /// au même endroit.
  ///
  /// Rend le nombre de dépôts effectivement remis.
  Future<int> vider(Future<Reponse> Function(Depot) remettre) async {
    var remis = 0;
    for (final depot in await enAttente()) {
      if (depot.tentatives >= tentativesMaximales) {
        continue;
      }
      final reponse = await remettre(depot);
      switch (reponse) {
        case Reponse.accepte:
          await _magasin.oublier(depot.identifiant);
          remis++;
        case Reponse.refuse:
          await _magasin.ranger(depot.avec(etat: EtatDuDepot.refuse));
        case Reponse.indisponible:
          await _magasin.ranger(depot.avec(tentatives: depot.tentatives + 1));
          return remis;
      }
    }
    return remis;
  }
}
