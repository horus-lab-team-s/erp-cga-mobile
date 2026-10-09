import 'package:cga_mobile/domaine/offre.dart';
import 'package:cga_mobile/domaine/souscription.dart';
import 'package:cga_mobile/ecrans/souscrire.dart';
import 'package:cga_mobile/marque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soutien/public_feint.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// LE NIU, EXIGÉ QUAND LA PRESTATION OUVRE UN DOSSIER
///
/// ⚠️ CONSTATÉ CONTRE LE VRAI SERVEUR. Le formulaire ne demandait pas le NIU :
/// le serveur établissait le devis sans lui, puis REFUSAIT le paiement — « le
/// NIU de l'entreprise est nécessaire ». Une adhésion souscrite depuis
/// l'application ne pouvait donc jamais être payée. C'est la prestation
/// principale du cabinet.
/// ─────────────────────────────────────────────────────────────────────────────

class _Public extends PublicFeint {
  _Public({this.devis});
  final prospects = <Prospect>[];

  /// Le devis à rendre ; `null` : le serveur ne répond pas.
  final Devis? devis;

  @override
  Future<Demarche<Devis>> etablirUnDevis({
    required Prospect prospect,
    required List<String> services,
  }) async {
    prospects.add(prospect);
    return devis == null
        ? const Demarche(sort: SortDeLaDemarche.indisponible)
        : Demarche(sort: SortDeLaDemarche.fait, valeur: devis);
  }
}

Service _service({required bool ouvreUnDossier, bool fixe = true}) =>
    Service.depuisJson({
      'code': ouvreUnDossier ? 'ADHESION' : 'DOMICILIATION',
      'libelle': ouvreUnDossier ? 'Adhésion' : 'Domiciliation',
      'nature': 'ABONNEMENT',
      'periodicite': 'MENSUELLE',
      'tarifs': [
        {
          'montant': '12500',
          'du': '2020-01-01',
          'au': null,
          'statut': fixe ? 'FIXE' : 'A_VALIDER',
        },
      ],
      'formules': const [],
      'ouvre_un_dossier': ouvreUnDossier,
      'souscriptible_en_ligne': true,
    });

Future<_Public> _poser(WidgetTester testeur, Service s, {Devis? devis}) async {
  testeur.view.physicalSize = const Size(360 * 3, 1400 * 3);
  testeur.view.devicePixelRatio = 3;
  addTearDown(testeur.view.reset);
  final p = _Public(devis: devis);
  await testeur.pumpWidget(
    MaterialApp(
      theme: themeClair(),
      home: EcranSouscrire(servicePublic: p, service: s),
    ),
  );
  return p;
}

Future<void> _remplir(WidgetTester testeur, {String? niu}) async {
  await testeur.enterText(find.byKey(const Key('champ-nom')), 'NKOA');
  await testeur.enterText(find.byKey(const Key('champ-prenom')), 'Jean');
  await testeur.enterText(
    find.byKey(const Key('champ-courriel')),
    'jean@exemple.cm',
  );
  await testeur.enterText(
    find.byKey(const Key('champ-telephone')),
    '677000111',
  );
  if (find.byKey(const Key('champ-denomination')).evaluate().isNotEmpty) {
    await testeur.enterText(
      find.byKey(const Key('champ-denomination')),
      'SARL BATIMENT PLUS',
    );
  }
  if (niu != null) {
    await testeur.enterText(find.byKey(const Key('champ-niu')), niu);
  }
}

