import 'dart:io';

import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/domaine/document_recu.dart';
import 'package:cga_mobile/domaine/echeance.dart';
import 'package:cga_mobile/domaine/mon_entreprise.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:cga_mobile/ports/appareil_photo.dart';
import 'package:cga_mobile/domaine/preuve.dart';
import 'package:cga_mobile/domaine/piece_remise.dart';
import 'package:cga_mobile/ecrans/echeances.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/service_de_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cga_mobile/composants/actions.dart';
import 'package:cga_mobile/domaine/fonds_confies.dart';

import 'soutien/espace_feint.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// L'écran qui répond à « qu'est-ce que je dois faire, et pour quand ? ».
///
/// ⚠️ Les deux cas les plus importants de ce fichier ne portent pas sur ce que
/// l'écran affiche, mais sur ce qu'il doit REFUSER de dire :
///
///   · « vous êtes à jour » quand le réseau a manqué ;
///   · « réglé » quand l'adhérent a seulement envoyé une preuve.
///
/// Les deux tranquillisent à tort, et la tranquillité à tort coûte des
/// majorations à quelqu'un qui aurait agi s'il avait su.
/// ─────────────────────────────────────────────────────────────────────────────

class SessionFeinte implements ServiceDeSession {
  SessionFeinte({this.echeancier = const Echeancier()});

  Echeancier echeancier;
  final List<String> demandes = [];

  @override
  Future<bool> ouvrirUneSession(String c, String m) async => true;

  @override
  Future<void> fermerLaSession() async {}

  @override
  Future<List<String>> mesDossiers() async => const ['M081234567890P'];

  @override
  Future<Historique> mesPieces(String dossier) async => const Historique();

  @override
  Future<Echeancier> mesEcheances(String dossier) async {
    demandes.add(dossier);
    return echeancier;
  }

  /// Les preuves envoyées, avec l'obligation qu'elles acquittent.
  final List<String> preuves = [];

  /// Ce que le serveur répond à l'envoi d'une preuve.
  Preuve sortDeLaPreuve = Preuve.recue;

  @override
  Future<Preuve> envoyerLaPreuve({
    required String dossier,
    required Echeance echeance,
    required String cheminDeLaPhoto,
  }) async {
    preuves.add(echeance.codeObligation);
    return sortDeLaPreuve;
  }

  @override
  Future<Fiche> monEntreprise(String dossier) async => const Fiche();

  @override
  Future<SortDuSignalement> signalerUnChangement({
    required String dossier,
    required String nature,
    required String message,
  }) async => SortDuSignalement.transmis;

  @override
  Future<Documents> mesDocuments(String dossier) async => const Documents();
}

Echeance echeance({
  String code = 'CNPS',
  String titre = 'Cotisations sociales CNPS',
  String periode = 'janvier 2025',
  String etat = 'EN_RETARD',
  int jours = 582,
  int autres = 0,
  String? deQuoi,
  String? retard,
  String echeanceLe = '2025-02-15',
}) => Echeance.depuisJson({
  'code_obligation': code,
  'titre': titre,
  'periode': periode,
  'periode_debut': '2025-01-01',
  'periode_fin': '2025-01-31',
  'echeance': echeanceLe,
  'etat': etat,
  'jours': jours,
  'autres_periodes_en_retard': autres,
  'de_quoi_s_agit_il': deQuoi,
  'en_cas_de_retard': retard,
});

/// Un appareil qui rend toujours une photo, ou jamais si on le lui dit.
class AppareilFeint implements AppareilPhoto {
  AppareilFeint(this.cache, {this.renonce = false});

  final Directory cache;
  final bool renonce;
  int prises = 0;

  @override
  Future<String?> photographier() async {
    if (renonce) return null;
    prises++;
    final f = File('${cache.path}/q$prises.jpg');
    await f.writeAsBytes([0xFF, 0xD8, prises, 0xFF, 0xD9]);
    return f.path;
  }
}

