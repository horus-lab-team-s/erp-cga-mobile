/// L'offre du cabinet, telle qu'un visiteur la voit AVANT de se connecter.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI L'APPLICATION A UN CÔTÉ PUBLIC
///
/// Elle n'en avait pas : elle s'ouvrait sur un mur de connexion. Or le compte
/// **naît de la souscription réglée** — le cabinet envoie le lien d'accès une
/// fois le paiement validé. Exiger un compte pour voir l'offre demandait donc
/// d'avoir déjà acheté pour savoir ce qu'on achète.
///
/// Le serveur, lui, avait tout prévu : le catalogue, le devis, le paiement
/// mobile et le suivi sont **publics**, sans session. C'est l'application qui
/// les ignorait.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// Un prix, et la période pendant laquelle il s'applique.
class Tarif {
  const Tarif({
    required this.montant,
    required this.du,
    this.au,
    this.motif,
    this.fixe = false,
  });

  /// ⚠️ NULLABLE, ET C'EST LE CŒUR DE LA CORRECTION.
  ///
  /// Le référentiel porte des tarifs **sans montant** : le régime du réel, la
  /// création d'entreprise, la prestation ponctuelle. Le prix y dépend du
  /// dossier, et le cabinet l'établit après examen.
  ///
  /// On lisait `double.tryParse('null') ?? 0`, donc **zéro**. Et comme zéro est
  /// le plus petit des nombres, il gagnait le classement du prix d'entrée :
  /// l'écran annonçait « dès 0 F par mois » pour l'adhésion, et « 0 F une
  /// fois » pour la création d'entreprise. Un prix inventé, affiché à un
  /// prospect, sur un écran qui engage le cabinet.
  ///
  /// Absent veut dire **sur étude**, jamais gratuit.
  final double? montant;
  final DateTime du;

  /// `null` : c'est le tarif en vigueur, sans échéance connue.
  final DateTime? au;

  /// ⚠️ RENSEIGNÉ QUAND LE TARIF N'EST PAS UNE VALEUR VALIDÉE.
  ///
  /// Le référentiel porte des tarifs « reconstitués », faute de barème
  /// contresigné pour la période. L'afficher n'est pas une coquetterie : un
  /// prix annoncé au client engage le cabinet, et celui qui le lit doit savoir
  /// s'il repose sur un document ou sur une reconstitution.
  final String? motif;

  /// ⚠️ VRAI SEULEMENT SI LE GÉRANT A ARRÊTÉ CE PRIX.
  ///
  /// Le prix est une décision humaine. Tant que la direction du cabinet ne l'a
  /// pas fixé, le montant vient du catalogue de démonstration : il s'affiche
  /// comme INDICATIF et ne se paie pas en ligne — le serveur refuse le
  /// paiement. Faux par défaut : un tarif dont on ne sait rien n'est pas fixé.
  final bool fixe;

  bool sApplique(DateTime le) =>
      !le.isBefore(du) && (au == null || le.isBefore(au!));

  static Tarif depuisJson(Map<String, dynamic> j) => Tarif(
    // ⚠️ Pas de `?? 0` : voir le commentaire du champ. Le serveur envoie le
    // montant en CHAÎNE (« 12500 »), et `null` quand il n'y en a pas.
    montant: j['montant'] == null ? null : double.tryParse('${j['montant']}'),
    du: DateTime.parse(j['du'] as String),
    au: j['au'] == null ? null : DateTime.parse(j['au'] as String),
    motif: j['motif'] as String?,
    fixe: j['statut'] == 'FIXE',
  );
}

/// Choisit le tarif en vigueur à une date. ⚠️ Rend `null` plutôt qu'un prix
/// approchant : afficher le tarif d'une autre période serait annoncer un prix
/// que le cabinet ne pratique pas.
Tarif? tarifApplicable(List<Tarif> tarifs, DateTime le) {
  for (final t in tarifs) {
    if (t.sApplique(le)) return t;
  }
  return null;
}

/// Une tranche de chiffre d'affaires, avec son prix.
class Formule {
  const Formule({
    required this.code,
    required this.libelle,
    required this.tarifs,
    required this.inclus,
    this.plancher,
    this.plafond,
  });

  final String code;
  final String libelle;

