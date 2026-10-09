/// Où en est une souscription, et ce que l'abonnement coûte mois après mois.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ QUATRE ÉTAPES, ET LA TROISIÈME EST CELLE QU'ON OUBLIE.
///
///   1. le paiement est demandé sur le téléphone ;
///   2. l'argent est arrivé ;
///   3. LE CABINET VÉRIFIE L'IDENTITÉ — pour une adhésion, qui ouvre l'accès
///      au dossier d'une entreprise. Un NIU se lit sur chaque facture : il ne
///      prouve pas qu'on représente l'entreprise ;
///   4. l'accès est ouvert, et le lien part par courriel.
///
/// Un écran qui passerait de « payé » à « accès ouvert » ferait attendre un
/// lien qui ne peut pas encore partir. L'adhérent rappellerait le cabinet en
/// croyant à une panne.
/// ─────────────────────────────────────────────────────────────────────────────
library;

enum EtatDeLaSouscription {
  enAttenteDePaiement,
  payee,
  activee,
  abandonnee,
  resiliee;

  static EtatDeLaSouscription depuis(String? code) => switch (code) {
    'PAYEE' => payee,
    'ACTIVEE' => activee,
    'ABANDONNEE' => abandonnee,
    'RESILIEE' => resiliee,
    _ => enAttenteDePaiement,
  };
}

class SuiviDeSouscription {
  const SuiviDeSouscription({
    required this.reference,
    required this.libelle,
    required this.etat,
    required this.ouvreUnAcces,
    required this.courriel,
    this.montant,
    this.abonnementMensuel,
    this.engageeLe,
    this.payeeLe,
    this.activeeLe,
    this.prendEffetLe,
    this.motif,
  });

  final String reference;
  final String libelle;
  final EtatDeLaSouscription etat;

  /// Vrai pour l'adhésion : elle ouvre l'accès à un dossier, donc passe par la
  /// vérification d'identité.
  final bool ouvreUnAcces;

  /// L'adresse où partira le lien d'accès : on la rappelle pour que le
  /// souscripteur sache où le chercher.
  final String courriel;
  final double? montant;
  final double? abonnementMensuel;
  final DateTime? engageeLe;
  final DateTime? payeeLe;
  final DateTime? activeeLe;
  final DateTime? prendEffetLe;

  /// Le motif d'un abandon ou d'une résiliation, tel que le serveur le donne.
  final String? motif;

  bool get estUnAbonnement => abonnementMensuel != null;

  static double? _nombre(Object? v) => v == null ? null : double.tryParse('$v');
  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse('$v');

  static SuiviDeSouscription depuisJson(Map<String, dynamic> j) {
    final p = j['prospect'];
    return SuiviDeSouscription(
      reference: j['reference'] as String,
      libelle: j['libelle'] as String? ?? '',
      etat: EtatDeLaSouscription.depuis(j['etat'] as String?),
      ouvreUnAcces: j['ouvre_un_acces'] as bool? ?? false,
      courriel: p is Map<String, dynamic> ? '${p['courriel'] ?? ''}' : '',
      montant: _nombre(j['montant']),
      abonnementMensuel: _nombre(j['abonnement_mensuel']),
      engageeLe: _date(j['engagee_le']),
      payeeLe: _date(j['payee_le']),
      activeeLe: _date(j['activee_le']),
      prendEffetLe: _date(j['prend_effet_le']),
      motif: j['motif'] as String?,
    );
  }
}

/// Ce que la lecture d'un suivi a produit.
enum SortDuSuivi { trouve, introuvable, indisponible }

class LectureDuSuivi {
  const LectureDuSuivi(this.sort, [this.suivi]);
  final SortDuSuivi sort;
  final SuiviDeSouscription? suivi;
}

/// Les états d'une mensualité, tels que le serveur les nomme.
enum EtatDeMensualite {
  reglee('Réglée'),
  enCours('Paiement en cours'),
  aAppeler('Demandée aujourd\'hui'),
  aVenir('À venir'),
  impayee('Impayée'),
  enDefaut('Service suspendu');

  const EtatDeMensualite(this.libelle);

  /// ⚠️ Un MOT pour chaque état : la couleur ne le dit jamais seule.
  final String libelle;

  static EtatDeMensualite depuis(String? code) => switch (code) {
    'REGLEE' => reglee,
    'EN_COURS' => enCours,
    'A_APPELER' => aAppeler,
    'IMPAYEE' => impayee,
    'EN_DEFAUT' => enDefaut,
    _ => aVenir,
  };

  bool get alerte => this == impayee || this == enDefaut;
}

class Mensualite {
  const Mensualite({
    required this.numero,
    required this.du,
    required this.au,
    required this.montant,
    required this.exigibleLe,
    required this.etat,
  });

  final int numero;
  final DateTime du;
  final DateTime au;
  final double montant;
  final DateTime exigibleLe;
  final EtatDeMensualite etat;

  static Mensualite depuisJson(Map<String, dynamic> j) => Mensualite(
    numero: (j['numero'] as num?)?.toInt() ?? 0,
    du: DateTime.parse(j['periode_debut'] as String),
    au: DateTime.parse(j['periode_fin'] as String),
    montant: double.tryParse('${j['montant']}') ?? 0,
    exigibleLe: DateTime.parse(j['exigible_le'] as String),
    etat: EtatDeMensualite.depuis(j['etat'] as String?),
  );
}