void main() {
  late Directory racine;
  late PriseDeVue prise;
  late AppareilFeint appareil;

  setUp(() async {
    racine = await Directory.systemTemp.createTemp('echeances');
    appareil = AppareilFeint(racine);
    prise = PriseDeVue(
      appareil: appareil,
      file: FileDAttente(MagasinEnMemoire()),
      photos: Directory('${racine.path}/photos'),
    );
  });

  tearDown(() async {
    if (await racine.exists()) await racine.delete(recursive: true);
  });

  Future<SessionFeinte> poser(
    WidgetTester testeur, {
    Echeancier echeancier = const Echeancier(),
    VoidCallback? quandSessionExpire,
    EspaceFeint? espace,
  }) async {
    final s = SessionFeinte(echeancier: echeancier);
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranEcheances(
          session: s,
          dossier: 'M081234567890P',
          quandSessionExpire: quandSessionExpire ?? () {},
          priseDeVue: prise,
          espace: espace,
        ),
      ),
    );
    return s;
  }

  group('Ce que l\'écran doit refuser de dire', () {
    testWidgets('PAS DE RÉSEAU NE SE DIT JAMAIS « aucune échéance »', (
      testeur,
    ) async {
      await poser(
        testeur,
        echeancier: const Echeancier(serveurJoignable: false),
      );
      await testeur.pumpAndSettle();

      expect(find.text('Pas de réseau'), findsOneWidget);
      expect(find.text('Aucune échéance'), findsNothing);
      expect(find.textContaining('Rien en retard'), findsNothing);
    });

    testWidgets('une preuve envoyée ne se dit pas « réglé »', (testeur) async {
      // ⚠️ Une preuve envoyée n'est pas un dépôt : l'obligation reste à faire au
      // calendrier du cabinet tant qu'un collaborateur n'a pas consigné
      // l'accusé. Une quittance illisible, ou d'un autre trimestre, ne règle
      // rien.
      await poser(
        testeur,
        echeancier: Echeancier(
          echeances: [echeance(etat: 'PREUVE_ENVOYEE', jours: 0)],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.text('Le cabinet vérifie votre preuve'), findsOneWidget);
      expect(find.textContaining('Réglé'), findsNothing);
      expect(find.textContaining('réglé'), findsNothing);
    });
  });

  group('Payée, ou fonds reçus (18 octobre 2026)', () {
    test('le téléphone lit les deux états du serveur', () {
      // ⚠️ Lus « À venir », ils faisaient glisser une CNPS tout juste réglée
      // par mobile money parmi les échéances futures.
      expect(
        echeance(etat: 'FONDS_RECUS', jours: 0).etat,
        EtatPourLAdherent.fondsRecus,
      );
      expect(echeance(etat: 'PAYEE', jours: 0).etat, EtatPourLAdherent.payee);
    });

    testWidgets('des fonds reçus le disent, sans rien demander', (
      testeur,
    ) async {
      await poser(
        testeur,
        echeancier: Echeancier(
          echeances: [echeance(etat: 'FONDS_RECUS', jours: 0)],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.text('Fonds reçus par le cabinet'), findsOneWidget);
      expect(find.text('À venir'), findsNothing);
    });
  });

  group('Le verdict', () {
    testWidgets('compte les PÉRIODES en retard, et non les cartes', (
      testeur,
    ) async {
      // ⚠️ LE PIÈGE. Deux cartes, mais dix-neuf et six autres périodes derrière
      // elles : conclure sur les cartes annoncerait « 2 » là où l'adhérent en
      // doit vingt-sept.
      await poser(
        testeur,
        echeancier: Echeancier(
          echeances: [
            echeance(code: 'CNPS', autres: 19),
            echeance(code: 'TVA', titre: 'TVA du mois', autres: 6),
          ],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.text('27 périodes en retard'), findsOneWidget);
      expect(find.text('2 périodes en retard'), findsNothing);
    });

    testWidgets('dit « rien en retard » quand rien ne l\'est', (testeur) async {
      await poser(
        testeur,
        echeancier: Echeancier(
          echeances: [echeance(etat: 'A_VENIR', jours: 12)],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.text('Rien en retard'), findsOneWidget);
    });
  });

  testWidgets('Les autres périodes en retard sont annoncées, jamais tues', (
    testeur,
  ) async {
    await poser(
      testeur,
      echeancier: Echeancier(echeances: [echeance(autres: 19)]),
    );
    await testeur.pumpAndSettle();

    expect(find.textContaining('19 autres périodes en retard'), findsOneWidget);
  });

  testWidgets('Le retard se dit en jours, sur la carte', (testeur) async {
    await poser(
      testeur,
      echeancier: Echeancier(echeances: [echeance(jours: 582)]),
    );
    await testeur.pumpAndSettle();

    expect(find.textContaining('En retard de 582 jours'), findsOneWidget);
  });

  testWidgets('L\'explication est repliée, et se déplie sur demande', (
    testeur,
  ) async {
    // ⚠️ Dépliée d'office, cinq cartes font un mur de texte que personne ne
    // lit. Absente, l'adhérent ignore ce que « CNPS » veut dire.
    const texte =
        'Les cotisations de sécurité sociale de vos employés : retraite, '
        'prestations familiales, accidents du travail.';
    await poser(
      testeur,
      echeancier: Echeancier(
        echeances: [echeance(deQuoi: texte, retard: 'Majorations.')],
      ),
    );
    await testeur.pumpAndSettle();

    expect(find.text(texte), findsNothing);
    await testeur.tap(find.byKey(const Key('expliquer-CNPS')));
    await testeur.pumpAndSettle();
    expect(find.text(texte), findsOneWidget);
    expect(find.text('Majorations.'), findsOneWidget);
  });

  testWidgets('Une session expirée demande de se reconnecter, et le signale', (
    testeur,
  ) async {
    var renvoye = false;
    await poser(
      testeur,
      echeancier: const Echeancier(sessionAExpire: true),
      quandSessionExpire: () => renvoye = true,
    );
    await testeur.pumpAndSettle();

    expect(find.text('Session expirée'), findsOneWidget);
    expect(renvoye, isTrue);
  });

  testWidgets('Un échéancier réellement vide le dit, et invite à appeler', (
    testeur,
  ) async {
    await poser(testeur);
    await testeur.pumpAndSettle();

    expect(find.text('Aucune échéance'), findsOneWidget);
    expect(find.text('Pas de réseau'), findsNothing);
  });

  group("« J'ai déjà payé »", () {
    testWidgets('n\'est proposé que sur ce qui est en retard', (testeur) async {
      // ⚠️ Sur une échéance à venir il n'y a rien à prouver, et sur une preuve
      // déjà envoyée le cabinet vérifie : reproposer le geste ferait déposer
      // une seconde quittance que quelqu'un devrait démêler.
      await poser(
        testeur,
        echeancier: Echeancier(
          echeances: [
            echeance(code: 'CNPS'),
            echeance(code: 'TVA', etat: 'A_VENIR', jours: 12),
            echeance(code: 'PATENTE', etat: 'PREUVE_ENVOYEE', jours: 3),
            echeance(code: 'DSF', etat: 'DEPOSEE', jours: 0),
          ],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.byKey(const Key('jai-paye-CNPS')), findsOneWidget);
      expect(find.byKey(const Key('jai-paye-TVA')), findsNothing);
      expect(find.byKey(const Key('jai-paye-PATENTE')), findsNothing);
      expect(find.byKey(const Key('jai-paye-DSF')), findsNothing);
    });

    testWidgets('dit « j\'ai déjà payé », et jamais « payer »', (
      testeur,
    ) async {
      // ⚠️ L'adhérent a réglé ailleurs — guichet, Mobile Money, virement — et
      // il en apporte la preuve. L'application ne sait pas encaisser, et le
      // serveur non plus pour un adhérent : il n'existe ni permission ni route.
      await poser(testeur, echeancier: Echeancier(echeances: [echeance()]));
      await testeur.pumpAndSettle();

      expect(find.textContaining("J'ai déjà payé"), findsOneWidget);
      expect(find.text('Payer'), findsNothing);
      expect(find.textContaining('Payer maintenant'), findsNothing);
    });

    testWidgets('photographie la quittance et l\'envoie pour cette obligation', (
      testeur,
    ) async {
      final session = await poser(
        testeur,
        echeancier: Echeancier(echeances: [echeance(code: 'CNPS')]),
      );
      await testeur.pumpAndSettle();

      await testeur.runAsync(() async {
        await testeur.tap(find.byKey(const Key('jai-paye-CNPS')));
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await testeur.pumpAndSettle();
      await envoyerLaQuittanceRevue(testeur);

      expect(appareil.prises, 1);
      expect(session.preuves, const ['CNPS']);
      // ⚠️ La période doit être nommée : la carte glisse au mois suivant et
      // reste « en retard ». Sans ce repère, l'adhérent croit que rien n'a été
      // pris et recommence.
      expect(
        find.textContaining('Preuve envoyée pour janvier 2025'),
        findsOneWidget,
      );
      expect(find.textContaining('Le cabinet la vérifie'), findsOneWidget);
    });

    testWidgets('renoncer à la photo n\'envoie rien', (testeur) async {
      prise = PriseDeVue(
        appareil: AppareilFeint(racine, renonce: true),
        file: FileDAttente(MagasinEnMemoire()),
        photos: Directory('${racine.path}/photos'),
      );
      final session = await poser(
        testeur,
        echeancier: Echeancier(echeances: [echeance(code: 'CNPS')]),
      );
      await testeur.pumpAndSettle();

      await testeur.runAsync(() async {
        await testeur.tap(find.byKey(const Key('jai-paye-CNPS')));
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await testeur.pumpAndSettle();

      expect(session.preuves, isEmpty);
    });

    testWidgets(
      'une panne dit que la quittance est PARTIE, pas qu elle est perdue',
      (testeur) async {
        // ⚠️ LE CAS QUI COMPTE. La quittance est déposée comme pièce ordinaire
        // AVANT qu'on dise ce qu'elle acquitte. Si le rattachement échoue, elle
        // est chez le cabinet, muette. Le taire ferait reprendre une photo, et
        // le cabinet recevrait deux quittances.
        final session = await poser(
          testeur,
          echeancier: Echeancier(echeances: [echeance(code: 'CNPS')]),
        );
        session.sortDeLaPreuve = Preuve.indisponible;
        await testeur.pumpAndSettle();

        await testeur.runAsync(() async {
          await testeur.tap(find.byKey(const Key('jai-paye-CNPS')));
          await Future<void>.delayed(const Duration(milliseconds: 120));
        });
        await testeur.pumpAndSettle();
        await envoyerLaQuittanceRevue(testeur);

        expect(find.textContaining('est arrivée au cabinet'), findsOneWidget);
        expect(find.textContaining('Inutile de la reprendre'), findsOneWidget);
      },
    );
  });

  testWidgets('Revenir dans l\'application redemande au serveur', (
    testeur,
  ) async {
    // ⚠️ Une échéance franchie pendant que l'application dormait change l'état
    // de la carte. Un écran qui dit « à venir » sur une obligation passée en
    // retard se trompe dans le sens qui coûte des majorations.
    final session = await poser(
      testeur,
      echeancier: Echeancier(echeances: [echeance(etat: 'A_VENIR', jours: 1)]),
    );
    await testeur.pumpAndSettle();
    expect(session.demandes.length, 1);

    session.echeancier = Echeancier(echeances: [echeance(jours: 1)]);
    // ⚠️ 20 octobre 2026 : pas dans les cinq minutes qui suivent une lecture
    // (voir `Fraicheur`). Aucune échéance ne se franchit dans l'intervalle.
    testeur.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await testeur.pumpAndSettle();
    expect(session.demandes.length, 1);

    await testeur.pump(const Duration(minutes: 6));
    testeur.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await testeur.pumpAndSettle();

    expect(session.demandes.length, 2);
    expect(find.text('1 période en retard'), findsOneWidget);
  });

  // ── 18 octobre 2026 : toutes les façons de régler ─────────────────────────
  FondsConfies sousMandat({String etat = 'A_REGLER'}) => FondsConfies.depuis({
    'obligations_mandatees': ['CNPS'],
    'appels': [
      {
        'identifiant': 'AF-M081234567890P-CNPS-20250101',
        'code_obligation': 'CNPS',
        'libelle': 'Cotisations sociales CNPS',
        'periode_debut': '2025-01-01',
        'montant': '110618',
        'etat': etat,
      },
    ],
  });

  testWidgets(
    'Sous mandat, l\'échéance se règle par mobile money, sans quittance',
    (testeur) async {
      final espace = EspaceFeint(fonds: sousMandat());
      await poser(
        testeur,
        echeancier: Echeancier(echeances: [echeance()]),
        espace: espace,
      );
      await testeur.pumpAndSettle();

      expect(find.text(montantFcfa(110618)), findsOneWidget);
      expect(find.textContaining('rien à photographier'), findsOneWidget);
      await testeur.tap(find.byKey(const Key('regler-CNPS')));
      await testeur.pumpAndSettle();
      await testeur.enterText(
        find.byKey(const Key('numero-mobile-money')),
        '677123456',
      );
      await testeur.tap(find.byKey(const Key('confirmer-le-paiement')));
      await testeur.pumpAndSettle();

      expect(espace.fondsConfies, [
        'AF-M081234567890P-CNPS-20250101:677123456',
      ]);
      expect(find.text('Validez sur votre téléphone'), findsOneWidget);
      expect(appareil.prises, 0, reason: 'aucune photo n\'a été demandée');
    },
  );

  testWidgets(
    'Après la demande, la carte attend la validation, puis dit les fonds reçus',
    (testeur) async {
      // ⚠️ 20 octobre 2026 : la carte gardait son bouton « Régler » après la
      // demande, et l'adhérent qui venait de composer son code payait deux fois.
      final espace = EspaceFeint(fonds: sousMandat());
      await poser(
        testeur,
        echeancier: Echeancier(echeances: [echeance()]),
        espace: espace,
      );
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('regler-CNPS')));
      await testeur.pumpAndSettle();
      await testeur.enterText(
        find.byKey(const Key('numero-mobile-money')),
        '677123456',
      );
      await testeur.tap(find.byKey(const Key('confirmer-le-paiement')));
      await testeur.pumpAndSettle();
      await testeur.tap(find.text('J\'ai compris'));
      await testeur.pumpAndSettle();

      expect(find.text('Paiement en attente de validation'), findsOneWidget);
      expect(find.text('Régler par mobile money'), findsNothing);

      espace.fonds = sousMandat(etat: 'FONDS_RECUS');
      await testeur.pump(const Duration(seconds: 10));
      await testeur.pumpAndSettle();

      expect(find.textContaining('Fonds reçus pour'), findsOneWidget);
      expect(find.text('Paiement en attente de validation'), findsNothing);
      await testeur.pump(const Duration(seconds: 30));
    },
  );

  testWidgets('Les fonds reçus, l\'échéance dit que le cabinet paie', (
    testeur,
  ) async {
    await poser(
      testeur,
      echeancier: Echeancier(echeances: [echeance()]),
      espace: EspaceFeint(fonds: sousMandat(etat: 'FONDS_RECUS')),
    );
    await testeur.pumpAndSettle();

    expect(
      find.textContaining('le cabinet paie l\'administration pour vous'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('regler-CNPS')), findsNothing);
  });

  testWidgets(
    'Sans mandat, les voies se disent, et la quittance reste offerte',
    (testeur) async {
      await poser(
        testeur,
        echeancier: Echeancier(echeances: [echeance()]),
        espace: EspaceFeint(),
      );
      await testeur.pumpAndSettle();

      expect(find.byKey(const Key('jai-paye-CNPS')), findsOneWidget);
      await testeur.tap(find.byKey(const Key('voies-CNPS')));
      await testeur.pumpAndSettle();
      expect(find.text('Le cabinet paie pour vous'), findsOneWidget);
      expect(find.text('Vous payez vous-même'), findsOneWidget);
      expect(find.text('Le demander au cabinet'), findsOneWidget);
    },
  );
}

/// 20 octobre 2026 : la quittance passe par l'aperçu avant de partir. On l'envoie.
Future<void> envoyerLaQuittanceRevue(WidgetTester testeur) async {
  expect(find.text('Vérifier la quittance'), findsOneWidget);
  // ⚠️ Pas de formulaire : ce que la quittance règle, l'écran le sait déjà.
  expect(find.byKey(const Key('apercu-emetteur')), findsNothing);
  await testeur.scrollUntilVisible(
    find.byKey(const Key('apercu-envoyer')),
    300,
    scrollable: find.byType(Scrollable).last,
  );
  await testeur.ensureVisible(find.byKey(const Key('apercu-envoyer')));
  await testeur.pumpAndSettle();
  await testeur.runAsync(() async {
    await testeur.tap(find.byKey(const Key('apercu-envoyer')));
    await Future<void>.delayed(const Duration(milliseconds: 120));
  });
  await testeur.pumpAndSettle();
}
