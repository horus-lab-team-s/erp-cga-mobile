// Ma paie (18 octobre 2026) : le mois clos, ce qu'il faut verser, les bulletins.
//
// ⚠️ CE QUI EST GARDÉ
// * le mois par défaut est le mois clos, et l'avenir ne s'ouvre pas ;
// * les montants sont ceux du serveur, les noms ceux du personnel.

import 'package:cga_mobile/composants/actions.dart';
import 'package:cga_mobile/domaine/ma_paie.dart';
import 'package:cga_mobile/ecrans/ma_paie.dart';
import 'package:cga_mobile/marque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soutien/espace_feint.dart';

MaPaie _paie() => MaPaie.depuis(
  annee: 2026,
  mois: 9,
  personnel: [
    {
      'matricule': 'S-1',
      'nom': 'NKOULOU',
      'prenom': 'Alphonse',
      'sans_contrat': false,
    },
  ],
  declaration: {
    'effectif': 1,
    'masse_salariale_brute': '495000',
    'total_a_verser': '191962',
    'cotisations_cnps': '110618',
    'a_deposer_avant': '2026-10-15',
    'en_retard': true,
    'bulletins': [
      {
        'salarie': 'S-1',
        'brut_taxable': '495000',
        'net_a_payer': '374715',
        'cout_employeur': '560000',
        'alertes': [],
      },
    ],
  },
);

void main() {
  testWidgets('Le mois clos, ce qu\'il faut verser, et le bulletin nommé', (
    testeur,
  ) async {
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranMaPaie(
          espace: EspaceFeint(paie: _paie()),
          dossiers: const ['M081234567890P'],
          quandSessionExpire: () {},
          aujourdHui: DateTime(2026, 10, 18),
        ),
      ),
    );
    await testeur.pumpAndSettle();

    expect(find.text('Septembre 2026'), findsOneWidget);
    expect(find.text('${montantFcfa(191962)} à verser'), findsOneWidget);
    expect(
      find.textContaining('devait partir avant le 15 octobre 2026'),
      findsOneWidget,
    );
    expect(find.text('Alphonse NKOULOU'), findsOneWidget);
    expect(find.text(montantFcfa(374715)), findsOneWidget);
    // L'avenir ne s'ouvre pas : le mois suivant est désactivé.
    final suivant = testeur.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(suivant.onPressed, isNull);
  });

  test('Le mois par défaut est le mois clos, janvier compris', () {
    expect(MaPaie.moisParDefaut(DateTime(2026, 10, 18)), (2026, 9));
    expect(MaPaie.moisParDefaut(DateTime(2027, 1, 5)), (2026, 12));
  });
}
