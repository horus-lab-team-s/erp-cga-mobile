/// Le devis, son règlement, et la souscription qui en naît.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ L'ORDRE DES TROIS ACTES, ET CE QUE CHACUN ENGAGE
///
/// 1. **Le devis** chiffre ce que le prospect a coché, au barème du jour. Les
///    montants y sont RECOPIÉS et non référencés : un devis reçu le 20 mars et
///    rouvert le 2 avril doit afficher le prix de mars. Valable trente jours.
/// 2. **L'engagement** demande le paiement mobile. Le serveur envoie alors un
///    message sur le téléphone du prospect, qu'il valide avec son code.
/// 3. **La souscription** reste `EN_ATTENTE_PAIEMENT` jusqu'à la validation.
///
/// ⚠️ RIEN N'EST ACQUIS AVANT LA VALIDATION, et l'écran ne doit pas le laisser
/// croire. Le prospect qui voit « c'est fait » après avoir demandé le paiement,
/// puis n'entre pas son code, se croit client d'un cabinet qui ne le connaît
/// pas.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// Qui demande. ⚠️ Le téléphone est exigé : c'est sur lui que part la demande
/// de paiement, et c'est par lui que le cabinet rappelle.
class Prospect {
  const Prospect({
    required this.nom,
    required this.prenom,
    required this.courriel,
    required this.telephone,
    this.denomination,
    this.niu,
    this.chiffreAffaires,
  });

  final String nom;
  final String prenom;
  final String courriel;
  final String telephone;
  final String? denomination;

  /// Le numéro d'identifiant unique de l'entreprise auprès des impôts.
  ///
  /// ⚠️ EXIGÉ POUR TOUTE PRESTATION QUI OUVRE UN DOSSIER — l'adhésion. Il ne
  /// l'était pas dans l'application, et c'était le défaut le plus grave trouvé
  /// en essai réel : le serveur établit le devis sans lui, puis REFUSE le
  /// paiement (« le NIU de l'entreprise est nécessaire »). L'adhérent
  /// remplissait tout, voyait son prix, touchait « Payer »… et restait bloqué
  /// sur la prestation principale du cabinet.
  final String? niu;

  /// ⚠️ Facultatif, mais il décide du prix : sans lui, le serveur ne peut pas
  /// déduire la tranche d'une prestation à formules, et refuse le devis en 422.
  final double? chiffreAffaires;

  Map<String, dynamic> versJson() => {
    'nom': nom,
    'prenom': prenom,
    'courriel': courriel,
    'telephone': telephone,
    if (denomination != null && denomination!.isNotEmpty)
      'denomination': denomination,
    if (niu != null && niu!.isNotEmpty) 'niu': niu,
    if (chiffreAffaires != null) 'chiffre_affaires_declare': chiffreAffaires,
  };
}

/// Une ligne chiffrée du devis.
class LigneDeDevis {
  const LigneDeDevis({
    required this.service,
    required this.libelle,
    required this.montant,
    required this.periodicite,
    this.precision,
    this.formule,
  });

  final String service;
  final String libelle;
  final double montant;
  final String periodicite;

  /// « FCFA par mois » : l'unité, telle que le serveur la formule.
  final String? precision;

  /// La tranche retenue par le serveur d'après le chiffre d'affaires
  /// (« LIBERATOIRE »). C'est son prix qui doit être fixé pour qu'on paie.
  final String? formule;

  static LigneDeDevis depuisJson(Map<String, dynamic> j) => LigneDeDevis(
    service: j['service'] as String? ?? '',
    libelle: j['libelle'] as String? ?? '',
    montant: double.tryParse('${j['montant']}') ?? 0,
    periodicite: j['periodicite'] as String? ?? '',
    precision: j['precision'] as String?,
    formule: j['formule'] as String?,
  );
}

/// Un devis établi.
class Devis {
  const Devis({
    required this.reference,
    required this.lignes,
    required this.montantTotal,
    required this.montantARegler,
    required this.etat,
    this.abonnementMensuel,
    this.valideJusquAu,
    this.prixArretes = false,
  });

