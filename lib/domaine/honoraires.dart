/// Ce que l'adhérent doit au cabinet, période par période (18 octobre 2026).
///
/// Lu sur `GET /souscription/honoraires/{niu}`, la même route que l'espace web.
/// ⚠️ L'écran ne calcule rien : le dû, les retards et la situation arrivent
/// calculés. Un montant recopié ici divergerait le jour où le tarif est révisé.
library;

enum EtatDHonoraires {
  reglee,
  aRegler,
  enRetard,
  aVenir;

  String get libelle => switch (this) {
    EtatDHonoraires.reglee => 'Réglée',
    EtatDHonoraires.aRegler => 'À régler',
    EtatDHonoraires.enRetard => 'En retard',
    EtatDHonoraires.aVenir => 'À venir',
  };

  /// Ce qui se règle maintenant, depuis l'application.
  bool get due =>
      this == EtatDHonoraires.aRegler || this == EtatDHonoraires.enRetard;

  static EtatDHonoraires depuisLeServeur(String? nom) => switch (nom) {
    'REGLEE' => EtatDHonoraires.reglee,
    'A_REGLER' => EtatDHonoraires.aRegler,
    'EN_RETARD' => EtatDHonoraires.enRetard,
    _ => EtatDHonoraires.aVenir,
  };
}

/// Le règlement constaté d'une période : par l'opérateur, ou au guichet.
class ReglementDHonoraires {
  const ReglementDHonoraires({
    required this.identifiant,
    required this.constateLe,
    required this.parMobileMoney,
    required this.reference,
  });

  final String identifiant;
  final DateTime constateLe;
  final bool parMobileMoney;
  final String reference;

  static ReglementDHonoraires depuis(Map<String, dynamic> json) =>
      ReglementDHonoraires(
        identifiant: json['identifiant'] as String,
        constateLe: DateTime.parse(json['constate_le'] as String),
        parMobileMoney: json['canal'] == 'MOBILE_MONEY',
        reference: (json['reference_externe'] as String?) ?? '',
      );
}

class PeriodeDHonoraires {
  const PeriodeDHonoraires({
    required this.debut,
    required this.fin,
    required this.exigibleLe,
    required this.montant,
    required this.etat,
    this.reglement,
  });

  final DateTime debut;
  final DateTime fin;
  final DateTime exigibleLe;

  /// En francs CFA, entiers : le serveur rend des chaînes décimales.
  final int montant;
  final EtatDHonoraires etat;
  final ReglementDHonoraires? reglement;

  /// « 2026-08-01 » : ce que les routes de la note et de la facture attendent.
  String get cle => debut.toIso8601String().split('T').first;

  static PeriodeDHonoraires depuis(Map<String, dynamic> json) =>
      PeriodeDHonoraires(
        debut: DateTime.parse(json['debut'] as String),
        fin: DateTime.parse(json['fin'] as String),
        exigibleLe: DateTime.parse(json['exigible_le'] as String),
        montant: double.parse('${json['montant']}').round(),
        etat: EtatDHonoraires.depuisLeServeur(json['etat'] as String?),
        reglement: json['reglement'] is Map<String, dynamic>
            ? ReglementDHonoraires.depuis(
                json['reglement'] as Map<String, dynamic>,
              )
            : null,
      );
}

/// Où en est le dossier vis-à-vis du cabinet : en règle, en retard, bloqué.
enum SituationDeReglement {
  sansContrat,
  enRegle,
  enRetard,
  sousGrace,
  bloque;

  String get libelle => switch (this) {
    SituationDeReglement.sansContrat => 'Aucun contrat d\'honoraires',
    SituationDeReglement.enRegle => 'Vous êtes en règle',
    SituationDeReglement.enRetard => 'Un règlement est en retard',
    SituationDeReglement.sousGrace => 'Un délai vous est accordé',
    SituationDeReglement.bloque => 'Votre dossier est suspendu',
  };

