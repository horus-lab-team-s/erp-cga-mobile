// Mes honoraires (18 octobre 2026) : régler une période par mobile money.
//
// ⚠️ CE QUI EST GARDÉ
// * la demande part avec la bonne période et le numéro, puis l'écran dit de
//   valider sur le téléphone, sans jamais marquer la période réglée lui-même ;
// * un numéro trop court ne part pas ; un refus du serveur se lit tel quel ;
// * la facture n'est proposée que si l'identité fiscale du cabinet est complète ;
// * sans contrat, sans réseau : l'écran le dit au lieu de montrer une liste vide.

import 'package:cga_mobile/composants/actions.dart';
import 'package:cga_mobile/domaine/honoraires.dart';
import 'package:cga_mobile/ecrans/honoraires.dart';
import 'package:cga_mobile/marque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soutien/espace_feint.dart';

void main() {
  final ouverts = <String>[];

  Future<void> poser(WidgetTester testeur, EspaceFeint espace) async {
    ouverts.clear();
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        // Une clé neuve à chaque pose : un second écran ne reprend pas l'état du premier.
        home: EcranHonoraires(
          key: UniqueKey(),
          espace: espace,
          dossiers: const ['M081234567890P'],
          quandSessionExpire: () {},
          ouvrirDocument: (chemin, titre) => ouverts.add(chemin),
        ),
      ),
    );
    await testeur.pumpAndSettle();
  }

  testWidgets(
    'La période en retard se règle, et l\'écran dit de valider sur le téléphone',
    (testeur) async {
      final espace = EspaceFeint(honoraires: honorairesDEssai());
      await poser(testeur, espace);

      expect(find.text('${montantFcfa(45000)} à régler'), findsOneWidget);
      await testeur.tap(find.byKey(const Key('payer-2026-09-01')));
      await testeur.pumpAndSettle();
      await testeur.enterText(
        find.byKey(const Key('numero-mobile-money')),
        '6 77 12 34 56',
      );
      await testeur.tap(find.byKey(const Key('confirmer-le-paiement')));
      await testeur.pumpAndSettle();

      expect(espace.debitsDemandes, ['2026-09-01:677123456']);
      expect(find.text('Validez sur votre téléphone'), findsOneWidget);
      expect(find.text('Démonstration : aucun débit réel'), findsOneWidget);
      final lecturesAvant = espace.lecturesDHonoraires;
      await testeur.tap(find.text('J\'ai compris'));
      await testeur.pumpAndSettle();
      // L'écran relit le serveur : c'est l'opérateur qui règle, pas le clic.
      expect(espace.lecturesDHonoraires, lecturesAvant + 1);
    },
  );

  testWidgets('Un numéro trop court ne part pas', (testeur) async {
    final espace = EspaceFeint(honoraires: honorairesDEssai());
    await poser(testeur, espace);

    await testeur.tap(find.byKey(const Key('payer-2026-09-01')));
    await testeur.pumpAndSettle();
    await testeur.enterText(
      find.byKey(const Key('numero-mobile-money')),
      '6771',
    );
    await testeur.tap(find.byKey(const Key('confirmer-le-paiement')));
    await testeur.pumpAndSettle();

    expect(espace.debitsDemandes, isEmpty);
    expect(find.textContaining('neuf chiffres au moins'), findsOneWidget);
  });

  testWidgets('Le refus du serveur se lit tel qu\'il l\'a écrit', (
    testeur,
  ) async {
    final espace = EspaceFeint(
      honoraires: honorairesDEssai(),
      debit: const DemandeDeDebit(
        sort: SortDuDebit.dejaEnCours,
        message: 'Une demande attend déjà votre validation.',
      ),
    );
    await poser(testeur, espace);

    await testeur.tap(find.byKey(const Key('payer-2026-09-01')));
    await testeur.pumpAndSettle();
    await testeur.enterText(
      find.byKey(const Key('numero-mobile-money')),
      '677123456',
    );
    await testeur.tap(find.byKey(const Key('confirmer-le-paiement')));
    await testeur.pumpAndSettle();

    expect(
      find.text('Une demande attend déjà votre validation.'),
      findsOneWidget,
    );
    expect(find.text('Validez sur votre téléphone'), findsNothing);
  });

  testWidgets('La facture n\'apparaît que lorsque le cabinet peut l\'émettre', (
    testeur,
  ) async {
    await poser(testeur, EspaceFeint(honoraires: honorairesDEssai()));
    await testeur.scrollUntilVisible(find.text('Reçu'), 200);
    expect(find.text('Reçu'), findsOneWidget);
    expect(find.text('Facture'), findsNothing);

    await poser(
      testeur,
      EspaceFeint(honoraires: honorairesDEssai(factureDisponible: true)),
    );
    await testeur.scrollUntilVisible(find.text('Facture'), 200);
    await testeur.tap(find.text('Facture'));
    expect(ouverts, [
      '/souscription/honoraires/M081234567890P/echeances/2026-08-01/facture',
    ]);
  });

  testWidgets('Sans contrat, et sans réseau, l\'écran le dit', (testeur) async {
    await poser(testeur, EspaceFeint(honoraires: MesHonoraires.sansContrat));
    expect(find.text('Aucun contrat d\'honoraires'), findsOneWidget);

    await poser(testeur, EspaceFeint());
    expect(find.text('Pas de réseau'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