  /// Les bornes de chiffre d'affaires. ⚠️ C'est le CA déclaré qui décide de la
  /// formule, pas le client : le serveur la déduit quand elle n'est pas donnée.
  final double? plancher;
  final double? plafond;

  final List<Tarif> tarifs;
  final List<String> inclus;

  /// Le tarif de la tranche à une date, ou `null` si elle est sur étude.
  ///
  /// ⚠️ « Sur étude » et « pas de tarif pour cette période » sont deux choses
  /// différentes, et l'écran les dit différemment. Ici les deux rendent `null`
  /// parce que dans les deux cas **on n'a pas de prix à annoncer**.
  Tarif? prixLe(DateTime le) {
    final t = tarifApplicable(tarifs, le);
    return t == null || t.montant == null ? null : t;
  }

  /// « jusqu'à 50 M », « de 50 à 100 M », « au-delà de 100 M ».
  ///
  /// ⚠️ C'est ce qui permet au commerçant de se reconnaître. Une tranche sans
  /// ses bornes ne lui dit pas laquelle est la sienne, et il faudrait
  /// téléphoner au cabinet pour le savoir.
  String get bornes {
    final bas = plancher == null || plancher == 0 ? null : _millions(plancher!);
    final haut = plafond == null ? null : _millions(plafond!);
    if (bas == null && haut == null) return '';
    if (bas == null) return 'CA jusqu\u2019à $haut';
    if (haut == null) return 'CA au-delà de $bas';
    return 'CA de $bas à $haut';
  }

  /// 50000000 → « 50 M ». ⚠️ Les chiffres d'affaires du référentiel sont en
  /// dizaines de millions : les écrire en entier occuperait la moitié de la
  /// largeur d'un téléphone pour une information qu'on lit de travers.
  static String _millions(double v) {
    if (v >= 1000000) {
      final m = v / 1000000;
      return '${m == m.roundToDouble() ? m.round() : m.toStringAsFixed(1)} M';
    }
    return v.round().toString();
  }

  static double? _nombre(Object? v) => v == null ? null : double.tryParse('$v');

  static Formule depuisJson(Map<String, dynamic> j) => Formule(
    code: j['code'] as String,
    libelle: j['libelle'] as String? ?? '',
    plancher: _nombre(j['plancher']),
    plafond: _nombre(j['plafond']),
    tarifs: [
      for (final t in (j['tarifs'] as List? ?? const []))
        Tarif.depuisJson(t as Map<String, dynamic>),
    ],
    inclus: [for (final i in (j['inclus'] as List? ?? const [])) '$i'],
  );
}

/// Une prestation du catalogue.
class Service {
  const Service({
    required this.code,
    required this.libelle,
    required this.nature,
    required this.periodicite,
    required this.tarifs,
    required this.formules,
    required this.inclus,
    required this.ouvreUnDossier,
    required this.souscriptibleEnLigne,
    this.unite,
    this.resume,
  });

  final String code;
  final String libelle;

  /// `ABONNEMENT` ou prestation unique.
  final String nature;

  /// `MENSUELLE`, `ANNUELLE`, `UNIQUE`.
  final String periodicite;

  /// Les tarifs du service quand il n'a pas de formule.
  final List<Tarif> tarifs;

  /// Les tranches, pour les services qui en ont. ⚠️ Vide n'est pas « pas de
  /// prix » : c'est « un seul prix », et il est dans [tarifs].
  final List<Formule> formules;

  final List<String> inclus;

  /// Vrai quand souscrire ouvre un dossier au cabinet, donc un accès.
  final bool ouvreUnDossier;

  /// ⚠️ FAUX VEUT DIRE « SUR ÉTUDE », ET L'ÉCRAN NE DOIT PAS PROPOSER DE PAYER.
  ///
  /// La création d'entreprise et les prestations ponctuelles ne se souscrivent
  /// pas en ligne : le cabinet examine le dossier puis adresse une proposition.
  /// Afficher un bouton « souscrire » dessus promettrait ce que le serveur
  /// refuse — il rend 422 sur une prestation non souscriptible.
  final bool souscriptibleEnLigne;

  final String? unite;
  final String? resume;

