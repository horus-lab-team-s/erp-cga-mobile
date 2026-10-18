import 'dart:typed_data';

import 'package:cga_mobile/domaine/fonds_confies.dart';
import 'package:cga_mobile/domaine/honoraires.dart';
import 'package:cga_mobile/domaine/ma_dsf.dart';
import 'package:cga_mobile/domaine/ma_paie.dart';
import 'package:cga_mobile/ports/service_de_l_espace.dart';
import 'package:cga_mobile/ports/service_des_fichiers.dart';

/// Une doublure de l'espace adhérent : chaque réponse se règle par le test.
class EspaceFeint implements ServiceDeLEspace {
  EspaceFeint({
    this.honoraires,
    this.dsf,
    this.paie,
    this.debit = const DemandeDeDebit(sort: SortDuDebit.envoyee, simule: true),
    this.versement = SortDuVersement.recue,
    this.fonds = FondsConfies.aucun,
  });

  MesHonoraires? honoraires;
  MaDsf? dsf;
  MaPaie? paie;
  DemandeDeDebit debit;
  SortDuVersement versement;

  final List<String> debitsDemandes = [];
  final List<String> versements = [];
  final List<String> documentsLus = [];
  int lecturesDHonoraires = 0;

  @override
  Future<Lecture<MesHonoraires>> mesHonoraires(String dossier) async {
    lecturesDHonoraires++;
    final h = honoraires;
    return h == null ? const Lecture.injoignable() : Lecture.lue(h);
  }

  @override
  Future<DemandeDeDebit> demanderLeDebit({
    required String dossier,
    required String periode,
    required String telephone,
  }) async {
    debitsDemandes.add('$periode:$telephone');
    return debit;
  }

  @override
  Future<Lecture<MaDsf>> maDsf(String dossier) async {
    final d = dsf;
    return d == null ? const Lecture.injoignable() : Lecture.lue(d);
  }

  @override
  Future<SortDuVersement> verserUnePieceDsf({
    required String dossier,
    required String exercice,
    required int numero,
    required String cheminDuFichier,
  }) async {
    versements.add('$exercice/$numero');
    return versement;
  }

  @override
  Future<Lecture<MaPaie>> maPaie(
    String dossier, {
    required int annee,
    required int mois,
  }) async {
    final p = paie;
    return p == null ? const Lecture.injoignable() : Lecture.lue(p);
  }

  FondsConfies? fonds;
  final List<String> fondsConfies = [];

  @override
  Future<Lecture<FondsConfies>> mesFondsConfies(String dossier) async {
    final f = fonds;
    return f == null ? const Lecture.injoignable() : Lecture.lue(f);
  }

  @override
  Future<DemandeDeDebit> confierSesFonds({
    required String dossier,
    required String appel,
    required String telephone,
  }) async {
    fondsConfies.add('$appel:$telephone');
    return debit;
  }

  @override
  Future<FichierLu> lireUnDocument(String chemin) async {
    documentsLus.add(chemin);
    return FichierLu(octets: Uint8List(0), type: 'application/pdf');
  }
}

/// Deux périodes : août réglée, septembre en retard.
MesHonoraires honorairesDEssai({bool factureDisponible = false}) =>
    MesHonoraires.depuis({
      'contrat': {'montant': '45000', 'periodicite': 'MENSUELLE'},
      'echeances': [
        {
          'debut': '2026-08-01',
          'fin': '2026-08-31',
          'exigible_le': '2026-08-13',
          'montant': '45000',
          'etat': 'REGLEE',
          'reglement': {
            'identifiant': 'RH-1',
            'constate_le': '2026-08-13T10:00:00',
            'canal': 'GUICHET',
            'reference_externe': 'Reçu de caisse 2026-0105',
          },
        },
        {
          'debut': '2026-09-01',
          'fin': '2026-09-30',
          'exigible_le': '2026-09-13',
          'montant': '45000',
          'etat': 'EN_RETARD',
        },
      ],
      'du': '45000',
      'en_retard': 1,
      'reglable_en_ligne': true,
      'situation': {'etat': 'EN_RETARD'},
      'facture_disponible': factureDisponible,
    });
