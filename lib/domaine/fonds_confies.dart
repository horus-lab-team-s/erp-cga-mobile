/// « Le cabinet paie pour moi » : les fonds confiés au cabinet (18 octobre 2026).
///
/// Lu sur `GET /souscription/fonds-de-tiers/{niu}`. Sous mandat de paiement, le
/// cabinet arrête le montant d'une échéance (un « appel de fonds ») ; l'adhérent
/// le règle par mobile money, depuis son téléphone ; le cabinet paie
/// l'administration et porte la quittance.
///
/// ⚠️ C'EST LA VOIE OÙ L'ADHÉRENT N'A RIEN À PHOTOGRAPHIER : la quittance est
/// celle que le cabinet obtient en payant.
library;

enum EtatDeLAppel {
  aRegler,
  fondsRecus,
  reverse;

  static EtatDeLAppel depuisLeServeur(String? nom) => switch (nom) {
    'FONDS_RECUS' => EtatDeLAppel.fondsRecus,
    'REVERSE' => EtatDeLAppel.reverse,
    _ => EtatDeLAppel.aRegler,
  };
}

class AppelDeFonds {
  const AppelDeFonds({
    required this.identifiant,
    required this.codeObligation,
    required this.libelle,
    required this.periodeDebut,
    required this.montant,
    required this.etat,
    this.fondsRecusLe,
    this.reverseLe,
  });

  final String identifiant;
  final String codeObligation;
  final String libelle;
  final DateTime periodeDebut;
  final int montant;
  final EtatDeLAppel etat;
  final DateTime? fondsRecusLe;
  final DateTime? reverseLe;

  static DateTime? _instant(Object? v) =>
      v is String ? DateTime.parse(v) : null;

  static AppelDeFonds depuis(Map<String, dynamic> json) => AppelDeFonds(
    identifiant: json['identifiant'] as String,
    codeObligation: json['code_obligation'] as String,
    libelle: json['libelle'] as String? ?? '',
    periodeDebut: DateTime.parse(json['periode_debut'] as String),
    montant: double.parse('${json['montant']}').round(),
    etat: EtatDeLAppel.depuisLeServeur(json['etat'] as String?),
    fondsRecusLe: _instant(json['fonds_recus_le']),
    reverseLe: _instant(json['reverse_le']),
  );
}

class FondsConfies {
  const FondsConfies({
    this.obligationsMandatees = const [],
    this.appels = const [],
  });

  /// Aucun mandat : l'adhérent paie lui-même, et envoie sa quittance.
  static const aucun = FondsConfies();

  final List<String> obligationsMandatees;
  final List<AppelDeFonds> appels;

  bool mandate(String codeObligation) =>
      obligationsMandatees.contains(codeObligation);

  /// L'appel d'une échéance : même obligation, même début de période.
  AppelDeFonds? appelPour(String codeObligation, DateTime periodeDebut) =>
      appels
          .where(
            (a) =>
                a.codeObligation == codeObligation &&
                a.periodeDebut.year == periodeDebut.year &&
                a.periodeDebut.month == periodeDebut.month &&
                a.periodeDebut.day == periodeDebut.day,
          )
          .firstOrNull;

  static FondsConfies depuis(Map<String, dynamic> json) => FondsConfies(
    obligationsMandatees: [
      for (final c in (json['obligations_mandatees'] as List? ?? const []))
        '$c',
    ],
    appels: [
      for (final a in (json['appels'] as List? ?? const []))
        AppelDeFonds.depuis(a as Map<String, dynamic>),
    ],
  );
}
