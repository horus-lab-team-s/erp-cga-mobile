/// Ce que l'adhérent dit de sa pièce au moment de la déposer (19 octobre 2026).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// TOUT EST FACULTATIF, ET C'EST VOULU
///
/// L'adhérent qui a la facture en main sait souvent ce que le comptable cherchera :
/// qui l'a émise, son numéro, son montant. Le dire tout de suite épargne au cabinet de
/// le relire sur une photo floue. Mais l'exiger ferait renoncer au dépôt : une pièce
/// sans précisions vaut mieux qu'une pièce jamais envoyée.
///
/// Ce sont des DÉCLARATIONS : le cabinet les relit et les corrige. Elles préremplissent
/// la fiche de la pièce, rien de plus.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// La nature d'une pièce, telle que le serveur la connaît (`TypePiece`).
enum NatureDeLaPiece {
  factureAchat('FACTURE_ACHAT', "Facture d'achat"),
  factureVente('FACTURE_VENTE', 'Facture de vente'),
  recu('RECU', 'Reçu'),
  releveBancaire('RELEVE_BANCAIRE', 'Relevé bancaire'),
  releveMobileMoney('RELEVE_MOBILE_MONEY', 'Relevé mobile money'),
  autre('AUTRE', 'Autre');

  const NatureDeLaPiece(this.code, this.libelle);

  final String code;
  final String libelle;

  static NatureDeLaPiece? depuisLeCode(String? code) {
    for (final n in values) {
      if (n.code == code) return n;
    }
    return null;
  }
}

class ConnaissanceDeLaPiece {
  const ConnaissanceDeLaPiece({
    this.nature,
    this.emetteur,
    this.reference,
    this.dateDuDocument,
    this.montantTtc,
    this.note,
  });

  final NatureDeLaPiece? nature;

  /// Le fournisseur sur une facture d'achat, le client sur une facture de vente.
  final String? emetteur;

  /// Le numéro porté par le document : « FA-2026-0815 ».
  final String? reference;

  final DateTime? dateDuDocument;

  /// En francs CFA, toutes taxes comprises : le montant qui se lit en bas de page.
  final int? montantTtc;

  /// Un mot pour le comptable : « payée en espèces », « avoir sur la facture 412 ».
  final String? note;

  bool get vide =>
      nature == null &&
      (emetteur ?? '').isEmpty &&
      (reference ?? '').isEmpty &&
      dateDuDocument == null &&
      montantTtc == null &&
      (note ?? '').isEmpty;

  /// Ce qui part au serveur, avec les noms de `DepotDePiece`. Rien de vide ne part.
  Map<String, dynamic> versLaRemise() => {
    if (nature != null) 'type': nature!.code,
    if ((emetteur ?? '').trim().isNotEmpty) 'emetteur': emetteur!.trim(),
    if ((reference ?? '').trim().isNotEmpty)
      'reference_document': reference!.trim(),
    if (dateDuDocument != null)
      'date_document': dateDuDocument!.toIso8601String().split('T').first,
    if (montantTtc != null) 'montant_ttc': montantTtc,
    if ((note ?? '').trim().isNotEmpty) 'commentaire': note!.trim(),
  };

  Map<String, dynamic> versJson() => {
    if (nature != null) 'nature': nature!.code,
    if (emetteur != null) 'emetteur': emetteur,
    if (reference != null) 'reference': reference,
    if (dateDuDocument != null)
      'date_du_document': dateDuDocument!.toIso8601String(),
    if (montantTtc != null) 'montant_ttc': montantTtc,
    if (note != null) 'note': note,
  };

  static ConnaissanceDeLaPiece depuisJson(Map<String, dynamic> j) =>
      ConnaissanceDeLaPiece(
        nature: NatureDeLaPiece.depuisLeCode(j['nature'] as String?),
        emetteur: j['emetteur'] as String?,
        reference: j['reference'] as String?,
        dateDuDocument: j['date_du_document'] == null
            ? null
            : DateTime.parse(j['date_du_document'] as String),
        montantTtc: j['montant_ttc'] as int?,
        note: j['note'] as String?,
      );
}
