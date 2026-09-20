/// Ce que l'adhérent doit, et quand.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ L'ÉCRAN QUI MANQUAIT LE PLUS, ET POURQUOI
///
/// L'application savait déposer une pièce et montrer ce que le cabinet en avait
/// fait. Elle ne disait rien de la question qui vient AVANT : « qu'est-ce que je
/// dois faire, et pour quand ? »
///
/// Le dossier d'essai porte six obligations, dont cinq en retard de cinq cent
/// quatre-vingt-deux jours, et dix-neuf autres périodes en retard derrière la
/// plus ancienne. Un adhérent qui ouvre son téléphone doit pouvoir lire cela
/// sans appeler son comptable.
///
/// ⚠️ UNE CARTE PAR OBLIGATION, JAMAIS UNE PAR PÉRIODE.
///
/// La règle vient du serveur, qui l'a apprise à ses dépens : un premier essai
/// sur ce même dossier rendait soixante-dix lignes « en retard », douze mois de
/// CNPS, douze de TVA, douze d'acomptes. Une liste pareille ne se lit pas, et
/// l'adhérent n'y trouve pas quoi régler en premier. Le serveur ne rend donc
/// qu'une instance par obligation — la plus ancienne période en retard sans
/// preuve, celle qu'on règle d'abord — et dit combien d'autres suivent.
/// L'application se garde de recomposer une liste que le serveur a délibérément
/// réduite.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// Où en est une obligation, du point de vue de l'adhérent.
///
/// ⚠️ Quatre états, et la nuance entre les deux du milieu est ce que cet écran
/// doit le mieux rendre.
enum EtatPourLAdherent {
  /// L'échéance est passée, rien n'est déposé, aucune preuve envoyée.
  enRetard,

  /// L'adhérent a envoyé sa quittance : le cabinet la vérifie.
  ///
  /// ⚠️ **CE N'EST PAS « RÉGLÉ ».** Une preuve envoyée n'est pas un dépôt.
  /// L'obligation reste à faire au calendrier du cabinet tant qu'un
  /// collaborateur habilité n'a pas consigné l'accusé, quittance jointe. Une
  /// quittance illisible, ou d'un autre trimestre, ne règle rien. Écrire
  /// « réglé » ici ferait croire à l'adhérent qu'il est en ordre alors qu'il ne
  /// l'est pas, et c'est exactement le genre de tranquillité qui coûte des
  /// majorations.
  preuveEnvoyee,

  /// L'échéance n'est pas passée.
  aVenir,

  /// Le cabinet a consigné le dépôt : l'accusé existe.
  deposee;

  /// La phrase que l'adhérent lit, jamais le nom technique.
  String get libelle => switch (this) {
    EtatPourLAdherent.enRetard => 'En retard',
    EtatPourLAdherent.preuveEnvoyee => 'Le cabinet vérifie votre preuve',
    EtatPourLAdherent.aVenir => 'À venir',
    EtatPourLAdherent.deposee => 'Déposée par le cabinet',
  };

  /// Vrai quand l'adhérent a quelque chose à faire, maintenant.
  bool get demandeUnGeste => this == EtatPourLAdherent.enRetard;

  /// Vrai quand plus rien n'est attendu de personne.
  bool get close => this == EtatPourLAdherent.deposee;

  /// ⚠️ Un état inconnu rend `aVenir`, et non une exception : le serveur peut
  /// gagner un cinquième état avant que ce téléphone ne soit mis à jour. Le
  /// repli le plus prudent est celui qui n'alarme pas à tort.
  static EtatPourLAdherent depuisLeServeur(String? nom) => switch (nom) {
    'EN_RETARD' => EtatPourLAdherent.enRetard,
    'PREUVE_ENVOYEE' => EtatPourLAdherent.preuveEnvoyee,
    'A_VENIR' => EtatPourLAdherent.aVenir,
    'DEPOSEE' => EtatPourLAdherent.deposee,
    _ => EtatPourLAdherent.aVenir,
  };
}

/// Une obligation, à la date où l'adhérent la regarde.
class Echeance {
  const Echeance({
    required this.codeObligation,
    required this.titre,
    required this.periode,
    required this.periodeDebut,
    required this.periodeFin,
    required this.echeanceLe,
    required this.etat,
    required this.jours,
    required this.autresPeriodesEnRetard,
    this.deQuoiSAgitIl,
    this.enCasDeRetard,
    this.prochaineEcheance,
    this.montantEstime,
  });