  /// Ce que le prix couvre, en toutes lettres, pour le mettre à côté.
  ///
  /// ⚠️ L'UNITÉ DU SERVEUR D'ABORD, LA PÉRIODICITÉ ENSUITE. On déduisait le
  /// libellé de la seule périodicité : la formation, facturée UNE fois mais
  /// PAR PERSONNE, s'affichait « 75 000 F une fois », ce qui laisse croire
  /// qu'on paie pour tout un groupe. Le barème porte l'unité exacte —
  /// « FCFA par personne », « FCFA pour douze mois » — : c'est elle qui fait
  /// foi. La périodicité ne sert qu'à défaut.
  String get rythme {
    final u = unite?.trim();
    if (u != null && u.isNotEmpty) {
      // « FCFA par personne » → « par personne » : la devise est déjà dans
      // le montant (« 75 000 F »), la répéter alourdit la ligne.
      return u.replaceFirst(RegExp(r'^(FCFA|XAF|F)\s+'), '');
    }
    return switch (periodicite) {
      'MENSUELLE' => 'par mois',
      'ANNUELLE' => 'par an',
      'UNIQUE' => 'une fois',
      _ => '',
    };
  }

  /// Le prix d'entrée : le plus bas des tarifs applicables aujourd'hui.
  ///
  /// ⚠️ « À partir de », et jamais un prix ferme, quand le service a des
  /// formules : le prix dépend du chiffre d'affaires, et annoncer celui d'une
  /// tranche ferait croire à un forfait.
  /// ⚠️ LES TARIFS SANS MONTANT SONT ÉCARTÉS, PAS COMPTÉS POUR ZÉRO. Le régime
  /// du réel est sur étude ; le faire entrer dans le classement à zéro faisait
  /// annoncer « dès 0 F par mois » une offre qui commence à 12 500.
  ///
  /// Quand il ne reste aucun candidat, on rend `null` et l'écran écrit que le
  /// montant s'établit après étude. Jamais un chiffre de remplacement.
  ({double montant, String? motif, bool fixe})? aPartirDe(DateTime le) {
    final candidats = <Tarif>[
      if (formules.isEmpty)
        ?tarifApplicable(tarifs, le)
      else
        for (final f in formules) ?tarifApplicable(f.tarifs, le),
    ].where((t) => t.montant != null).toList();
    if (candidats.isEmpty) return null;
    candidats.sort((a, b) => a.montant!.compareTo(b.montant!));
    return (
      montant: candidats.first.montant!,
      motif: candidats.first.motif,
      fixe: candidats.first.fixe,
    );
  }

  /// Vrai quand le cabinet chiffre après examen : aucun montant applicable.
  bool surEtudeLe(DateTime le) => aPartirDe(le) == null;

  static Service depuisJson(Map<String, dynamic> j) => Service(
    code: j['code'] as String,
    libelle: j['libelle'] as String? ?? '',
    nature: j['nature'] as String? ?? '',
    periodicite: j['periodicite'] as String? ?? '',
    tarifs: [
      for (final t in (j['tarifs'] as List? ?? const []))
        Tarif.depuisJson(t as Map<String, dynamic>),
    ],
    formules: [
      for (final f in (j['formules'] as List? ?? const []))
        Formule.depuisJson(f as Map<String, dynamic>),
    ],
    inclus: [for (final i in (j['inclus'] as List? ?? const [])) '$i'],
    ouvreUnDossier: j['ouvre_un_dossier'] as bool? ?? false,
    souscriptibleEnLigne: j['souscriptible_en_ligne'] as bool? ?? false,
    unite: j['unite'] as String?,
    resume: j['resume'] as String?,
  );
}

/// Ce qu'une lecture du catalogue a produit.
///
/// ⚠️ Pas de `sessionAExpire` ici : ces routes sont publiques. Une session n'a
/// rien à y faire, et prétendre le contraire ferait renvoyer un visiteur vers
/// une connexion dont il n'a pas besoin.
class Offre {
  const Offre({this.services = const [], this.serveurJoignable = true});

  final List<Service> services;
  final bool serveurJoignable;

  /// Ce qu'on peut souscrire depuis le téléphone, tout de suite.
  List<Service> get enLigne =>
      services.where((s) => s.souscriptibleEnLigne).toList();

  /// Ce qui demande un examen du cabinet.
  List<Service> get surEtude =>
      services.where((s) => !s.souscriptibleEnLigne).toList();
}
