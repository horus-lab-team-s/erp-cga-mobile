// « Plus » (18 octobre 2026) : tout l'espace hors de la barre, à un toucher.
//
// ⚠️ CE QUI EST GARDÉ
// * chaque entrée mène à son écran ;
// * ce qui demande un geste porte une pastille, lue au serveur ;
// * se déconnecter demande confirmation.

import 'package:cga_mobile/composants/actions.dart';
import 'package:cga_mobile/domaine/ma_dsf.dart';
import 'package:cga_mobile/ecrans/plus.dart';
import 'package:cga_mobile/marque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soutien/espace_feint.dart';

void main() {
  testWidgets('Les entrées, leurs pastilles, et la déconnexion confirmée', (
    testeur,
  ) async {
    final ouverts = <String>[];
    var deconnecte = false;
    final espace = EspaceFeint(
      honoraires: honorairesDEssai(),
      dsf: MaDsf.depuis({
        'exercices': [
          {
            'exercice': '2025',
            'cloture': '2025-12-31',
            'etat': 'EN_PREPARATION',
            'a_fournir': 7,
            'pieces': [],
          },
          {
            'exercice': '2024',
            'cloture': '2024-12-31',
            'etat': 'EN_PREPARATION',
            'a_fournir': 8,
            'pieces': [],
          },
        ],
      }),
    );
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranPlus(
          espace: espace,
          dossier: 'M081234567890P',
          ouvrirHonoraires: () => ouverts.add('honoraires'),
          ouvrirMaDsf: () => ouverts.add('dsf'),
          ouvrirMaPaie: () => ouverts.add('paie'),
          ouvrirMonEntreprise: () => ouverts.add('entreprise'),
          ouvrirMesPieces: () => ouverts.add('pieces'),
          seDeconnecter: () async => deconnecte = true,
        ),
      ),
    );
    await testeur.pumpAndSettle();

    expect(find.text('${montantFcfa(45000)} à régler'), findsOneWidget);
    // ⚠️ L'exercice le plus récent, et non 7 + 8.
    expect(find.text('7 à fournir'), findsOneWidget);
    for (final cle in [
      'plus-honoraires',
      'plus-dsf',
      'plus-pieces',
      'plus-entreprise',
      'plus-paie',
    ]) {
      await testeur.ensureVisible(find.byKey(Key(cle)));
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(Key(cle)));
    }
    expect(ouverts, ['honoraires', 'dsf', 'pieces', 'entreprise', 'paie']);

    await testeur.ensureVisible(find.byKey(const Key('plus-deconnexion')));
    await testeur.pumpAndSettle();
    await testeur.tap(find.byKey(const Key('plus-deconnexion')));
    await testeur.pumpAndSettle();
    await testeur.tap(find.text('Annuler'));
    await testeur.pumpAndSettle();
    expect(deconnecte, isFalse);
    await testeur.tap(find.byKey(const Key('plus-deconnexion')));
    await testeur.pumpAndSettle();
    await testeur.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
    await testeur.pumpAndSettle();
    expect(deconnecte, isTrue);
  });
}
