import 'depot.dart';
import '../ports/magasin.dart';

/// Ce que le serveur répond à une tentative de remise.
enum Reponse {
  /// Reçu. Le dépôt sort de la file.
  accepte,

  /// Refusé pour une raison qui ne changera pas : type de document non accepté,
  /// fichier trop volumineux, doublon certain, dossier hors périmètre.
  /// ⚠️ Ne jamais réessayer : la file tournerait indéfiniment contre un serveur
  /// qui dira toujours non, en vidant la batterie et le forfait de l'adhérent.
  refuse,

  /// La session n'est plus valable : il faut se reconnecter.
  ///
  /// ⚠️ **CE CAS MANQUAIT, ET SON ABSENCE COÛTAIT LA FILE ENTIÈRE.**
  ///
  /// Une session expire. Sans ce troisième cas, un 401 tombait dans « refusé »,
  /// faute de mieux : chaque dépôt en attente était marqué « à reprendre », et
  /// l'adhérent qui avait simplement laissé l'application quelques jours
  /// retrouvait au retour toutes ses pièces déclarées irrécupérables. Rien
  /// n'était pourtant refusé : personne n'avait demandé.
  ///
  /// Le dépôt reste donc en attente, **sans compter de tentative**, et la file
  /// s'arrête pour que l'écran puisse demander de se reconnecter.
  sessionExpiree,

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
  Future<Vidage> vider(Future<Reponse> Function(Depot) remettre) async {
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
        case Reponse.sessionExpiree:
          // ⚠️ AUCUNE TENTATIVE COMPTÉE, et le dépôt reste en attente.
          //
          // Compter une tentative ici ferait franchir le garde-fou des six
          // essais à un adhérent qui n'a rien fait de mal : six ouvertures de
          // l'application avec une session périmée, et ses pièces cessaient
          // d'être envoyées sans que rien ne le dise. Une session expirée n'est
          // pas un échec du dépôt, c'est un échec de la demande.
          return Vidage(remis: remis, sessionAExpire: true);
        case Reponse.indisponible:
          await _magasin.ranger(depot.avec(tentatives: depot.tentatives + 1));
          return Vidage(remis: remis);
      }
    }
    return Vidage(remis: remis);
  }
}

/// Ce qu'une tentative de vidage a produit.
///
/// ⚠️ Le compte de remises ne suffisait pas. « Zéro remis » se lit aussi bien
/// comme « rien n'attendait » que comme « la session a expiré », et l'écran ne
/// pouvait donc pas savoir s'il devait demander de se reconnecter. Une réponse
/// qui force son lecteur à deviner est une réponse incomplète.
class Vidage {
  const Vidage({required this.remis, this.sessionAExpire = false});

  /// Combien de dépôts sont réellement partis.
  final int remis;

  /// Vrai quand la file s'est arrêtée parce qu'il faut se reconnecter.
  final bool sessionAExpire;
}
