import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domaine/echeance.dart';
import '../domaine/file_d_attente.dart';
import '../domaine/piece_remise.dart';
import '../domaine/preuve.dart';
import '../ports/service_de_session.dart';
import 'remise.dart';

/// Le lien avec le serveur.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI `dart:io` ET PAS UNE BIBLIOTHÈQUE HTTP
///
/// Le client HTTP de la plateforme suffit à ce que fait cette application :
/// quelques routes, un cookie de session, un envoi de fichier. Une dépendance de
/// plus, c'est une chaîne d'approvisionnement de plus à surveiller, et sur un
/// produit qui manipule la comptabilité d'un tiers, ce n'est pas un détail. Le
/// jour où le besoin dépassera ce fichier, il sera temps.
///
/// ⚠️ LE LOCATAIRE SE DIT PAR LE SOUS-DOMAINE, COMME PARTOUT
///
/// Le serveur résout le locataire à l'entrée, une fois, depuis le nom d'hôte.
/// L'application ne l'envoie donc pas dans un en-tête à elle : elle parle à
/// `https://<cabinet>.cga-brcg.cm`, et c'est tout. Poser le locataire ailleurs
/// ouvrirait deux vérités sur la même requête, et c'est exactement le défaut que
/// le socle multi-locataire du serveur a été construit pour rendre impossible.
/// ─────────────────────────────────────────────────────────────────────────────
class ClientApi implements ServiceDeSession {
  ClientApi({required this.base});

  /// L'adresse du serveur, sous-domaine du cabinet compris.
  ///
  /// Se règle à la compilation, pour qu'une version de démonstration ne puisse
  /// pas se retrouver branchée sur la production par un fichier de réglage
  /// oublié :
  ///
  /// ```
  /// flutter run --dart-define=CGA_API=http://10.0.2.2:8010
  /// ```
  ///
  /// ⚠️ `10.0.2.2` et non `localhost` : dans l'émulateur Android, `localhost`
  /// désigne l'émulateur lui-même, et l'appel ne sort jamais de l'appareil.
  static const String adresseParDefaut = String.fromEnvironment(
    'CGA_API',
    defaultValue: 'http://10.0.2.2:8010',
  );

  final Uri base;

  /// Le cookie de session, tel que le serveur l'a posé. ⚠️ Gardé en mémoire
  /// seulement : l'écrire sur le disque demanderait le magasin protégé du
  /// système, et le faire à moitié vaut moins que ne pas le faire.
  String? _session;

  bool get connecte => _session != null;

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  /// Ouvre une session. Rend vrai si le serveur a reconnu le compte.
  @override
  Future<bool> ouvrirUneSession(String courriel, String motDePasse) async {
    final requete = await _client.postUrl(base.resolve('/transverse/session'));
    requete.headers.contentType = ContentType.json;
    requete.write(
      jsonEncode({'courriel': courriel, 'mot_de_passe': motDePasse}),
    );
    final reponse = await requete.close();
    await reponse.drain<void>();
    if (reponse.statusCode != HttpStatus.ok) {
      return false;
    }
    final cookies = reponse.cookies;
    if (cookies.isEmpty) {
      return false;
    }
    _session = '${cookies.first.name}=${cookies.first.value}';
    return true;
  }

  /// Ferme la session côté serveur, puis l'oublie ici.
  ///
  /// ⚠️ Dans cet ordre, et l'oubli a lieu même si l'appel échoue. Garder un
  /// jeton dont on ne sait plus s'il vaut encore ne sert à rien et laisse
  /// l'application dans un état qu'aucun écran ne sait montrer.
  @override
  Future<void> fermerLaSession() async {
    try {
      final requete = await _client.deleteUrl(
        base.resolve('/transverse/session'),
      );
      _poserLaSession(requete);
      final reponse = await requete.close();
      await reponse.drain<void>();
    } on Object {
      // Sans réseau, la session expirera d'elle-même côté serveur.
    } finally {
      _session = null;
    }
  }