  final String reference;
  final List<LigneDeDevis> lignes;

  /// ⚠️ LU SUR LE SERVEUR, JAMAIS RECALCULÉ ICI.
  ///
  /// Vrai quand chaque prix du devis a été arrêté par le gérant. Le serveur le
  /// recopie dans le devis en même temps que le montant : un devis établi sur
  /// un prix indicatif reste indicatif, même si le prix est fixé le lendemain.
  /// L'application et la vitrine lisent ce même champ ; recopier la règle dans
  /// chacune finirait par en faire deux règles. Faux par défaut : on ne
  /// présente pas un paiement sur un prix dont on ne sait rien.
  final bool prixArretes;

  /// Tout ce que le devis chiffre, abonnement compris.
  final double montantTotal;

  /// ⚠️ CE QU'ON PAIE MAINTENANT, et c'est rarement le total : un abonnement
  /// mensuel se prélève ensuite. Confondre les deux ferait annoncer 192 500 F
  /// à quelqu'un à qui l'on en demande 180 000.
  final double montantARegler;

  /// Ce qui sera prélevé chaque mois, s'il y a un abonnement.
  final double? abonnementMensuel;

  final String etat;
  final DateTime? valideJusquAu;

  static double _nombre(Object? v) => double.tryParse('$v') ?? 0;

  static Devis depuisJson(Map<String, dynamic> j) => Devis(
    reference: j['reference'] as String,
    lignes: [
      for (final l in (j['lignes'] as List? ?? const []))
        LigneDeDevis.depuisJson(l as Map<String, dynamic>),
    ],
    montantTotal: _nombre(j['montant_total']),
    montantARegler: _nombre(j['montant_a_regler']),
    abonnementMensuel: j['abonnement_mensuel'] == null
        ? null
        : _nombre(j['abonnement_mensuel']),
    etat: j['etat'] as String? ?? '',
    valideJusquAu: j['valide_jusqu_au'] == null
        ? null
        : DateTime.tryParse('${j['valide_jusqu_au']}'),
    prixArretes: j['prix_arretes'] as bool? ?? false,
  );
}

/// Ce qu'une demande de paiement a produit.
class Engagement {
  const Engagement({
    required this.message,
    required this.souscription,
    required this.etat,
    this.telephone,
    this.montant,
  });

  /// La phrase du serveur, affichée TELLE QUELLE : c'est lui qui sait ce que
  /// l'opérateur vient d'envoyer, et la réécrire ferait diverger les deux.
  final String message;

  /// La référence à garder : elle sert à suivre la souscription.
  final String souscription;

  /// `EN_ATTENTE_PAIEMENT` tant que le code n'est pas saisi.
  final String etat;

  final String? telephone;
  final double? montant;

  static Engagement depuisJson(Map<String, dynamic> j) {
    final s = j['souscription'];
    final p = j['paiement'];
    return Engagement(
      message: j['message'] as String? ?? '',
      souscription: s is Map<String, dynamic>
          ? (s['reference'] as String? ?? '')
          : '',
      etat: s is Map<String, dynamic> ? (s['etat'] as String? ?? '') : '',
      telephone: p is Map<String, dynamic> ? p['telephone'] as String? : null,
      montant: p is Map<String, dynamic>
          ? double.tryParse('${p['montant']}')
          : null,
    );
  }
}

/// Ce qu'une démarche publique a produit.
enum SortDeLaDemarche { fait, refuse, indisponible }

/// Le résultat d'un devis ou d'un engagement.
class Demarche<T> {
  const Demarche({required this.sort, this.valeur, this.motif});

  final SortDeLaDemarche sort;
  final T? valeur;

  /// ⚠️ Le motif du refus vient du serveur. « Prestation inconnue, ou formule
  /// impossible à choisir » dit au prospect quoi corriger ; « une erreur est
  /// survenue » le laisse recommencer à l'identique.
  final String? motif;
}
