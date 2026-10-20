import 'dart:io';

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

  /// Au-delà, l'écran dit que la pièce « n'arrive pas à partir ».
  ///
  /// ⚠️ 19 OCTOBRE 2026 : C'ÉTAIT UN ARRÊT DÉFINITIF, ET IL TOMBAIT EN TROIS MINUTES.
  /// Le minuteur réessaie toutes les 30 s : six essais manqués sans réseau, et la
  /// pièce ne repartait plus jamais, alors que l'écran promettait « elles repartent
  /// toutes seules ». « Envoyer maintenant » la sautait aussi. La file ne renonce
  /// plus : elle espace ses essais ([attenteApres]), ce qui ménage la batterie
  /// sans perdre la pièce.
  static const int tentativesMaximales = 6;

  /// Combien attendre après [tentatives] essais manqués : 30 s, 2 min, 10 min,
  /// 30 min, puis une heure. Le réseau d'un chantier revient rarement en dix
  /// secondes, et souvent dans l'heure.
  static Duration attenteApres(int tentatives) => switch (tentatives) {
    <= 0 => Duration.zero,
    1 => const Duration(seconds: 30),
    2 => const Duration(minutes: 2),
    3 => const Duration(minutes: 10),
    4 => const Duration(minutes: 30),
    _ => const Duration(hours: 1),
  };

  /// Ajoute un dépôt à la file.
  Future<void> ajouter(Depot depot) => _magasin.ranger(depot);

  /// Retire un dépôt de la file, ET efface sa copie sur le téléphone (20 octobre
  /// 2026).
  ///
  /// ⚠️ LE SEUL MOYEN DE SE DÉDIRE. Une photo prise de travers, la mauvaise facture,
  /// un doublon : la file la gardait jusqu'à ce que le serveur la prenne ou la
  /// refuse, et l'adhérent la voyait partir sans pouvoir l'arrêter. L'écran
  /// demande confirmation ; ici, on retire.
  ///
  /// ⚠️ La copie part avec : laissée sur le disque, elle attendrait le prochain
  /// ménage de `PriseDeVue`, et une photo qu'on vient de retirer doit disparaître
  /// tout de suite. Une copie déjà absente n'est pas une erreur.
  Future<void> retirer(String identifiant) async {
    final depot = (await _magasin.tous())
        .where((d) => d.identifiant == identifiant)
        .firstOrNull;
    await _magasin.oublier(identifiant);
    if (depot == null) return;
    try {
      await File(depot.cheminDuFichier).delete();
    } on Object {
      // Déjà partie : rien à faire.
    }
  }

  /// Ce qui attend de partir, dans l'ordre de la prise de vue.
  Future<List<Depot>> enAttente() async {
    final tous = await _magasin.tous();
    return tous.where((d) => d.etat == EtatDuDepot.enAttente).toList();
  }

  /// Tout ce que la file connaît, quel que soit l'état.
  ///
  /// ⚠️ Sert à savoir quelles copies de photos sont encore utiles. Se fonder sur
  /// la seule attente effacerait les pièces refusées, que l'adhérent doit
  /// pouvoir regarder.
  Future<List<Depot>> tous() => _magasin.tous();

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
  /// [forcer] : l'adhérent a appuyé sur « Envoyer maintenant », ou l'application
  /// revient au premier plan. On essaie sans attendre la fin de l'espacement.
  Future<Vidage> vider(
    Future<Reponse> Function(Depot) remettre, {
    bool forcer = false,
    DateTime? maintenant,
  }) async {
    final instant = maintenant ?? DateTime.now();
    var remis = 0;
    for (final depot in await enAttente()) {
      final dernier = depot.dernierEssaiLe;
      if (!forcer &&
          dernier != null &&
          instant.isBefore(dernier.add(attenteApres(depot.tentatives)))) {
        // ⚠️ S'arrêter, et non sauter au suivant : l'ordre de remise compte, et
        // le réseau qui manquait pour celui-ci manque pour les autres.
        return Vidage(remis: remis);
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
          await _magasin.ranger(
            depot.avec(
              tentatives: depot.tentatives + 1,
              dernierEssaiLe: instant,
            ),
          );
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
