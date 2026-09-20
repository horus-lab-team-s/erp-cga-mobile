/// La fiche du dossier, dans les mots de l'adhérent.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ CE QUE CET ÉCRAN EST, ET CE QU'IL N'EST PAS
///
/// C'est une fiche de CONSULTATION, plus un seul geste : signaler un changement.
/// Et ce geste ne modifie RIEN au dossier. Le serveur est formel : un
/// signalement est « une parole datée au journal, annoncée au chargé de
/// clientèle » ; c'est le cabinet qui instruit.
///
/// Laisser croire l'inverse serait grave : un adhérent qui déménage, signale sa
/// nouvelle adresse et croit son dossier à jour continuerait de recevoir ses
/// avis à l'ancienne — et manquerait ses échéances. L'écran dit donc ce que le
/// signalement fait vraiment : il prévient quelqu'un.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// Une personne du cabinet à qui l'adhérent peut parler.
class Interlocuteur {
  const Interlocuteur({
    required this.nom,
    required this.role,
    this.courriel,
    this.telephone,
  });

  final String nom;
  final String role;
  final String? courriel;
  final String? telephone;

  /// Le rôle en français, jamais le code du serveur.
  String get roleLisible => switch (role) {
    'CHARGE_CLIENTELE' => 'Chargé de clientèle',
    'COMPTABLE' => 'Comptable',
    'REVISEUR' => 'Réviseur',
    'FISCALISTE' => 'Fiscaliste',
    'DIRECTION' => 'Direction',
    _ => role.toLowerCase().replaceAll('_', ' '),
  };

  static Interlocuteur? depuisJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return Interlocuteur(
      nom: json['nom'] as String? ?? '',
      role: json['role'] as String? ?? '',
      courriel: json['courriel'] as String?,
      telephone: json['telephone'] as String?,
    );
  }
}

/// Une nature de changement que l'adhérent peut signaler.
class NatureDeChangement {
  const NatureDeChangement({
    required this.code,
    required this.libelle,
    required this.aide,
  });

  /// `ADRESSE`, `DIRIGEANT`, `ACTIVITE`, `TELEPHONE`, `AUTRE`.
  final String code;
  final String libelle;

  /// ⚠️ Ce que le changement ENTRAÎNE, en langage courant, et c'est le serveur
  /// qui l'écrit : « une nouvelle adresse peut changer votre centre des impôts,
  /// donc vos dates ». L'application n'explique pas le droit.
  final String aide;

  static NatureDeChangement depuisJson(Map<String, dynamic> j) =>
      NatureDeChangement(
        code: j['nature'] as String,
        libelle: j['libelle'] as String? ?? '',
        aide: j['aide'] as String? ?? '',
      );
}

/// Un changement déjà signalé, et quand.
class Signalement {
  const Signalement({
    required this.libelle,
    required this.message,
    required this.le,
  });

  final String libelle;
  final String message;
  final String le;

  static Signalement depuisJson(Map<String, dynamic> j) => Signalement(
    libelle: j['libelle'] as String? ?? '',
    message: j['message'] as String? ?? '',
    le: j['le'] as String? ?? '',
  );
}

/// La fiche complète.
class MonEntreprise {
  const MonEntreprise({
    required this.niu,
    required this.denomination,
    required this.forme,
    required this.regimeTitre,
    required this.assujettieTva,
    required this.dirigeants,
    required this.natures,
    required this.signalements,
    this.activite,
    this.rccm,
    this.siege,
    this.centre,
    this.regimeExplication,
    this.regimeDepuis,
    this.adhesionNumero,
    this.adherenteDepuis,
    this.interlocuteur,
  });

  final String niu;
  final String denomination;
  final String forme;

  /// Le régime, qui EST la formule d'adhésion : impôt libératoire, réel
  /// simplifié ou régime du réel. C'est lui qui commande ce que le cabinet
  /// suit pour ce dossier.
  final String regimeTitre;
  final String? regimeExplication;
  final String? regimeDepuis;

  final bool assujettieTva;
  final String? activite;
  final String? rccm;
  final String? siege;
  final String? centre;
  final String? adhesionNumero;
  final String? adherenteDepuis;

  /// Nom et qualité, tels que le cabinet les connaît.
  final List<({String nom, String qualite})> dirigeants;

  final Interlocuteur? interlocuteur;
  final List<NatureDeChangement> natures;
  final List<Signalement> signalements;

  static MonEntreprise depuisJson(Map<String, dynamic> j) {
    final regime = j['regime'];
    final r = regime is Map<String, dynamic> ? regime : const <String, dynamic>{};
    return MonEntreprise(
      niu: j['niu'] as String? ?? '',
      denomination: j['denomination'] as String? ?? '',
      forme: j['forme'] as String? ?? '',
      regimeTitre: r['titre'] as String? ?? '',
      regimeExplication: r['explication'] as String?,
      regimeDepuis: r['depuis'] as String?,
      assujettieTva: j['assujettie_tva'] as bool? ?? false,
      activite: j['activite'] as String?,
      rccm: j['rccm'] as String?,
      siege: j['siege'] as String?,
      centre: j['centre'] as String?,
      adhesionNumero: j['adhesion_numero'] as String?,
      adherenteDepuis: j['adherente_depuis'] as String?,
      dirigeants: [
        for (final d in (j['dirigeants'] as List? ?? const []))
          (
            nom: (d as Map<String, dynamic>)['nom'] as String? ?? '',
            qualite: d['qualite'] as String? ?? '',
          ),
      ],
      interlocuteur: Interlocuteur.depuisJson(j['interlocuteur']),
      natures: [
        for (final n in (j['natures'] as List? ?? const []))
          NatureDeChangement.depuisJson(n as Map<String, dynamic>),
      ],
      signalements: [
        for (final s in (j['signalements'] as List? ?? const []))
          Signalement.depuisJson(s as Map<String, dynamic>),
      ],
    );
  }
}

/// Ce qu'une lecture de la fiche a produit. Même parti que partout ailleurs :
/// une fiche absente se lit de trois façons, et deux appellent un geste.
class Fiche {
  const Fiche({
    this.entreprise,
    this.serveurJoignable = true,
    this.sessionAExpire = false,
  });

  final MonEntreprise? entreprise;
  final bool serveurJoignable;
  final bool sessionAExpire;
}

/// Ce qu'un signalement a produit.
enum SortDuSignalement {
  /// Le cabinet est prévenu. ⚠️ Le dossier, lui, n'a pas bougé.
  transmis,

  /// Le même signalement, le même jour, par le même compte : un double appui.
  /// ⚠️ Ce n'est PAS un échec, et l'écran ne doit pas le présenter comme tel :
  /// le cabinet est déjà prévenu.
  dejaSignale,

  /// Le serveur a refusé pour une autre raison qui ne changera pas.
  refuse,

  sessionExpiree,
  indisponible,
}
