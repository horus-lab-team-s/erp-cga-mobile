/// Le mois de l'adhérent : ce qui manque, ou que tout est complet.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ C'EST LE SERVEUR QUI DIT SI LE MOIS EST COMPLET, JAMAIS L'ÉCRAN.
///
/// La route `/pilotage/dossiers/{niu}/mon-mois` rend un bandeau déjà rédigé
/// — un état, un titre, un détail — dont les mots sont au référentiel du
/// cabinet. L'application les affiche tels quels. Recomposer « complet »
/// ici, en comptant les demandes ouvertes, dirait « complet » à une entreprise
/// qui n'a envoyé aucune pièce du mois : le serveur, lui, sait distinguer
/// « rien n'est demandé » de « rien n'est arrivé ».
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// Les quatre états du mois, tels que le serveur les nomme.
enum EtatDuMois {
  /// Le cabinet a demandé des pièces, encore ouvertes.
  aEnvoyer,

  /// Rien n'est demandé, mais le cabinet vérifie : il pourrait manquer
  /// quelque chose.
  enVerification,

  /// Aucune pièce du mois n'est arrivée. ⚠️ Ce n'est PAS « complet ».
  aucunePiece,

  /// Des pièces sont arrivées, et rien n'est demandé.
  complet;

  static EtatDuMois depuis(String? code) => switch (code) {
    'A_ENVOYER' => aEnvoyer,
    'EN_VERIFICATION' => enVerification,
    'COMPLET' => complet,
    // ⚠️ Un état inconnu se lit comme « aucune pièce » : c'est le seul qui
    // pousse à agir sans rien affirmer. Le lire comme « complet » rassurerait
    // à tort.
    _ => aucunePiece,
  };

  /// Vrai quand l'adhérent a quelque chose à faire.
  bool get demandeUnGeste => this == aEnvoyer || this == aucunePiece;
}

/// Une pièce que le cabinet attend de l'adhérent.
class Attendue {
  const Attendue({
    required this.demande,
    required this.libelle,
    required this.attenduePour,
    required this.enRetard,
    required this.bloquante,
    required this.aCorriger,
    this.pieceARectifier,
    this.reponse,
    this.reponseLe,
  });

  /// La référence de la demande (« DP-2026-002 »), à rappeler au cabinet.
  final String demande;
  final String libelle;
  final DateTime? attenduePour;
  final bool enRetard;

  /// Sans elle, le cabinet ne peut pas clore le mois.
  final bool bloquante;

  /// Une pièce déjà envoyée, mais à refaire : une facture rectificative.
  final bool aCorriger;

  /// La pièce refusée (« PJ-2026-0013 »), quand la demande en corrige une.
  /// ⚠️ C'est elle que l'adhérent doit revoir pour comprendre ce qu'on lui
  /// demande : « la facture F-2026-0424 » ne lui dit rien sans l'image.
  final String? pieceARectifier;

  /// Ce que l'adhérent a déjà répondu, s'il l'a fait.
  final String? reponse;
  final DateTime? reponseLe;

  bool get aRepondu => reponse != null;

  static Attendue depuisJson(Map<String, dynamic> j) => Attendue(
    demande: j['demande'] as String,
    libelle: j['libelle'] as String? ?? '',
    attenduePour: DateTime.tryParse(j['attendue_pour'] as String? ?? ''),
    enRetard: j['en_retard'] as bool? ?? false,
    bloquante: j['bloquante'] as bool? ?? false,
    aCorriger: j['a_corriger'] as bool? ?? false,
    pieceARectifier: j['piece_a_rectifier'] as String?,
    reponse: j['reponse'] as String?,
    reponseLe: DateTime.tryParse(j['reponse_le'] as String? ?? ''),
  );
}

/// Ce qu'une lecture du mois a produit.
class MonMois {
  const MonMois({
    this.denomination = '',
    this.nomDuMois = '',
    this.etat = EtatDuMois.aucunePiece,
    this.titre = '',
    this.detail = '',
    this.attendues = const [],
    this.justificatifsRecus = 0,
    this.serveurJoignable = true,
    this.sessionAExpire = false,
    this.serveurEnPanne = false,
    this.copieDu,
  });

  final String denomination;

  /// « août 2026 », déjà écrit par le serveur.
  final String nomDuMois;
  final EtatDuMois etat;

  /// Le titre et le détail du bandeau, rédigés par le serveur.
  final String titre;
  final String detail;
  final List<Attendue> attendues;

  /// ⚠️ Reçues PLUS attendues : le dénominateur de l'avancement du mois.
  int get piecesDuMois => justificatifsRecus + attendues.length;

  /// Combien de justificatifs le cabinet a déjà reçus pour ce mois.
  ///
  /// ⚠️ Avec `attendues`, il donne l'avancement du mois : « 2 sur 5 ». Le
  /// serveur le rend depuis toujours (`justificatifs_du_mois`) ; l'application
  /// ne le lisait pas, et ne pouvait donc rien montrer de l'avancement.
  final int justificatifsRecus;
  final bool serveurJoignable;
  final bool sessionAExpire;

  /// 20 octobre 2026 : le téléphone a du réseau, mais le serveur n'a pas répondu
  /// comme il faut. Faux avec `serveurJoignable` faux : c'est le réseau qui manque.
  final bool serveurEnPanne;

  /// Non nul : le réseau a manqué, et ce qui s'affiche est la dernière lecture
  /// gardée sur l'appareil, de cet instant-là. ⚠️ `serveurJoignable` reste vrai :
  /// le contenu est lisible ; c'est cette date qui dit qu'il peut avoir vieilli.
  final DateTime? copieDu;

  static MonMois depuisJson(
    Map<String, dynamic> j, {
    DateTime? copieDu,
    bool serveurEnPanne = false,
  }) {
    final bandeau = j['bandeau'] as Map<String, dynamic>? ?? const {};
    return MonMois(
      copieDu: copieDu,
      serveurEnPanne: serveurEnPanne,
      denomination: j['denomination'] as String? ?? '',
      nomDuMois: j['nom_du_mois'] as String? ?? '',
      etat: EtatDuMois.depuis(bandeau['etat'] as String?),
      titre: bandeau['titre'] as String? ?? '',
      detail: bandeau['detail'] as String? ?? '',
      attendues: [
        for (final a in (j['attendues'] as List? ?? []))
          Attendue.depuisJson(a as Map<String, dynamic>),
      ],
      justificatifsRecus: (j['justificatifs_du_mois'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Les réponses toutes faites à une demande du cabinet.
///
/// ⚠️ Deux réponses, pas trois : « envoyer la pièce » n'est pas une réponse,
/// c'est un dépôt, et il a son propre geste.
enum NatureDeReponse {
  plusTard('PLUS_TARD', "Je l'aurai la semaine prochaine"),
  introuvable('INTROUVABLE', "Je n'ai pas ce document");

  const NatureDeReponse(this.code, this.libelle);
  final String code;
  final String libelle;
}

/// Ce qu'une réponse au cabinet a produit.
enum SortDeLaReponse {
  transmise,

  /// 409 : le serveur a déjà une réponse du jour, ou la demande est close.
  /// ⚠️ Pas un échec pour l'adhérent : le cabinet a l'information.
  dejaRecue,
  refusee,
  sessionExpiree,
  indisponible,
}
