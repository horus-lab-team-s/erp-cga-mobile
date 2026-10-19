// Le banc d'aperçus : chaque écran rendu en PNG, à la taille d'un téléphone
// (18 octobre 2026).
//
// ─────────────────────────────────────────────────────────────────────────────
// POURQUOI CE BANC
//
// Le design se juge à l'œil, et le téléphone n'est pas toujours branché. Ce banc
// rend les écrans avec les VRAIES polices de la marque (Poppins, Inter) et les
// icônes Material, à 390 × 844 points, sur des données de démonstration, et les
// écrit en PNG. Il ne vérifie rien : il montre.
//
// ⚠️ IL NE TOURNE QUE SUR DEMANDE, pour ne pas alourdir la suite ordinaire :
//
//     APERCUS=/chemin/du/dossier flutter test test/apercus/apercus_test.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:ui' as ui;

import 'package:cga_mobile/domaine/document_recu.dart';
import 'package:cga_mobile/domaine/echeance.dart';
import 'package:cga_mobile/domaine/fonds_confies.dart';
import 'package:cga_mobile/domaine/ma_dsf.dart';
import 'package:cga_mobile/domaine/ma_paie.dart';
import 'package:cga_mobile/ecrans/documents.dart';
import 'package:cga_mobile/ecrans/echeances.dart';
import 'package:cga_mobile/ecrans/honoraires.dart';
import 'package:cga_mobile/ecrans/ma_dsf.dart';
import 'package:cga_mobile/ecrans/ma_paie.dart';
import 'package:cga_mobile/ecrans/plus.dart';
import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/appareil_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ecran_documents_test.dart' as documents_test;
import '../ecran_echeances_test.dart' as echeances_test;
import '../soutien/espace_feint.dart';

final _sortie = Platform.environment['APERCUS'];

class _SansPhoto implements AppareilPhoto {
  @override
  Future<String?> photographier() async => null;
}

Future<void> _chargerLesPolices() async {
  Future<void> famille(String nom, List<String> fichiers) async {
    final chargeur = FontLoader(nom);
    for (final f in fichiers) {
      chargeur.addFont(rootBundle.load('assets/polices/$f'));
    }
    await chargeur.load();
  }

  await famille('Inter', [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]);
  await famille('Poppins', [
    'Poppins-Regular.ttf',
    'Poppins-Medium.ttf',
    'Poppins-SemiBold.ttf',
    'Poppins-Bold.ttf',
  ]);
  final racine =
      Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/flutter';
  final icones = File(
    '$racine/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icones.existsSync()) {
    final chargeur = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icones.readAsBytesSync())));
    await chargeur.load();
  }
}

Future<void> _photographier(
  WidgetTester testeur,
  String nom,
  Widget ecran,
) async {
  final cle = GlobalKey();
  testeur.view.physicalSize = const Size(390 * 2, 844 * 2);
  testeur.view.devicePixelRatio = 2;
  await testeur.pumpWidget(
    RepaintBoundary(
      key: cle,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // SOMBRE=1 : le même écran en thème sombre (19 octobre 2026).
        theme: Platform.environment['SOMBRE'] == '1'
            ? themeSombre()
            : themeClair(),
        home: ecran,
      ),
    ),
  );
  await testeur.pumpAndSettle();
  await testeur.runAsync(() async {
    final limite =
        cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await limite.toImage(pixelRatio: 2);
    final octets = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_sortie/$nom.png').writeAsBytesSync(octets!.buffer.asUint8List());
  });
}

Echeance _echeance(
  String code,
  String titre,
  String etat, {
  int jours = 64,
  int autres = 0,
}) => Echeance.depuisJson({
  'code_obligation': code,
  'titre': titre,
  'periode': 'juillet 2026',
  'periode_debut': '2026-07-01',
  'periode_fin': '2026-07-31',
  'echeance': '2026-08-15',
  'etat': etat,
  'jours': jours,
  'autres_periodes_en_retard': autres,
  'de_quoi_s_agit_il': 'Les cotisations sociales de vos salariés.',
});

