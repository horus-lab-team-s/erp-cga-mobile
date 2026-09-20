/// Une pièce telle que le CABINET la connaît, et non telle que l'appareil s'en
/// souvient.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI L'HISTORIQUE NE SE LIT PAS SUR LE TÉLÉPHONE
///
/// L'application tenait une file de dépôts, et cette file OUBLIE un dépôt dès
/// que le serveur l'accepte. C'était volontaire — la file est un sas, pas une
/// archive — mais il en résultait un défaut que l'adhérent voyait tous les
/// jours : une fois les pièces parties, l'écran affichait « tout est parti » et
/// plus rien. Impossible de répondre à la seule question qu'on se pose une
/// semaine plus tard : « est-ce que j'ai envoyé la facture de mardi ? »
///
/// La tentation était de garder les dépôts sur l'appareil. Trois raisons l'ont
/// écartée, et elles tiennent toutes les trois :
///
/// 1. **Un historique local se fige sur « envoyée ».** L'appareil sait qu'il a
///    remis la pièce ; il ne saura jamais que le comptable l'a lue, rapprochée,
///    puis comptabilisée. Or c'est cela que l'adhérent veut savoir — pas que sa
///    photo est partie, mais qu'elle a SERVI.
///
/// 2. **Un historique local meurt avec le téléphone.** Réinstallation, appareil
///    changé, téléphone perdu : l'archive disparaît alors que le cabinet, lui,
///    détient toujours les pièces. Montrer un historique vide à quelqu'un qui a
///    déposé deux cents justificatifs serait pire que ne rien montrer.
///
/// 3. **Un historique local ignore les autres canaux.** L'adhérent dépose aussi
///    par courriel et en main propre au cabinet. Son dossier ne se réduit pas à
///    ce qui est passé par ce téléphone, et lui présenter une vue partielle sous
///    le nom d'« historique » l'induirait en erreur sur ce qu'il a fourni.
///
/// L'historique se lit donc sur le serveur, qui est la seule source qui sache
/// répondre. La file reste ce qu'elle est : ce qui n'est pas encore parti.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// Où en est la pièce dans le traitement du cabinet.
///
/// ⚠️ Les cinq états du serveur, traduits ici SANS EN INVENTER UN SIXIÈME. La
/// tentation serait de replier « rapprochée » et « comptabilisée » sur un seul
/// « traitée » plus simple à dire. Ce serait retirer à l'adhérent une
/// information qu'il réclame au téléphone : une pièce rapprochée est reconnue
/// mais pas encore passée en écriture, et c'est précisément l'état sur lequel
/// portent ses relances de fin de mois.
enum EtatChezLeCabinet {
  /// Arrivée. Personne ne l'a encore ouverte.
  recue,

  /// Le cabinet a ouvert le document et su ce que c'était.
  lue,

  /// Rapprochée d'une opération du dossier.
  rapprochee,

  /// Passée en écriture comptable.
  comptabilisee,

  /// Classée : le dossier de l'exercice est clos de son côté.
  archivee;

  /// Ce que l'état signifie pour l'adhérent, à la première personne du dossier.
  ///
  /// ⚠️ Pas le nom technique. « RAPPROCHEE » ne veut rien dire à un commerçant ;
  /// « rapprochée d'une opération » le lui dit. Le dossier de design l'impose à
  /// sa section sur les libellés : on écrit ce que la chose fait, pas comment
  /// elle s'appelle dans la base.
  String get libelle => switch (this) {
    EtatChezLeCabinet.recue => 'Reçue par le cabinet',
    EtatChezLeCabinet.lue => 'Lue par le cabinet',
    EtatChezLeCabinet.rapprochee => 'Rapprochée d\'une opération',
    EtatChezLeCabinet.comptabilisee => 'Comptabilisée',
    EtatChezLeCabinet.archivee => 'Archivée',
  };

  /// Le rang dans la progression, de 0 à 4. ⚠️ Sert à DESSINER l'avancement,
  /// jamais à comparer deux pièces entre elles : une pièce archivée n'est pas
  /// « meilleure » qu'une pièce reçue hier.
  int get rang => index;

  /// Vrai dès que le cabinet a fait quelque chose de la pièce.
  ///
  /// ⚠️ C'est la seule question à laquelle l'adhérent tient vraiment. « Reçue »
  /// veut dire « elle est arrivée et elle attend » ; tout le reste veut dire
  /// « on s'en est occupé ».
  bool get priseEnCompte => this != EtatChezLeCabinet.recue;

  /// Lit l'état rendu par le serveur.
  ///
  /// ⚠️ Un état inconnu rend `recue` et NON une exception. Le jour où le serveur
  /// ajoutera un sixième état, une application déjà installée sur un téléphone
  /// ne doit pas cesser d'afficher l'historique pour autant : elle doit montrer
  /// ce qu'elle sait montrer. Un écran dégradé vaut mieux qu'un écran blanc.
  static EtatChezLeCabinet depuisLeServeur(String? nom) => switch (nom) {
    'RECUE' => EtatChezLeCabinet.recue,
    'LUE' => EtatChezLeCabinet.lue,
    'RAPPROCHEE' => EtatChezLeCabinet.rapprochee,
    'COMPTABILISEE' => EtatChezLeCabinet.comptabilisee,
    'ARCHIVEE' => EtatChezLeCabinet.archivee,
    _ => EtatChezLeCabinet.recue,
  };
}

