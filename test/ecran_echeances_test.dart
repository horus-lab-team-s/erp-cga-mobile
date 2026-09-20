import 'package:cga_mobile/domaine/echeance.dart';
import 'package:cga_mobile/domaine/piece_remise.dart';
import 'package:cga_mobile/ecrans/echeances.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/service_de_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  Future<SessionFeinte> poser(
    WidgetTester testeur, {
    Echeancier echeancier = const Echeancier(),
    VoidCallback? quandSessionExpire,
  }) async {
    final s = SessionFeinte(echeancier: echeancier);
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranEcheances(
          session: s,
          dossiers: const ['M081234567890P'],
          quandSessionExpire: quandSessionExpire ?? () {},
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

    expect(
      find.textContaining('19 autres périodes en retard'),
      findsOneWidget,
    );
  });

  testWidgets('Le retard se dit en jours, sur la carte', (testeur) async {
    await poser(
      testeur,
      echeancier: Echeancier(echeances: [echeance(jours: 582)]),
    );
    await testeur.pumpAndSettle();

    expect(find.textContaining('En retard de 582 jours'), findsOneWidget);
  });

  testWidgets(
    'L\'explication est repliée, et se déplie sur demande',
    (testeur) async {
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
    },
  );

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
    testeur.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await testeur.pumpAndSettle();

    expect(session.demandes.length, 2);
    expect(find.text('1 période en retard'), findsOneWidget);
  });
}
