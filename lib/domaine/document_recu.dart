/// Les accusés de dépôt : ce que le cabinet a déposé pour l'adhérent.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ CE QUE « MES DOCUMENTS » VEUT DIRE, ET CE QUE CE N'EST PAS
///
/// Ce sont les **preuves de dépôt** : le numéro que le guichet a rendu quand le
/// cabinet a déposé une déclaration au nom de l'adhérent. C'est ce qu'on produit
/// devant l'administration quand elle conteste une date.
///
/// Ce ne sont ni les rapports mensuels du cabinet — qui exigent `LIRE_PILOTAGE`
/// et `LIRE_AUDIT`, deux permissions qu'un adhérent n'a pas, parce que ce sont
/// des documents INTERNES —, ni les pièces que l'adhérent a lui-même envoyées,
/// qui ont leur propre écran.
///
/// ⚠️ L'ÉCRAN NE MONTRE QUE CE QUE LE SERVEUR REND. Il a longtemps rendu une
/// liste vide, faute d'accusé dans le jeu de démonstration, et il aurait été
/// tentant d'appeler cela « un écran à faire plus tard ». Le trou était dans les
/// données, pas dans le produit.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// Un accusé de dépôt.
class DocumentRecu {
  const DocumentRecu({
    required this.numero,
    required this.titre,
    required this.periode,
    required this.deposeLe,
    required this.guichet,
    required this.verifiable,
    this.montantConstate,
  });

  /// Le numéro rendu par le guichet. ⚠️ C'est la seule référence que
  /// l'administration reconnaîtra : elle se cite, donc elle se copie.
  final String numero;

  /// « TVA du mois », « Cotisations sociales CNPS », « Déclaration annuelle ».
  final String titre;

  /// « février 2024 », « année 2023 » : déjà mis en mots par le serveur.
  final String periode;

  final DateTime deposeLe;

  /// « Impôts (DGI) », « CNPS ». ⚠️ Affiché, parce qu'un accusé CNPS ne prouve
  /// rien devant la DGI : savoir de quel guichet vient le numéro fait partie de
  /// la preuve.
  final String guichet;

  /// Vrai quand un justificatif est archivé avec l'accusé — la quittance, la
  /// capture du portail.
  ///
  /// ⚠️ **FAUX VEUT DIRE QUELQUE CHOSE, ET L'ÉCRAN DOIT LE DIRE.** L'accusé
  /// repose alors sur la parole de celui qui a saisi le numéro. Ce n'est pas un
  /// défaut à cacher : c'est une nuance que l'adhérent doit connaître avant de
  /// s'appuyer dessus devant l'administration.
  final bool verifiable;

  final double? montantConstate;

  /// ⚠️ Le montant arrive ici en CHAÎNE — « 1340000.00 » —, là où la liste des
  /// pièces le rend en nombre. Le même serveur, deux routes, deux formes : un
  /// transtypage direct vers un décimal rendrait `null` sur toutes les lignes,
  /// et aucun montant ne s'afficherait. Les deux formes sont donc lues.
  static double? _montant(Object? v) => switch (v) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };

  static DocumentRecu depuisJson(Map<String, dynamic> j) => DocumentRecu(
    numero: j['numero'] as String,
    titre: j['titre'] as String? ?? '',
    periode: j['periode'] as String? ?? '',
    deposeLe: DateTime.parse(j['depose_le'] as String),
    guichet: j['guichet'] as String? ?? '',
    verifiable: j['verifiable'] as bool? ?? false,
    montantConstate: _montant(j['montant_constate']),
  );
}

/// Ce qu'une lecture des documents a produit.
class Documents {
  const Documents({
    this.documents = const [],
    this.serveurJoignable = true,
    this.sessionAExpire = false,
  });

  final List<DocumentRecu> documents;
  final bool serveurJoignable;
  final bool sessionAExpire;
}