/// Une pièce déjà remise, vue depuis l'appareil de l'adhérent.
class PieceRemise {
  const PieceRemise({
    required this.identifiant,
    required this.deposeLe,
    required this.etat,
    required this.canal,
    this.nomDuFichier,
    this.emetteur,
    this.montantTtc,
    this.referenceDocument,
  });

  /// La référence que porte la pièce chez le cabinet — « PJ-M08123-68a1… ».
  ///
  /// ⚠️ C'est ce numéro, et lui seul, qu'un adhérent doit citer au téléphone
  /// quand il appelle son comptable. L'identifiant local du dépôt ne quitte
  /// jamais l'appareil et ne veut rien dire pour le cabinet.
  final String identifiant;

  /// La date de la prise de vue, celle que la comptabilité retient.
  final DateTime deposeLe;

  final EtatChezLeCabinet etat;

  /// Par quel chemin la pièce est arrivée : MOBILE, COURRIEL, DEPOT…
  ///
  /// ⚠️ Affiché, et c'est délibéré. L'historique montre TOUT le dossier, pas
  /// seulement ce qui est parti de ce téléphone. Sans cette mention, l'adhérent
  /// qui retrouve une pièce envoyée par courriel croirait l'avoir photographiée.
  final String canal;

  final String? nomDuFichier;

  /// Ce que le cabinet a LU sur le document. Vide tant que la pièce est à
  /// l'état « reçue ».
  ///
  /// ⚠️ Ces trois champs valent mieux qu'une pastille d'état : voir apparaître
  /// « ENEO · 45 000 F » sous sa propre photo, c'est la preuve concrète que
  /// quelqu'un l'a ouverte et l'a comprise. Une pastille qui passe de gris à
  /// vert demande de croire sur parole.
  final String? emetteur;
  final double? montantTtc;
  final String? referenceDocument;

  /// Vrai quand le cabinet a identifié le document et en a tiré quelque chose.
  bool get identifiee =>
      emetteur != null || montantTtc != null || referenceDocument != null;

  /// Lit une ligne de `GET /collecte/pieces`.
  ///
  /// ⚠️ Tout est facultatif sauf l'identifiant et la date. Le serveur rend des
  /// nuls sur la moitié des champs tant que la pièce n'est pas identifiée, et
  /// c'est normal : une photo qui vient d'arriver n'a ni émetteur ni montant.
  static PieceRemise depuisJson(Map<String, dynamic> json) => PieceRemise(
    identifiant: json['identifiant'] as String,
    deposeLe: DateTime.parse(json['depose_le'] as String),
    etat: EtatChezLeCabinet.depuisLeServeur(json['etat'] as String?),
    canal: json['canal'] as String? ?? 'INDETERMINE',
    nomDuFichier: json['nom_fichier'] as String?,
    emetteur: json['emetteur'] as String?,
    // ⚠️ `num` et non `double` : le serveur rend `45000` pour un montant rond,
    // que Dart décode en `int`. Un transtypage direct vers `double` lèverait
    // une exception sur la moitié des factures, et l'historique entier
    // tomberait sur une seule ligne mal formée.
    montantTtc: (json['montant_ttc'] as num?)?.toDouble(),
    referenceDocument: json['reference_document'] as String?,
  );
}

/// Ce qu'une lecture de l'historique a produit.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI PAS UNE SIMPLE LISTE
///
/// Une liste vide se lit de trois façons, et l'écran ne peut pas les distinguer :
/// « vous n'avez jamais rien déposé », « le réseau manque », « votre session a
/// expiré ». Les trois appellent des phrases opposées, et deux d'entre elles
/// appellent un geste. Rendre une liste vide dans les trois cas revient à
/// afficher « aucune pièce déposée » à un adhérent qui en a remis deux cents —
/// le pire mensonge que cet écran puisse dire.
///
/// C'est la même leçon que [Vidage] a coûtée à la file d'attente, à ceci près
/// qu'ici elle se paie plus cher : la file se rattrape au réveil suivant,
/// l'historique se lit et se croit.
/// ─────────────────────────────────────────────────────────────────────────────
class Historique {
  const Historique({
    this.pieces = const [],
    this.serveurJoignable = true,
    this.sessionAExpire = false,
  });

  /// Les pièces du dossier, de la plus récente à la plus ancienne.
  final List<PieceRemise> pieces;

  /// Faux quand rien n'a abouti : pas de réseau, serveur injoignable, délai
  /// dépassé. L'écran doit alors le DIRE, et non montrer une liste vide.
  final bool serveurJoignable;

  /// Vrai quand il faut se reconnecter pour lire.
  final bool sessionAExpire;

  /// Combien de pièces le cabinet a déjà prises en compte.
  int get prisesEnCompte => pieces.where((p) => p.etat.priseEnCompte).length;
}
