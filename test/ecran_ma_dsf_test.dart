// Ma DSF (18 octobre 2026, point 24) : verser une pièce, suivre l'état.
//
// ⚠️ CE QUI EST GARDÉ
// * une pièce à fournir se photographie et part ; la ligne se relit au serveur ;
// * une photo trop lourde se dit en clair, sans rien relire ;
// * une DSF déposée n'offre plus d'envoi, mais sa copie ;
// * le compte « à fournir » est celui de l'exercice, pas une somme d'exercices.

import 'dart:io';

import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/ma_dsf.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:cga_mobile/ecrans/ma_dsf.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/appareil_photo.dart';
import 'package:cga_mobile/ports/service_de_l_espace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soutien/espace_feint.dart';

class _AppareilQuiPhotographie implements AppareilPhoto {
  _AppareilQuiPhotographie(this.photo);
  final File photo;

  @override
  Future<String?> photographier() async => photo.path;
}

MaDsf _dsf({String etat = 'EN_PREPARATION'}) => MaDsf.depuis({
  'exercices': [
    {
      'exercice': '2025',
      'cloture': '2025-12-31',
      'etat': etat,
      'numero_accuse': etat == 'DEPOSEE' ? 'DGI-2026-DSF-001' : null,
      'deposee_le': etat == 'DEPOSEE' ? '2026-03-12T15:00:00' : null,
      'document': etat == 'DEPOSEE',
      'a_fournir': etat == 'DEPOSEE' ? 0 : 1,
      'pieces': [
        {
          'numero': 1,
          'libelle': 'Attestation de visa',
          'etat': etat == 'DEPOSEE' ? 'JOINTE' : 'A_FOURNIR',
          'nom_du_fichier': etat == 'DEPOSEE' ? 'visa.pdf' : null,
          'versable': etat != 'DEPOSEE',
        },
        {
          'numero': 2,
          'libelle': 'Balance auxiliaire clients',
          'etat': 'PRODUITE',
          'nom_du_fichier': null,
          'versable': false,
        },
      ],
    },
  ],
});

void main() {
  late Directory racine;
  late PriseDeVue prise;

  setUp(() async {
    racine = await Directory.systemTemp.createTemp('ma-dsf');
    final photo = File('${racine.path}/visa.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    prise = PriseDeVue(
      appareil: _AppareilQuiPhotographie(photo),
      file: FileDAttente(MagasinEnMemoire()),
      photos: Directory('${racine.path}/photos'),
    );
  });

  tearDown(() => racine.delete(recursive: true));

  Future<List<String>> poser(WidgetTester testeur, EspaceFeint espace) async {
    final ouverts = <String>[];
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranMaDsf(
          key: UniqueKey(),
          espace: espace,
          dossiers: const ['M081234567890P'],
          priseDeVue: prise,
          quandSessionExpire: () {},
          ouvrirDocument: (chemin, _) => ouverts.add(chemin),
        ),
      ),
    );
    await testeur.pumpAndSettle();
    return ouverts;
  }

  testWidgets('Une pièce à fournir se photographie et part au cabinet', (
    testeur,
  ) async {
    final espace = EspaceFeint(dsf: _dsf());
    await poser(testeur, espace);

    expect(find.text('1 à fournir'), findsOneWidget);
    expect(find.textContaining('Établies par le cabinet'), findsOneWidget);
    await testeur.runAsync(() async {
      await testeur.tap(find.byKey(const Key('verser-1')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await testeur.pumpAndSettle();

    expect(espace.versements, ['2025/1']);
    expect(find.textContaining('est bien arrivée au cabinet'), findsOneWidget);
  });

  testWidgets('Une photo trop lourde se dit en clair', (testeur) async {
    final espace = EspaceFeint(
      dsf: _dsf(),
      versement: SortDuVersement.tropLourde,
    );
    await poser(testeur, espace);

    await testeur.runAsync(() async {
      await testeur.tap(find.byKey(const Key('verser-1')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await testeur.pumpAndSettle();

    expect(find.textContaining('dépasse 15 Mo'), findsOneWidget);
  });

  testWidgets('Déposée, la DSF n\'offre plus d\'envoi, mais sa copie', (
    testeur,
  ) async {
    final ouverts = await poser(
      testeur,
      EspaceFeint(dsf: _dsf(etat: 'DEPOSEE')),
    );

    expect(find.byKey(const Key('verser-1')), findsNothing);
    expect(find.text('Accusé de la DGI n° DGI-2026-DSF-001'), findsOneWidget);
    await testeur.tap(find.text('Voir la copie déposée'));
    expect(ouverts, ['/cloture/dossiers/M081234567890P/ma-dsf/2025/document']);
  });

  testWidgets('Déposée, elle ne dit plus « à fournir » ce qui ne manque plus', (
    testeur,
  ) async {
    // 18 octobre 2026 : connue par son seul accusé, une DSF déposée montrait encore
    // ses pièces « à fournir », cercles vides, comme si quelque chose manquait.
    final dsf = MaDsf.depuis({
      'exercices': [
        {
          'exercice': '2025',
          'cloture': '2025-12-31',
          'etat': 'DEPOSEE',
          'numero_accuse': 'DGI-2025-DSF-563648',
          'deposee_le': '2026-05-13T10:00:00',
          'document': false,
          'a_fournir': 0,
          'pieces': [
            {
              'numero': 1,
              'libelle': 'Attestation de visa',
              'etat': 'A_FOURNIR',
              'nom_du_fichier': null,
              'versable': false,
            },
            {
              'numero': 11,
              'libelle': 'État des stocks',
              'etat': 'JOINTE',
              'nom_du_fichier': 'stocks.jpg',
              'versable': false,
            },
          ],
        },
      ],
    });
    await poser(testeur, EspaceFeint(dsf: dsf));

    expect(find.text('Attestation de visa'), findsNothing);
    expect(find.text('État des stocks'), findsOneWidget);
  });
}
