import 'package:cga_mobile/domaine/mon_mois.dart';
import 'package:cga_mobile/ports/service_du_tableau_de_bord.dart';

/// Un serveur de test pour l'accueil connecté.
///
/// Chaque réponse se règle à la construction, et chaque appel est noté : on
/// vérifie ce que l'écran a DEMANDÉ, pas seulement ce qu'il affiche.
class TableauFeint implements ServiceDuTableauDeBord {
  TableauFeint({
    this.nom = 'Jean-Pierre NKOA',
    MonMois? mois,
    this.sortDeLaReponse = SortDeLaReponse.transmise,
  }) : mois = mois ?? moisAEnvoyer();

  String? nom;
  MonMois mois;
  SortDeLaReponse sortDeLaReponse;

  final moisDemandes = <String>[];
  final reponses = <(String, NatureDeReponse)>[];

  @override
  Future<String?> monNom() async => nom;

  @override
  Future<MonMois> monMois(String dossier) async {
    moisDemandes.add(dossier);
    return mois;
  }

  @override
  Future<SortDeLaReponse> repondre({
    required String demande,
    required NatureDeReponse nature,
  }) async {
    reponses.add((demande, nature));
    return sortDeLaReponse;
  }
}

/// Le mois du dossier d'essai tel que le serveur le rend : trois pièces
/// demandées, dont deux factures à corriger, toutes en retard.
MonMois moisAEnvoyer() => MonMois.depuisJson({
  'denomination': 'SARL BATIMENT PLUS',
  'nom_du_mois': 'août 2026',
  'bandeau': {
    'etat': 'A_ENVOYER',
    'titre': 'Il manque 3 justificatifs',
    'detail':
        'La date prévue est passée : envoyez-les dès que possible, le '
        'cabinet vous attend.',
  },
  'attendues': [
    {
      'demande': 'DP-2026-002',
      'libelle': 'Facture rectificative — F-2026-0424, SABLIÈRE DU MOUNGO',
      'attendue_pour': '2026-08-12',
      'en_retard': true,
      'bloquante': true,
      'a_corriger': true,
      'piece_a_rectifier': 'PJ-2026-0013',
      'reponse': null,
    },
    {
      'demande': 'DP-2026-010',
      'libelle': 'Relevé bancaire de juillet 2026',
      'attendue_pour': '2026-08-12',
      'en_retard': true,
      'bloquante': true,
      'a_corriger': false,
      'reponse': null,
    },
  ],
});