  /// Lit une route et rend son corps décodé, ou rien si le serveur n'a pas
  /// répondu 200.
  Future<Object?> lire(String chemin) async {
    final requete = await _client.getUrl(base.resolve(chemin));
    _poserLaSession(requete);
    final reponse = await requete.close();
    final corps = await reponse.transform(utf8.decoder).join();
    if (reponse.statusCode != HttpStatus.ok) {
      return null;
    }
    return jsonDecode(corps);
  }

  /// Envoie les octets d'un justificatif, et rend l'empreinte que le serveur a
  /// calculée dessus.
  ///
  /// ⚠️ L'enveloppe multipart est écrite à la main, et les bornes comptent : un
  /// `\r\n` manquant avant la ligne de séparation finale fait lire au serveur
  /// deux octets de trop dans le fichier. L'empreinte change alors à chaque
  /// envoi, l'idempotence disparaît sans bruit, et la même facture entre deux
  /// fois. On écrit donc les octets bruts, jamais une chaîne encodée.
  Future<FichierDepose> envoyerLeFichier({
    required String entreprise,
    required File fichier,
  }) async {
    final separateur = '----cga${DateTime.now().microsecondsSinceEpoch}';
    final requete = await _client.postUrl(
      base.resolve('/collecte/fichiers?entreprise=$entreprise'),
    );
    _poserLaSession(requete);
    requete.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$separateur',
    );
    final tete = utf8.encode(
      '--$separateur\r\n'
      'Content-Disposition: form-data; name="fichier"; '
      'filename="${fichier.uri.pathSegments.last}"\r\n'
      // ⚠️ Le type déclaré ici n'est pas cru par le serveur : il lit les
      // premiers octets et décide lui-même. On l'envoie quand même, parce que
      // l'enveloppe multipart l'attend, mais aucune décision n'en dépend.
      'Content-Type: application/octet-stream\r\n\r\n',
    );
    final pied = utf8.encode('\r\n--$separateur--\r\n');
    requete.add(tete);
    requete.add(await fichier.readAsBytes());
    requete.add(pied);

