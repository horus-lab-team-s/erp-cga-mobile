import 'package:cga_mobile/domaine/suivi.dart';
import 'package:cga_mobile/ecrans/suivi.dart';
import 'package:cga_mobile/marque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soutien/public_feint.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// LE SUIVI D'UNE SOUSCRIPTION
///
/// Les réponses sont celles du vrai serveur, relevées en jouant le parcours :
/// devis, paiement demandé, paiement validé. Le cas qui compte : après le
/// paiement d'une adhésion, l'écran dit que le CABINET VÉRIFIE L'IDENTITÉ,
/// au lieu de faire attendre un lien qui ne peut pas encore partir.
/// ─────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _json(String etat, {bool acces = true}) => {
  'reference': 'SO-9057039895054fc2',
  'libelle': 'Suivi comptable et fiscal — Impôt libératoire',
  'etat': etat,
  'ouvre_un_acces': acces,
  'prospect': {'courriel': 'parcours.essai@exemple.cm'},
  'montant': '12500',
  'abonnement_mensuel': '12500',
  'engagee_le': '2026-09-21T16:10:45',
  'payee_le': etat == 'EN_ATTENTE_PAIEMENT' ? null : '2026-09-21T16:11:58',
  'activee_le': etat == 'ACTIVEE' ? '2026-09-22T09:00:00' : null,
  'prend_effet_le': etat == 'ACTIVEE' ? '2026-09-22' : null,
};

Future<PublicFeint> _poser(
  WidgetTester testeur,
  LectureDuSuivi lecture, {
  List<Mensualite>? mensualites,
}) async {
  testeur.view.physicalSize = const Size(360 * 3, 1400 * 3);
  testeur.view.devicePixelRatio = 3;
  addTearDown(testeur.view.reset);
  final p = PublicFeint(suivi: lecture, lesMensualites: mensualites);
  await testeur.pumpWidget(
    MaterialApp(
      theme: themeClair(),
      home: EcranSuivi(servicePublic: p, reference: 'SO-9057039895054fc2'),
    ),
  );
  await testeur.pumpAndSettle();
  return p;
}

LectureDuSuivi _trouve(String etat, {bool acces = true}) => LectureDuSuivi(
  SortDuSuivi.trouve,
  SuiviDeSouscription.depuisJson(_json(etat, acces: acces)),
);

void main() {
  testWidgets('en attente : le paiement est EN COURS, pas fait', (
    testeur,
  ) async {
    await _poser(testeur, _trouve('EN_ATTENTE_PAIEMENT'));
    expect(find.text('Paiement demandé · fait'), findsOneWidget);
    expect(find.text('Paiement reçu · en cours'), findsOneWidget);
  });

  testWidgets("payée : l'étape suivante est la vérification d'identité", (
    testeur,
  ) async {
    // ⚠️ L'étape qu'on oublie : sans elle, le souscripteur attend un lien
    // qui ne peut pas encore partir, et appelle le cabinet.
    await _poser(testeur, _trouve('PAYEE'));
    expect(find.text('Paiement reçu · fait'), findsOneWidget);
    expect(
      find.text('Identité vérifiée par le cabinet · en cours'),
      findsOneWidget,
    );
    expect(find.textContaining('Le NIU seul ne le prouve pas'), findsOneWidget);
    // Et l'adresse où partira le lien est rappelée.
    expect(find.textContaining('parcours.essai@exemple.cm'), findsOneWidget);
  });

  testWidgets("une prestation sans dossier n'a pas d'étape d'identité", (
    testeur,
  ) async {
    await _poser(testeur, _trouve('PAYEE', acces: false));
    expect(find.textContaining('Identité vérifiée'), findsNothing);
    expect(find.text('Prestation confirmée · fait'), findsOneWidget);
  });

  testWidgets('activée : les mensualités, avec leur état en mots', (
    testeur,
  ) async {
    await _poser(
      testeur,
      _trouve('ACTIVEE'),
      mensualites: [
        Mensualite.depuisJson({
          'numero': 1,
          'periode_debut': '2026-09-22',
          'periode_fin': '2026-10-21',
          'montant': '12500',
          'exigible_le': '2026-09-22',
          'etat': 'REGLEE',
        }),
        Mensualite.depuisJson({
          'numero': 2,
          'periode_debut': '2026-10-22',
          'periode_fin': '2026-11-21',
          'montant': '12500',
          'exigible_le': '2026-10-22',
          'etat': 'IMPAYEE',
        }),
      ],
    );
    expect(find.text('Accès ouvert · fait'), findsOneWidget);
    expect(find.text('Réglée'), findsOneWidget);
    expect(find.text('Impayée'), findsOneWidget);
    expect(find.text('12 500 F'), findsNWidgets(2));
  });

  testWidgets('une référence inconnue ne passe pas pour une panne', (
    testeur,
  ) async {
    await _poser(testeur, const LectureDuSuivi(SortDuSuivi.introuvable));
    expect(find.byKey(const Key('suivi-introuvable')), findsOneWidget);
    expect(find.byKey(const Key('suivi-hors-ligne')), findsNothing);
  });

  testWidgets('pas de réseau le dit', (testeur) async {
    await _poser(testeur, const LectureDuSuivi(SortDuSuivi.indisponible));
    expect(find.byKey(const Key('suivi-hors-ligne')), findsOneWidget);
  });

  testWidgets("un paiement abandonné dit que rien n'a été débité", (
    testeur,
  ) async {
    await _poser(testeur, _trouve('ABANDONNEE'));
    expect(find.byKey(const Key('suivi-interrompu')), findsOneWidget);
    expect(find.textContaining("rien n'a été débité"), findsOneWidget);
  });
}
