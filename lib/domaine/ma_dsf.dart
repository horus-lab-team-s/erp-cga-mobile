/// Ma déclaration annuelle (DSF), vue de l'adhérent (18 octobre 2026, point 24).
///
/// Lu sur `GET /cloture/dossiers/{niu}/ma-dsf`, la même route que l'espace web.
/// ⚠️ AUCUN CHIFFRE ET AUCUN NOM : l'adhérent suit l'état de sa déclaration et
/// verse ce qu'on attend de lui ; il ne lit pas une liasse en cours.
library;

enum EtatDeMaDsf {
  enPreparation,
  preparee,
  validee,
  deposee;

  String get libelle => switch (this) {
    EtatDeMaDsf.enPreparation => 'En préparation au cabinet',
    EtatDeMaDsf.preparee => 'Préparée, en relecture',
    EtatDeMaDsf.validee => 'Validée, prête pour le dépôt',
    EtatDeMaDsf.deposee => 'Déposée à la DGI',
  };

  String get explication => switch (this) {
    EtatDeMaDsf.enPreparation =>
      'Le cabinet arrête vos comptes de l\'exercice. Envoyez les pièces à fournir : elles l\'aident.',
    EtatDeMaDsf.preparee =>
      'La déclaration est établie ; un second collaborateur la relit avant qu\'elle parte.',
    EtatDeMaDsf.validee =>
      'La déclaration est relue et validée ; elle part sur le portail de la DGI.',
    EtatDeMaDsf.deposee =>
      'La DGI a délivré son accusé. La copie déposée se consulte ici.',
  };

  /// L'avancement, pour la barre de progression : quatre étapes.
  int get rang => index + 1;

  static EtatDeMaDsf depuisLeServeur(String? nom) => switch (nom) {
    'PREPAREE' => EtatDeMaDsf.preparee,
    'VALIDEE' => EtatDeMaDsf.validee,
    'DEPOSEE' => EtatDeMaDsf.deposee,
    _ => EtatDeMaDsf.enPreparation,
  };
}

enum EtatDeMaPiece {
  produite,
  jointe,
  neant,
  aFournir;

  String get libelle => switch (this) {
    EtatDeMaPiece.produite => 'Établie par le cabinet',
    EtatDeMaPiece.jointe => 'Reçue',
    EtatDeMaPiece.neant => 'Sans objet',
    EtatDeMaPiece.aFournir => 'À fournir',
  };

  static EtatDeMaPiece depuisLeServeur(String? nom) => switch (nom) {
    'PRODUITE' => EtatDeMaPiece.produite,
    'JOINTE' => EtatDeMaPiece.jointe,
    'NEANT' => EtatDeMaPiece.neant,
    _ => EtatDeMaPiece.aFournir,
  };
}

class MaPieceDsf {
  const MaPieceDsf({
    required this.numero,
    required this.libelle,
    required this.etat,
    required this.versable,
    this.nomDuFichier,
  });

  final int numero;
  final String libelle;
  final EtatDeMaPiece etat;

  /// À fournir, ou versée par l'adhérent et remplaçable avant le dépôt.
  final bool versable;
  final String? nomDuFichier;

  static MaPieceDsf depuis(Map<String, dynamic> json) => MaPieceDsf(
    numero: (json['numero'] as num).toInt(),
    libelle: json['libelle'] as String,
    etat: EtatDeMaPiece.depuisLeServeur(json['etat'] as String?),
    versable: json['versable'] == true,
    nomDuFichier: json['nom_du_fichier'] as String?,
  );
}

class MaDsfDeLExercice {
  const MaDsfDeLExercice({
    required this.exercice,
    required this.cloture,
    required this.etat,
    required this.aFournir,
    required this.pieces,
    required this.document,
    this.numeroAccuse,
    this.deposeeLe,
  });

  final String exercice;
  final DateTime cloture;
  final EtatDeMaDsf etat;
  final int aFournir;
  final List<MaPieceDsf> pieces;

  /// La copie de la DSF déposée se télécharge.
  final bool document;
  final String? numeroAccuse;
  final DateTime? deposeeLe;

  /// Ce que l'adhérent a à faire : les pièces à fournir et celles qu'il a versées.
  List<MaPieceDsf> get attendues => pieces
      .where(
        (p) =>
            p.etat == EtatDeMaPiece.aFournir || p.etat == EtatDeMaPiece.jointe,
      )
      .toList();

  /// Ce que le cabinet établit lui-même, ou a déclaré sans objet.
  List<MaPieceDsf> get parLeCabinet => pieces
      .where(
        (p) =>
            p.etat == EtatDeMaPiece.produite || p.etat == EtatDeMaPiece.neant,
      )
      .toList();

  static MaDsfDeLExercice depuis(Map<String, dynamic> json) => MaDsfDeLExercice(
    exercice: json['exercice'] as String,
    cloture: DateTime.parse(json['cloture'] as String),
    etat: EtatDeMaDsf.depuisLeServeur(json['etat'] as String?),
    aFournir: (json['a_fournir'] as num?)?.toInt() ?? 0,
    pieces: [
      for (final p in (json['pieces'] as List? ?? const []))
        MaPieceDsf.depuis(p as Map<String, dynamic>),
    ],
    document: json['document'] == true,
    numeroAccuse: json['numero_accuse'] as String?,
    deposeeLe: json['deposee_le'] == null
        ? null
        : DateTime.parse(json['deposee_le'] as String),
  );
}

class MaDsf {
  const MaDsf(this.exercices);

  final List<MaDsfDeLExercice> exercices;

  static MaDsf depuis(Map<String, dynamic> json) => MaDsf([
    for (final e in (json['exercices'] as List? ?? const []))
      MaDsfDeLExercice.depuis(e as Map<String, dynamic>),
  ]);
}