  /// Le code du référentiel : `CNPS`, `TVA`… ⚠️ Il ne s'affiche pas, il sert à
  /// désigner l'obligation au serveur quand on lui envoie une preuve.
  final String codeObligation;

  /// « Cotisations sociales CNPS ».
  final String titre;

  /// « janvier 2025 », déjà mis en mots par le serveur.
  ///
  /// ⚠️ On ne recompose pas cette phrase ici. Une période fiscale n'est pas un
  /// intervalle de dates qu'on met en français : un exercice décalé, un
  /// trimestre civil et un mois ne se disent pas de la même façon, et le
  /// référentiel sait lequel s'applique.
  final String periode;

  final DateTime periodeDebut;
  final DateTime periodeFin;
  final DateTime echeanceLe;
  final EtatPourLAdherent etat;

  /// Le nombre de jours de retard, ou d'avance. Rendu par le serveur.
  final int jours;

  /// Combien d'AUTRES périodes de la même obligation sont en retard.
  ///
  /// ⚠️ Le taire donnerait une fausse tranquillité : le dossier d'essai porte
  /// dix-neuf autres mois de CNPS en retard derrière la carte affichée. Un
  /// adhérent qui règle la première et croit en avoir fini se trompe de
  /// dix-neuf mois.
  final int autresPeriodesEnRetard;

  /// L'explication du référentiel, en langage courant.
  final String? deQuoiSAgitIl;

  /// Ce qu'un retard entraîne, en langage courant.
  final String? enCasDeRetard;

  final DateTime? prochaineEcheance;
  final double? montantEstime;

  static DateTime? _date(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.parse(v) : null;

  static Echeance depuisJson(Map<String, dynamic> json) => Echeance(
    codeObligation: json['code_obligation'] as String,
    titre: json['titre'] as String? ?? json['libelle'] as String? ?? '',
    periode: json['periode'] as String? ?? '',
    periodeDebut: DateTime.parse(json['periode_debut'] as String),
    periodeFin: DateTime.parse(json['periode_fin'] as String),
    echeanceLe: DateTime.parse(json['echeance'] as String),
    etat: EtatPourLAdherent.depuisLeServeur(json['etat'] as String?),
    jours: (json['jours'] as num?)?.toInt() ?? 0,
    autresPeriodesEnRetard:
        (json['autres_periodes_en_retard'] as num?)?.toInt() ?? 0,
    deQuoiSAgitIl: json['de_quoi_s_agit_il'] as String?,
    enCasDeRetard: json['en_cas_de_retard'] as String?,
    prochaineEcheance: _date(json['prochaine_echeance']),
    // ⚠️ `num` et non `double` : un montant rond arrive en entier. Même piège
    // que sur les pièces remises, et il tombait sur la moitié des lignes.
    montantEstime: (json['montant_estime'] as num?)?.toDouble(),
  );
}

/// Ce qu'une lecture de l'échéancier a produit.
///
/// ⚠️ Même parti que pour l'historique des pièces : une liste vide se lit de
/// trois façons, et deux appellent un geste. « Vous êtes à jour » et « je n'ai
/// pas pu demander » ne se disent pas de la même manière, et la première, dite à
/// tort, laisse un adhérent en retard de dix-neuf mois se croire tranquille.
class Echeancier {
  const Echeancier({
    this.echeances = const [],
    this.serveurJoignable = true,
    this.sessionAExpire = false,
  });

  final List<Echeance> echeances;
  final bool serveurJoignable;
  final bool sessionAExpire;

  /// Ce qui demande un geste de l'adhérent, maintenant.
  int get enRetard => echeances.where((e) => e.etat.demandeUnGeste).length;

  /// Le total des périodes en retard, celles qui sont derrière comprises.
  ///
  /// ⚠️ C'est ce nombre-là qu'il faut annoncer, et non le nombre de cartes :
  /// six cartes peuvent cacher une centaine de mois en retard.
  int get periodesEnRetard => echeances
      .where((e) => e.etat.demandeUnGeste)
      .fold(0, (somme, e) => somme + 1 + e.autresPeriodesEnRetard);
}