void main() {
  testWidgets("l'adhésion demande le NIU, et dit ce qu'il ne prouve pas", (
    testeur,
  ) async {
    await _poser(testeur, _service(ouvreUnDossier: true));
    expect(find.byKey(const Key('champ-niu')), findsOneWidget);
    expect(find.byKey(const Key('avertissement-verification')), findsOneWidget);
  });

  testWidgets('sans NIU, le devis ne part pas', (testeur) async {
    final p = await _poser(testeur, _service(ouvreUnDossier: true));
    await _remplir(testeur);
    await testeur.ensureVisible(find.byKey(const Key('chiffrer')));
    await testeur.tap(find.byKey(const Key('chiffrer')));
    await testeur.pumpAndSettle();

    expect(p.prospects, isEmpty);
    expect(find.textContaining('NIU est nécessaire'), findsOneWidget);
  });

  testWidgets('un NIU mal formé ne part pas non plus', (testeur) async {
    final p = await _poser(testeur, _service(ouvreUnDossier: true));
    await _remplir(testeur, niu: '123');
    await testeur.ensureVisible(find.byKey(const Key('chiffrer')));
    await testeur.tap(find.byKey(const Key('chiffrer')));
    await testeur.pumpAndSettle();
    expect(p.prospects, isEmpty);
  });

  testWidgets('le NIU part au serveur, en capitales et sans espaces', (
    testeur,
  ) async {
    final p = await _poser(testeur, _service(ouvreUnDossier: true));
    await _remplir(testeur, niu: 'm081 2345 6789 0p');
    await testeur.ensureVisible(find.byKey(const Key('chiffrer')));
    await testeur.tap(find.byKey(const Key('chiffrer')));
    await testeur.pumpAndSettle();

    expect(p.prospects, hasLength(1));
    expect(p.prospects.single.versJson()['niu'], 'M081234567890P');
  });

  testWidgets("une prestation sans dossier ne demande pas de NIU", (
    testeur,
  ) async {
    final p = await _poser(testeur, _service(ouvreUnDossier: false));
    expect(find.byKey(const Key('champ-niu')), findsNothing);
    await _remplir(testeur);
    await testeur.ensureVisible(find.byKey(const Key('chiffrer')));
    await testeur.tap(find.byKey(const Key('chiffrer')));
    await testeur.pumpAndSettle();
    expect(p.prospects, hasLength(1));
    expect(p.prospects.single.versJson().containsKey('niu'), isFalse);
  });

  testWidgets('une fois le prix affiché, une seule action pleine : régler', (
    testeur,
  ) async {
    // ⚠️ Vu sur le téléphone : « Voir mon prix » et « Régler » se suivaient,
    // deux boutons pleins magenta. § 10.7 : une seule action principale.
    final devis = Devis.depuisJson({
      'reference': 'DV-1',
      'lignes': [
        {
          'service': 'DOMICILIATION',
          'libelle': 'Domiciliation',
          'montant': '180000',
          'chiffree': true,
        },
      ],
      'montant_total': '180000',
      'montant_a_regler': '180000',
      'etat': 'EMIS',
      'valide_jusqu_au': '2026-10-21',
      'prix_arretes': true,
    });
    await _poser(testeur, _service(ouvreUnDossier: false), devis: devis);
    await _remplir(testeur);
    await testeur.ensureVisible(find.byKey(const Key('chiffrer')));
    await testeur.tap(find.byKey(const Key('chiffrer')));
    await testeur.pumpAndSettle();

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Recalculer après modification'), findsOneWidget);
  });

  testWidgets("sur un prix que le gérant n'a pas fixé, pas de paiement", (
    testeur,
  ) async {
    // ⚠️ Le serveur refuserait le paiement. Montrer le bouton, c'est promettre
    // ce qui échouera au moment où le visiteur a décidé de payer.
    final devis = Devis.depuisJson({
      'reference': 'DV-2',
      'lignes': [
        {
          'service': 'DOMICILIATION',
          'libelle': 'Domiciliation',
          'montant': '12500',
          'chiffree': true,
        },
      ],
      'montant_total': '12500',
      'montant_a_regler': '12500',
      'etat': 'EMIS',
      'valide_jusqu_au': '2026-10-21',
      'prix_arretes': false,
    });
    await _poser(
      testeur,
      _service(ouvreUnDossier: false, fixe: false),
      devis: devis,
    );
    await _remplir(testeur);
    await testeur.ensureVisible(find.byKey(const Key('chiffrer')));
    await testeur.tap(find.byKey(const Key('chiffrer')));
    await testeur.pumpAndSettle();

    expect(find.byKey(const Key('payer')), findsNothing);
    expect(find.byKey(const Key('prix-a-confirmer')), findsOneWidget);
    // ⚠️ Le résumé ne contredit pas le bloc : ni « à régler », ni « garanti ».
    expect(find.text('Tarif indicatif'), findsOneWidget);
    expect(find.text('À régler maintenant'), findsNothing);
    expect(find.textContaining('garanti'), findsNothing);
    // Le numéro saisi est repris : le visiteur sait où il sera rappelé.
    expect(
      find.descendant(
        of: find.byKey(const Key('prix-a-confirmer')),
        matching: find.textContaining('677000111'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('« Faire confirmer mon prix » dépose la demande au cabinet', (
    testeur,
  ) async {
    // ⚠️ L'écran promettait un rappel que rien ne déclenchait. Le bouton doit
    // appeler le serveur avec la référence du devis, et dire que c'est fait.
    final devis = Devis.depuisJson({
      'reference': 'DV-3',
      'lignes': [
        {
          'service': 'DOMICILIATION',
          'libelle': 'Domiciliation',
          'montant': '12500',
          'chiffree': true,
        },
      ],
      'montant_total': '12500',
      'montant_a_regler': '12500',
      'etat': 'EMIS',
      'valide_jusqu_au': '2026-10-21',
      'prix_arretes': false,
    });
    final p = await _poser(
      testeur,
      _service(ouvreUnDossier: false, fixe: false),
      devis: devis,
    );
    p.reponseAuRappel = const Demarche(
      sort: SortDeLaDemarche.fait,
      valeur: 'Un responsable vous contacte au 677000111.',
    );
    await _remplir(testeur);
    await testeur.ensureVisible(find.byKey(const Key('chiffrer')));
    await testeur.tap(find.byKey(const Key('chiffrer')));
    await testeur.pumpAndSettle();

    await testeur.ensureVisible(find.byKey(const Key('faire-confirmer')));
    await testeur.tap(find.byKey(const Key('faire-confirmer')));
    await testeur.pumpAndSettle();

    expect(p.rappelsDemandes, ['DV-3']);
    expect(find.byKey(const Key('rappel-transmis')), findsOneWidget);
    expect(find.textContaining('vous contacte au 677000111'), findsOneWidget);
    // Le bouton se retire : le client voit que c'est fait, il ne recommence pas.
    expect(find.byKey(const Key('faire-confirmer')), findsNothing);
  });

  testWidgets('un refus du serveur se lit, et le bouton reste', (
    testeur,
  ) async {
    final devis = Devis.depuisJson({
      'reference': 'DV-4',
      'lignes': [
        {
          'service': 'DOMICILIATION',
          'libelle': 'Domiciliation',
          'montant': '12500',
          'chiffree': true,
        },
      ],
      'montant_total': '12500',
      'montant_a_regler': '12500',
      'etat': 'EMIS',
      'valide_jusqu_au': '2026-10-21',
      'prix_arretes': false,
    });
    final p = await _poser(
      testeur,
      _service(ouvreUnDossier: false, fixe: false),
      devis: devis,
    );
    p.reponseAuRappel = const Demarche(sort: SortDeLaDemarche.indisponible);
    await _remplir(testeur);
    await testeur.ensureVisible(find.byKey(const Key('chiffrer')));
    await testeur.tap(find.byKey(const Key('chiffrer')));
    await testeur.pumpAndSettle();
    await testeur.ensureVisible(find.byKey(const Key('faire-confirmer')));
    await testeur.tap(find.byKey(const Key('faire-confirmer')));
    await testeur.pumpAndSettle();

    expect(find.byKey(const Key('rappel-motif')), findsOneWidget);
    expect(find.byKey(const Key('faire-confirmer')), findsOneWidget);
  });
}
