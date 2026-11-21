/// Ma paie : le personnel et la déclaration du mois clos (18 octobre 2026).
///
/// Lu sur `GET /social/dossiers/{niu}/salaries` et `.../declaration/{a}/{m}`, les
/// routes de l'espace web. ⚠️ L'écran ne calcule rien : le brut, les retenues,
/// le net et ce qu'il faut verser arrivent calculés par le serveur.
library;

class SalarieDeLaPaie {
  const SalarieDeLaPaie({
    required this.matricule,
    required this.nomComplet,
    this.poste,
    required this.sansContrat,
  });

  final String matricule;
  final String nomComplet;
  final String? poste;
  final bool sansContrat;

  static SalarieDeLaPaie depuis(Map<String, dynamic> json) => SalarieDeLaPaie(
    matricule: json['matricule'] as String,
    nomComplet: '${json['prenom'] ?? ''} ${json['nom'] ?? ''}'.trim(),
    poste: json['poste'] as String?,
    sansContrat: json['sans_contrat'] == true,
  );
}

class BulletinDuMois {
  const BulletinDuMois({
    required this.matricule,
    required this.brut,
    required this.net,
    required this.coutEmployeur,
    required this.alertes,
  });

  final String matricule;
  final int brut;
  final int net;
  final int coutEmployeur;
  final List<String> alertes;

  static int _f(Object? v) => double.parse('${v ?? 0}').round();

  static BulletinDuMois depuis(Map<String, dynamic> json) => BulletinDuMois(
    matricule: json['salarie'] as String,
    brut: _f(json['brut_taxable']),
    net: _f(json['net_a_payer']),
    coutEmployeur: _f(json['cout_employeur']),
    alertes: [for (final a in (json['alertes'] as List? ?? const [])) '$a'],
  );
}

class MaPaie {
  const MaPaie({
    required this.annee,
    required this.mois,
    required this.salaries,
    required this.effectif,
    required this.masseBrute,
    required this.totalAVerser,
    required this.cotisationsCnps,
    required this.aDeposerAvant,
    required this.enRetard,
    required this.bulletins,
  });

  final int annee;
  final int mois;
  final List<SalarieDeLaPaie> salaries;
  final int effectif;
  final int masseBrute;

  /// Retenues salariales et charges patronales : ce que l'entreprise verse.
  final int totalAVerser;
  final int cotisationsCnps;
  final DateTime? aDeposerAvant;
  final bool enRetard;
  final List<BulletinDuMois> bulletins;

  String nomDe(String matricule) =>
      salaries.where((s) => s.matricule == matricule).firstOrNull?.nomComplet ??
      matricule;

  /// ⚠️ LE MOIS CLOS, PAS LE MOIS COURANT : une déclaration du mois en cours est
  /// incomplète par construction, et ferait croire à un effectif qui a fondu.
  static (int, int) moisParDefaut(DateTime aujourdHui) => aujourdHui.month == 1
      ? (aujourdHui.year - 1, 12)
      : (aujourdHui.year, aujourdHui.month - 1);

  static MaPaie depuis({
    required int annee,
    required int mois,
    required List<dynamic> personnel,
    required Map<String, dynamic> declaration,
  }) {
    int f(Object? v) => double.parse('${v ?? 0}').round();
    final avant = declaration['a_deposer_avant'];
    return MaPaie(
      annee: annee,
      mois: mois,
      salaries: [
        for (final s in personnel)
          SalarieDeLaPaie.depuis(s as Map<String, dynamic>),
      ],
      effectif: (declaration['effectif'] as num?)?.toInt() ?? 0,
      masseBrute: f(declaration['masse_salariale_brute']),
      totalAVerser: f(declaration['total_a_verser']),
      cotisationsCnps: f(declaration['cotisations_cnps']),
      aDeposerAvant: avant == null ? null : DateTime.parse(avant as String),
      enRetard: declaration['en_retard'] == true,
      bulletins: [
        for (final b in (declaration['bulletins'] as List? ?? const []))
          BulletinDuMois.depuis(b as Map<String, dynamic>),
      ],
    );
  }
}