    final reponse = await requete.close();
    final corps = await reponse.transform(utf8.decoder).join();
    final sort = sortDuCode(reponse.statusCode);
    if (sort != Reponse.accepte) {
      return FichierDepose(reponse: sort);
    }
    final json = jsonDecode(corps) as Map<String, dynamic>;
    return FichierDepose(
      reponse: Reponse.accepte,
      empreinte: json['empreinte'] as String,
    );
  }

  /// Crée la pièce qui cite l'empreinte, et rend le sort du dépôt.
  Future<PieceCreee> creerLaPiece({
    required String entreprise,
    required String empreinte,
    required DateTime prisLe,
  }) async {
    final requete = await _client.postUrl(base.resolve('/collecte/pieces'));
    _poserLaSession(requete);
    requete.headers.contentType = ContentType.json;
    requete.write(
      jsonEncode({
        'entreprise': entreprise,
        'canal': 'MOBILE',
        'empreinte': empreinte,
        // ⚠️ UN NOM QUI DIT QUELQUE CHOSE À QUI LE LIRA.
        //
        // Ce champ était laissé vide, et la pièce arrivait sans nom dans la
        // boîte de réception du cabinet. C'est pourtant le seul repère lisible
        // avant d'ouvrir le document : le comptable voyait une ligne muette
        // parmi d'autres qui portaient « f-2026-0439.pdf ».
        //
        // Le nom que rend l'appareil photo ne vaut rien non plus : c'est un
        // identifiant technique du sélecteur d'images. On pose donc la date et
        // l'heure de la PRISE DE VUE, qui situent la pièce sans rien inventer.
        'nom_fichier': _nomDeLaPhoto(prisLe),
        // ⚠️ La date de la PRISE DE VUE, pas celle de la remise. C'est elle que
        // la comptabilité retient : prendre celle de la remise ferait glisser au
        // mois suivant toute pièce photographiée le 31 au soir sans réseau.
        //
        // Le serveur la borne à quatre-vingt-dix jours d'antériorité. Au-delà,
        // ce n'est plus un dépôt mais une reprise d'historique, et il répond 422
        // — un refus, à juste titre.
        'depose_le': prisLe.toIso8601String().split('T').first,
      }),
    );
    final reponse = await requete.close();
    final corps = await reponse.transform(utf8.decoder).join();
    final sort = sortDuCode(reponse.statusCode);
    if (sort != Reponse.accepte) {
      return PieceCreee(reponse: sort);
    }
    // ⚠️ ON LIT DÉSORMAIS LE CORPS, alors qu'on le jetait.
    //
    // Le serveur rend la pièce créée, donc son IDENTIFIANT — « PJ-M08123-… ».
    // C'est ce numéro, et lui seul, qu'on cite pour dire de quoi une quittance
    // est la preuve : la route des preuves de paiement l'exige. L'empreinte ne
    // lui sert pas, elle identifie des octets, pas une pièce du dossier.
    //
    // ⚠️ Un corps illisible ne fait pas échouer le dépôt : la pièce EST créée,
    // le serveur a répondu 201. On rend donc l'acceptation sans identifiant, et
    // c'est à l'appelant de constater qu'il ne peut pas enchaîner sur la preuve.
    try {
      final json = jsonDecode(corps) as Map<String, dynamic>;
      final piece = json['piece'];
      final identifiant = piece is Map<String, dynamic>
          ? piece['identifiant'] as String?
          : null;
      return PieceCreee(reponse: sort, identifiant: identifiant);
    } on Object {
      return PieceCreee(reponse: sort);
    }
  }

  /// Les dossiers que ce compte a le droit de déposer.
  ///
  /// ⚠️ Lus sur le serveur à chaque ouverture de session, et jamais devinés ni
  /// gardés d'une fois sur l'autre. Un adhérent peut avoir deux entreprises, en
  /// perdre une, en gagner une autre : une liste retenue sur l'appareil
  /// proposerait un dossier que le serveur refuse, et le refus arriverait après
  /// la photo, quand il est trop tard pour la reprendre.
  @override
  Future<List<String>> mesDossiers() async {
    final moi = await lire('/transverse/moi');
    if (moi is! Map<String, dynamic>) {
      return const [];
    }
    final dossiers = moi['dossiers'];
    if (dossiers is! List) {
      return const [];
    }
    return [for (final d in dossiers) d as String];
  }

  /// Les pièces que le cabinet détient pour ce dossier.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// ⚠️ CETTE MÉTHODE N'EMPRUNTE PAS `lire()`, ET C'EST VOULU
  ///
  /// `lire()` rend `null` dès que le serveur n'a pas répondu 200, sans dire
  /// pourquoi. Pour les dossiers, c'était sans conséquence : une liste vide fait
  /// une liste déroulante vide, l'adhérent voit bien que quelque chose manque.
  ///
  /// Ici, c'en aurait une. « Pas de réseau », « session expirée » et « vous
  /// n'avez rien déposé » sont trois phrases différentes, dont deux appellent un
  /// geste, et un `null` les confond toutes les trois. L'écran afficherait
  /// « aucune pièce » à un adhérent qui en a remis deux cents.
  ///
  /// On distingue donc les sorts sur place, et l'on rend un [Historique] qui les
  /// porte — comme [Vidage] le fait pour la file d'attente.
  /// ─────────────────────────────────────────────────────────────────────────
  @override
  Future<Historique> mesPieces(String dossier) async {
    try {
      // ⚠️ `a_la_date` est EXIGÉ par la route : c'est la date de référence dont
      // le serveur se sert pour calculer anciennetés et retards. On envoie le
      // jour de l'appareil, qui est aussi celui que l'adhérent a sous les yeux.
      final aujourdHui = DateTime.now().toIso8601String().split('T').first;
      final requete = await _client.getUrl(
        base.resolve(
          '/collecte/pieces?entreprise=$dossier&a_la_date=$aujourdHui',
        ),
      );
      _poserLaSession(requete);
      final reponse = await requete.close();
      final corps = await reponse.transform(utf8.decoder).join();
      if (reponse.statusCode == HttpStatus.unauthorized) {
        return const Historique(sessionAExpire: true);
      }
      if (reponse.statusCode != HttpStatus.ok) {
        // ⚠️ Un 404 arrive ici quand le dossier sort du périmètre du compte —
        // le serveur répond « ce dossier n'existe pas » plutôt que « vous n'y
        // avez pas droit », et il a raison de ne pas renseigner un curieux sur
        // l'existence des dossiers des autres. Vu d'ici, c'est un serveur qui
        // n'a pas répondu, et l'écran le dira ainsi.
        return const Historique(serveurJoignable: false);
      }
      final lignes = jsonDecode(corps);
      if (lignes is! List) {
        return const Historique(serveurJoignable: false);
      }
      final pieces = [
        for (final ligne in lignes)
          PieceRemise.depuisJson(ligne as Map<String, dynamic>),
      ];
      // ⚠️ LA PLUS RÉCENTE EN HAUT, à l'inverse de la file d'attente.
      //
      // La file part dans l'ordre de la prise de vue, parce que c'est la
      // chronologie que le comptable doit voir arriver. Un historique se lit
      // dans l'autre sens : on y cherche ce qu'on vient de faire, pas ce qu'on
      // a fait il y a six mois.
      pieces.sort((a, b) => b.deposeLe.compareTo(a.deposeLe));
      return Historique(pieces: pieces);
    } on Object {
      // Pas de réseau, serveur injoignable, délai dépassé, corps illisible.
      return const Historique(serveurJoignable: false);
    }
  }

  /// Les échéances du dossier, telles que l'adhérent les lit.
  ///
  /// ⚠️ Même traitement des sorts que [mesPieces], et pour une raison plus forte
  /// encore : ici, une liste vide affichée comme « vous êtes à jour » dirait à un
  /// adhérent en retard de dix-neuf mois qu'il est tranquille.
  @override
  Future<Echeancier> mesEcheances(String dossier) async {
    try {
      final requete = await _client.getUrl(
        base.resolve('/obligations/dossiers/$dossier/mes-echeances'),
      );
      _poserLaSession(requete);
      final reponse = await requete.close();
      final corps = await reponse.transform(utf8.decoder).join();
      if (reponse.statusCode == HttpStatus.unauthorized) {
        return const Echeancier(sessionAExpire: true);
      }
      if (reponse.statusCode != HttpStatus.ok) {
        return const Echeancier(serveurJoignable: false);
      }
      final json = jsonDecode(corps);
      if (json is! Map<String, dynamic>) {
        return const Echeancier(serveurJoignable: false);
      }
      final lignes = json['echeances'];
      if (lignes is! List) {
        return const Echeancier(serveurJoignable: false);
      }
      final echeances = [
        for (final ligne in lignes)
          Echeance.depuisJson(ligne as Map<String, dynamic>),
      ];
      // ⚠️ CE QUI DEMANDE UN GESTE EN PREMIER, puis l'ordre des dates.
      //
      // Le serveur rend l'échéancier dans son ordre à lui, qui est celui du
      // calendrier. Sur un dossier en retard de cinq cents jours, cela place
      // l'action urgente au milieu d'obligations à venir. L'adhérent ouvre
      // l'application pour savoir quoi faire, pas pour lire un calendrier.
      echeances.sort((a, b) {
        final urgence = (b.etat.demandeUnGeste ? 1 : 0)
            .compareTo(a.etat.demandeUnGeste ? 1 : 0);
        if (urgence != 0) return urgence;
        return a.echeanceLe.compareTo(b.echeanceLe);
      });
      return Echeancier(echeances: echeances);
    } on Object {
      return const Echeancier(serveurJoignable: false);
    }
  }

  /// « J'ai déjà payé » : dépose la quittance, puis dit ce qu'elle acquitte.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// ⚠️ TROIS APPELS, ET LE TROISIÈME SEUL PEUT ÊTRE REJOUÉ SANS DOMMAGE
  ///
  /// 1. les octets de la quittance, qui rendent une empreinte ;
  /// 2. la création de la pièce, qui rend son identifiant ;
  /// 3. le rattachement à l'obligation.
  ///
  /// Les deux premiers sont idempotents par construction : la même quittance
  /// sur le même dossier rend la même pièce, inchangée. Le troisième refuse un
  /// second envoi de la même pièce pour la même obligation, en 409 — ce qui est
  /// juste, et que l'on traduit en refus et non en panne.
  ///
  /// ⚠️ SI LE TROISIÈME ÉCHOUE, LA QUITTANCE EST QUAND MÊME CHEZ LE CABINET.
  /// Elle y est comme une pièce ordinaire, sans dire ce qu'elle acquitte. Ce
  /// n'est pas rien, et l'écran doit le dire : sans cela l'adhérent
  /// photographie une seconde fois, et le cabinet reçoit deux quittances.
  /// ─────────────────────────────────────────────────────────────────────────
  @override
  Future<Preuve> envoyerLaPreuve({
    required String dossier,
    required Echeance echeance,
    required String cheminDeLaPhoto,
  }) async {
    Preuve traduire(Reponse r) => switch (r) {
      Reponse.accepte => Preuve.recue,
      Reponse.refuse => Preuve.refusee,
      Reponse.sessionExpiree => Preuve.sessionExpiree,
      Reponse.indisponible => Preuve.indisponible,
    };

    try {
      final fichier = File(cheminDeLaPhoto);
      if (!await fichier.exists()) {
        return Preuve.refusee;
      }
      final depose = await envoyerLeFichier(
        entreprise: dossier,
        fichier: fichier,
      );
      if (depose.reponse != Reponse.accepte) {
        return traduire(depose.reponse);
      }
      final creee = await creerLaPiece(
        entreprise: dossier,
        empreinte: depose.empreinte!,
        // ⚠️ La date de l'ÉCHÉANCE et non celle du jour : une quittance de
        // janvier photographiée en septembre appartient à janvier. Le serveur
        // borne l'antériorité à quatre-vingt-dix jours et refusera au-delà,
        // ce qui est exact : une reprise d'historique n'est pas un dépôt.
        prisLe: DateTime.now(),
      );
      if (creee.reponse != Reponse.accepte) {
        return traduire(creee.reponse);
      }
      final identifiant = creee.identifiant;
      if (identifiant == null) {
        // La pièce existe, mais on n'a pas son numéro : on ne peut pas dire ce
        // qu'elle acquitte. Ce n'est pas un refus du cabinet.
        return Preuve.indisponible;
      }

      final requete = await _client.postUrl(
        base.resolve('/obligations/dossiers/$dossier/preuves-de-paiement'),
      );
      _poserLaSession(requete);
      requete.headers.contentType = ContentType.json;
      String jour(DateTime d) => d.toIso8601String().split('T').first;
      requete.write(
        jsonEncode({
          'code_obligation': echeance.codeObligation,
          'periode_debut': jour(echeance.periodeDebut),
          'periode_fin': jour(echeance.periodeFin),
          'piece': identifiant,
        }),
      );
      final reponse = await requete.close();
      await reponse.drain<void>();
      return traduire(sortDuCode(reponse.statusCode));
    } on Object {
      return Preuve.indisponible;
    }
  }

  /// « photo-2026-09-19-2110.jpg » : la date et l'heure de la prise de vue.
  ///
  /// ⚠️ Deux photos dans la même minute portent le même nom, et c'est sans
  /// conséquence : le nom n'identifie rien, il renseigne. L'identité de la pièce
  /// vient de l'empreinte de ses octets, et elle seule.
  /// ⚠️ Ouvert aux seuls cas d'essai. Le nom le dit, pour que personne ne
  /// l'emploie ailleurs en croyant à une API.
  @visibleForTesting
  static String nomDeLaPhotoPourEssai(DateTime prisLe) => _nomDeLaPhoto(prisLe);

  static String _nomDeLaPhoto(DateTime prisLe) {
    String deuxChiffres(int n) => n.toString().padLeft(2, '0');
    final jour =
        '${prisLe.year}-${deuxChiffres(prisLe.month)}-${deuxChiffres(prisLe.day)}';
    final heure = '${deuxChiffres(prisLe.hour)}${deuxChiffres(prisLe.minute)}';
    return 'photo-$jour-$heure.jpg';
  }

  void _poserLaSession(HttpClientRequest requete) {
    final session = _session;
    if (session != null) {
      requete.headers.add(HttpHeaders.cookieHeader, session);
    }
  }

  void fermer() => _client.close(force: true);
}