  /// ⚠️ L'adhérent doit savoir que son dossier ne se traite plus, et pourquoi.
  String get explication => switch (this) {
    SituationDeReglement.sansContrat =>
      'Le cabinet ne vous a encore rien facturé.',
    SituationDeReglement.enRegle => 'Toutes vos périodes échues sont réglées.',
    SituationDeReglement.enRetard =>
      'Réglez la période en retard pour que le traitement continue sans interruption.',
    SituationDeReglement.sousGrace =>
      'Le cabinet continue de traiter votre dossier pendant ce délai. Réglez avant qu\'il expire.',
    SituationDeReglement.bloque =>
      'Le cabinet ne traite plus votre dossier tant que le retard n\'est pas réglé.',
  };

  static SituationDeReglement depuisLeServeur(String? nom) => switch (nom) {
    'EN_REGLE' => SituationDeReglement.enRegle,
    'EN_RETARD' => SituationDeReglement.enRetard,
    'SOUS_GRACE' => SituationDeReglement.sousGrace,
    'BLOQUE' => SituationDeReglement.bloque,
    _ => SituationDeReglement.sansContrat,
  };
}

class MesHonoraires {
  const MesHonoraires({
    required this.periodes,
    required this.du,
    required this.enRetard,
    required this.reglableEnLigne,
    required this.situation,
    required this.factureDisponible,
    this.montantParPeriode,
    this.periodicite,
  });

  /// Aucun contrat : l'écran le dit au lieu de montrer une liste vide.
  static const sansContrat = MesHonoraires(
    periodes: [],
    du: 0,
    enRetard: 0,
    reglableEnLigne: false,
    situation: SituationDeReglement.sansContrat,
    factureDisponible: false,
  );

  final List<PeriodeDHonoraires> periodes;
  final int du;
  final int enRetard;
  final bool reglableEnLigne;
  final SituationDeReglement situation;

  /// L'identité fiscale du cabinet est complète : la facture d'une période
  /// réglée s'émet. Sinon, la note d'honoraires reste le document.
  final bool factureDisponible;
  final int? montantParPeriode;
  final String? periodicite;

  bool get aUnContrat => montantParPeriode != null;

  List<PeriodeDHonoraires> get dues =>
      periodes.where((p) => p.etat.due).toList();

  /// La plus récente d'abord : c'est le reçu qu'on cherche le plus souvent.
  List<PeriodeDHonoraires> get reglees => periodes
      .where((p) => p.etat == EtatDHonoraires.reglee)
      .toList()
      .reversed
      .toList();

  List<PeriodeDHonoraires> get aVenir =>
      periodes.where((p) => p.etat == EtatDHonoraires.aVenir).toList();

  static MesHonoraires depuis(Map<String, dynamic> json) {
    final contrat = json['contrat'];
    if (contrat is! Map<String, dynamic>) return sansContrat;
    final situation = json['situation'];
    return MesHonoraires(
      periodes: [
        for (final p in (json['echeances'] as List? ?? const []))
          PeriodeDHonoraires.depuis(p as Map<String, dynamic>),
      ],
      du: double.parse('${json['du'] ?? 0}').round(),
      enRetard: (json['en_retard'] as num?)?.toInt() ?? 0,
      reglableEnLigne: json['reglable_en_ligne'] == true,
      situation: situation is Map<String, dynamic>
          ? SituationDeReglement.depuisLeServeur(situation['etat'] as String?)
          : SituationDeReglement.enRegle,
      factureDisponible: json['facture_disponible'] == true,
      montantParPeriode: double.parse('${contrat['montant']}').round(),
      periodicite: contrat['periodicite'] as String?,
    );
  }
}

/// Le sort d'une demande de débit mobile money.
///
/// ⚠️ « Envoyée » ne veut pas dire « payée » : l'adhérent valide sur son
/// téléphone, et c'est la notification de l'opérateur qui règle la période.
enum SortDuDebit { envoyee, refusee, dejaEnCours, sessionExpiree, indisponible }

class DemandeDeDebit {
  const DemandeDeDebit({required this.sort, this.message, this.simule = false});

  final SortDuDebit sort;

  /// Ce que le serveur dit : à afficher tel quel, il est écrit pour l'adhérent.
  final String? message;

  /// Aucun débit réel : la plateforme n'a pas encore ses identifiants marchands.
  final bool simule;
}