void main() {
  setUpAll(() async {
    final sortie = _sortie;
    if (sortie != null) {
      Directory(sortie).createSync(recursive: true);
      await _chargerLesPolices();
    }
  });

  final passer = _sortie == null
      ? 'APERCUS non défini : banc d\'aperçus non joué'
      : null;
  final prise = PriseDeVue(
    appareil: _SansPhoto(),
    file: FileDAttente(MagasinEnMemoire()),
    photos: Directory.systemTemp,
  );
  final espace = EspaceFeint(
    honoraires: honorairesDEssai(factureDisponible: true),
    fonds: FondsConfies.depuis({
      'obligations_mandatees': ['CNPS'],
      'appels': [
        {
          'identifiant': 'AF-1',
          'code_obligation': 'CNPS',
          'libelle': 'Cotisations sociales CNPS',
          'periode_debut': '2026-07-01',
          'montant': '110618',
          'etat': 'A_REGLER',
        },
      ],
    }),
    dsf: MaDsf.depuis({
      'exercices': [
        {
          'exercice': '2025',
          'cloture': '2025-12-31',
          'etat': 'EN_PREPARATION',
          'a_fournir': 2,
          'document': false,
          'pieces': [
            {
              'numero': 1,
              'libelle': 'Attestation de visa',
              'etat': 'JOINTE',
              'nom_du_fichier': 'visa.pdf',
              'versable': true,
            },
            {
              'numero': 4,
              'libelle': 'Déclaration des dépenses fiscales',
              'etat': 'A_FOURNIR',
              'versable': true,
            },
            {
              'numero': 6,
              'libelle': 'DIPE (personnel employé)',
              'etat': 'A_FOURNIR',
              'versable': true,
            },
            {
              'numero': 2,
              'libelle': 'Balance auxiliaire clients',
              'etat': 'PRODUITE',
              'versable': false,
            },
          ],
        },
        {
          'exercice': '2024',
          'cloture': '2024-12-31',
          'etat': 'DEPOSEE',
          'a_fournir': 0,
          'document': true,
          'numero_accuse': 'DGI-2025-DSF-0412',
          'deposee_le': '2025-03-10T10:00:00',
          'pieces': [],
        },
      ],
    }),
    paie: MaPaie.depuis(
      annee: 2026,
      mois: 9,
      personnel: [
        {'matricule': 'S-1', 'nom': 'NKOULOU', 'prenom': 'Alphonse'},
        {'matricule': 'S-2', 'nom': 'TSANGA', 'prenom': 'Marie'},
      ],
      declaration: {
        'effectif': 2,
        'masse_salariale_brute': '645000',
        'total_a_verser': '191962',
        'cotisations_cnps': '110618',
        'a_deposer_avant': '2026-10-15',
        'en_retard': false,
        'bulletins': [
          {
            'salarie': 'S-1',
            'brut_taxable': '495000',
            'net_a_payer': '374715',
            'cout_employeur': '560000',
          },
          {
            'salarie': 'S-2',
            'brut_taxable': '150000',
            'net_a_payer': '132976',
            'cout_employeur': '170000',
          },
        ],
      },
    ),
  );
  const dossiers = ['M081234567890P'];

  testWidgets('Mes honoraires', skip: passer != null, (t) async {
    await _photographier(
      t,
      'honoraires',
      EcranHonoraires(
        espace: espace,
        dossier: dossiers.first,
        quandSessionExpire: () {},
        ouvrirDocument: (_, _) {},
      ),
    );
  });

  testWidgets('Plus', skip: passer != null, (t) async {
    await _photographier(
      t,
      'plus',
      EcranPlus(
        espace: espace,
        dossier: dossiers.first,
        ouvrirHonoraires: () {},
        ouvrirMaDsf: () {},
        ouvrirMaPaie: () {},
        ouvrirMonEntreprise: () {},
        ouvrirMesPieces: () {},
        seDeconnecter: () async {},
      ),
    );
  });

  testWidgets('Ma DSF', skip: passer != null, (t) async {
    await _photographier(
      t,
      'ma-dsf',
      EcranMaDsf(
        espace: espace,
        dossier: dossiers.first,
        priseDeVue: prise,
        quandSessionExpire: () {},
        ouvrirDocument: (_, _) {},
      ),
    );
  });

  testWidgets('Ma paie', skip: passer != null, (t) async {
    await _photographier(
      t,
      'ma-paie',
      EcranMaPaie(
        espace: espace,
        dossier: dossiers.first,
        quandSessionExpire: () {},
        aujourdHui: DateTime(2026, 10, 18),
      ),
    );
  });

  testWidgets('Mes échéances', skip: passer != null, (t) async {
    final session = echeances_test.SessionFeinte(
      echeancier: Echeancier(
        echeances: [
          _echeance('CNPS', 'Cotisations sociales CNPS', 'EN_RETARD'),
          _echeance('TVA', 'TVA du mois', 'EN_RETARD', autres: 2),
          _echeance('IGS', 'Impôt général synthétique', 'A_VENIR', jours: 0),
        ],
      ),
    );
    await _photographier(
      t,
      'echeances',
      EcranEcheances(
        session: session,
        dossier: dossiers.first,
        quandSessionExpire: () {},
        priseDeVue: prise,
        espace: espace,
      ),
    );
  });

  testWidgets('Mes documents', skip: passer != null, (t) async {
    final session = documents_test.SessionFeinte(
      documents: Documents(
        documents: [
          documents_test.document(),
          documents_test.document(
            numero: 'CNPS-2026-08-118941',
            titre: 'Cotisations sociales CNPS',
            periode: 'août 2026',
            guichet: 'CNPS',
            deposeLe: '2026-09-13T09:00:00',
            montant: '412500',
          ),
          documents_test.document(
            numero: 'DGI-2026-07-0931',
            titre: 'Acompte d\'impôt sur le revenu',
            periode: 'juillet 2026',
            deposeLe: '2026-08-14T09:00:00',
            montant: '86000',
          ),
        ],
      ),
    );
    await _photographier(
      t,
      'documents',
      EcranDocuments(
        session: session,
        dossier: dossiers.first,
        quandSessionExpire: () {},
        ouvrirLHistorique: () {},
        ouvrirLeRecu: (_, _) {},
      ),
    );
  });
}
