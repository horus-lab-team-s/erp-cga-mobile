import 'dart:async';

import 'package:cga_mobile/domaine/document_recu.dart';
import 'package:cga_mobile/domaine/echeance.dart';
import 'package:cga_mobile/domaine/mon_entreprise.dart';
import 'package:cga_mobile/domaine/preuve.dart';
import 'package:cga_mobile/domaine/piece_remise.dart';
import 'package:cga_mobile/ecrans/historique.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/service_de_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// L'écran qui répond à « est-ce que j'ai envoyé la facture de mardi ? ».
///
/// ⚠️ Le cas le plus important de ce fichier n'est pas celui qui affiche la
/// liste : c'est celui qui vérifie qu'une panne de réseau ne s'affiche PAS
/// « aucune pièce remise ». Les deux situations rendent une liste vide, et les
/// confondre ferait dire à l'application, à un adhérent qui a déposé deux cents
/// justificatifs, qu'il n'a jamais rien fourni. Il rappellerait le cabinet en
/// urgence, et le produit aurait produit exactement l'appel qu'il promet
/// d'éviter.
/// ─────────────────────────────────────────────────────────────────────────────

/// Une doublure du serveur : elle rend l'historique qu'on lui pose.
class SessionFeinte implements ServiceDeSession {
  SessionFeinte({
    this.historique = const Historique(),
    this.attente,
    this.dossiers = const ['M081234567890P'],
  });

  Historique historique;

  /// Quand elle est posée, la lecture ne rend rien tant qu'on ne l'achève pas.
  /// Sert à observer ce que l'écran montre PENDANT l'attente.
  final Completer<Historique>? attente;

  final List<String> dossiers;

  /// Les dossiers demandés, dans l'ordre. ⚠️ On vérifie non seulement CE QUE
  /// l'écran affiche, mais CE QU'IL DEMANDE : un sélecteur qui change le titre
  /// sans relire le serveur afficherait les pièces du dossier précédent sous le
  /// nom du nouveau.
  final List<String> demandes = [];

  @override
  Future<bool> ouvrirUneSession(String c, String m) async => true;

  @override
  Future<void> fermerLaSession() async {}

  @override
  Future<List<String>> mesDossiers() async => dossiers;

  /// ⚠️ La doublure rend un échéancier VIDE : ces cas-ci ne portent pas sur les
  /// échéances, qui ont leur propre fichier.
  @override
  Future<Echeancier> mesEcheances(String dossier) async => const Echeancier();

  @override
  Future<Historique> mesPieces(String dossier) {
    demandes.add(dossier);
    return attente?.future ?? Future.value(historique);
  }

  @override
  Future<Preuve> envoyerLaPreuve({
    required String dossier,
    required Echeance echeance,
    required String cheminDeLaPhoto,
  }) async => Preuve.recue;

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

PieceRemise piece({
  required String identifiant,
  required String deposeLe,
  String etat = 'RECUE',
  String canal = 'MOBILE',
  String? emetteur,
  num? montant,
  String? reference,
}) => PieceRemise.depuisJson({
  'identifiant': identifiant,
  'depose_le': deposeLe,
  'etat': etat,
  'canal': canal,
  'emetteur': emetteur,
  'montant_ttc': montant,
  'reference_document': reference,
});

void main() {
  Future<SessionFeinte> poser(
    WidgetTester testeur, {
    Historique historique = const Historique(),
    Completer<Historique>? attente,
    List<String> dossiers = const ['M081234567890P'],
    VoidCallback? quandSessionExpire,
  }) async {
    final session = SessionFeinte(
      historique: historique,
      attente: attente,
      dossiers: dossiers,
    );
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranHistorique(
          session: session,
          dossiers: dossiers,
          quandSessionExpire: quandSessionExpire ?? () {},
        ),
      ),
    );
    return session;
  }

  group('Ce que l\'adhérent voit quand il a déjà déposé', () {
    testWidgets('le bilan répond avant le détail', (testeur) async {
      await poser(
        testeur,
        historique: Historique(
          pieces: [
            piece(identifiant: 'PJ-1', deposeLe: '2026-09-18'),
            piece(identifiant: 'PJ-2', deposeLe: '2026-09-12', etat: 'LUE'),
            piece(
              identifiant: 'PJ-3',
              deposeLe: '2026-09-04',
              etat: 'COMPTABILISEE',
            ),
          ],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.text('3 pièces au cabinet'), findsOneWidget);
      expect(
        find.text('2 déjà prises en compte par le cabinet.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'une pièce lue porte ce que le cabinet y a vu, pas sa date seule',
      (testeur) async {
        // ⚠️ C'est LA preuve visible du travail du cabinet. Voir « ENEO ·
        // 45 000 F » apparaître sous sa propre photo, c'est constater que
        // quelqu'un l'a ouverte. Une pastille qui passe de gris à magenta
        // demande de croire sur parole.
        await poser(
          testeur,
          historique: Historique(
            pieces: [
              piece(
                identifiant: 'PJ-1',
                deposeLe: '2026-09-12',
                etat: 'LUE',
                emetteur: 'ENEO',
                montant: 45000,
                reference: 'F-2026-0439',
              ),
            ],
          ),
        );
        await testeur.pumpAndSettle();

        expect(find.text('ENEO'), findsOneWidget);
        expect(find.text('45 000 F'), findsOneWidget);
        expect(find.textContaining('F-2026-0439'), findsOneWidget);
        expect(find.text('Lue par le cabinet'), findsOneWidget);
      },
    );

    testWidgets('une pièce que personne n\'a ouverte se dit par sa date', (
      testeur,
    ) async {
      await poser(
        testeur,
        historique: Historique(
          pieces: [piece(identifiant: 'PJ-1', deposeLe: '2026-09-12')],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.text('Pièce du 12 septembre'), findsOneWidget);
      expect(find.text('Reçue par le cabinet'), findsOneWidget);
    });

    testWidgets('les pièces se rangent par mois, du plus récent au plus vieux', (
      testeur,
    ) async {
      await poser(
        testeur,
        historique: Historique(
          pieces: [
            piece(identifiant: 'PJ-1', deposeLe: '2026-09-18'),
            piece(identifiant: 'PJ-2', deposeLe: '2026-09-04'),
            piece(identifiant: 'PJ-3', deposeLe: '2026-08-27'),
          ],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.text('Septembre 2026'), findsOneWidget);
      expect(find.text('Août 2026'), findsOneWidget);
      // Le mois le plus récent d'abord : c'est ce qu'on vient chercher.
      final septembre = testeur.getTopLeft(find.text('Septembre 2026')).dy;
      final aout = testeur.getTopLeft(find.text('Août 2026')).dy;
      expect(septembre, lessThan(aout));
    });

    testWidgets(
      "une pièce sans rien à détailler ne réserve pas la ligne pour autant",
      (testeur) async {
        // ⚠️ MESURÉ SUR LE TECNO, ET LE DÉFAUT ÉTAIT VISIBLE. Une pièce
        // photographiée que le cabinet n'a pas encore ouverte n'a ni émetteur,
        // ni référence, et son canal est le téléphone : les trois morceaux de
        // la ligne de détail manquent. Le `Text` vide restait en place entre
        // deux marges et creusait sous le titre un blanc que rien n'occupait.
        await poser(
          testeur,
          historique: Historique(
            pieces: [piece(identifiant: 'PJ-1', deposeLe: '2026-09-20')],
          ),
        );
        await testeur.pumpAndSettle();

        expect(find.text('Pièce du 20 septembre'), findsOneWidget);
        expect(find.text(''), findsNothing);
      },
    );

    testWidgets('le canal n\'est cité que s\'il n\'est pas ce téléphone', (
      testeur,
    ) async {
      await poser(
        testeur,
        historique: Historique(
          pieces: [
            piece(identifiant: 'PJ-1', deposeLe: '2026-09-18'),
            piece(
              identifiant: 'PJ-2',
              deposeLe: '2026-09-17',
              canal: 'COURRIEL',
            ),
          ],
        ),
      );
      await testeur.pumpAndSettle();

      // ⚠️ L'historique montre TOUT le dossier, y compris ce qui n'est pas
      // passé par l'application. Sans la mention, l'adhérent croirait avoir
      // photographié une pièce qu'il a envoyée par courriel.
      expect(find.textContaining('reçue par courriel'), findsOneWidget);
      expect(find.textContaining('mobile'), findsNothing);
    });
  });

  group('Ce que l\'adhérent voit quand quelque chose manque', () {
    testWidgets(
      'PAS DE RÉSEAU NE SE DIT JAMAIS « aucune pièce remise »',
      (testeur) async {
        // ⚠️ LE CAS QUI JUSTIFIE TOUT LE TYPE `Historique`. Les deux situations
        // rendent zéro pièce ; l'une veut dire « vous n'avez rien déposé »,
        // l'autre « je n'ai pas pu demander ». Dire la première à quelqu'un qui
        // a tout déposé est le pire mensonge que cet écran puisse faire.
        await poser(
          testeur,
          historique: const Historique(serveurJoignable: false),
        );
        await testeur.pumpAndSettle();

        expect(find.text('Pas de réseau'), findsOneWidget);
        expect(find.text('Aucune pièce remise'), findsNothing);
        expect(
          find.textContaining('Vos pièces remises sont chez le cabinet'),
          findsOneWidget,
        );
      },
    );

    testWidgets('un dossier réellement vide le dit, et rassure', (
      testeur,
    ) async {
      await poser(testeur);
      await testeur.pumpAndSettle();

      expect(find.text('Aucune pièce remise'), findsOneWidget);
      expect(find.text('Pas de réseau'), findsNothing);
    });

    testWidgets('une session expirée demande de se reconnecter, et le signale', (
      testeur,
    ) async {
      var renvoye = false;
      await poser(
        testeur,
        historique: const Historique(sessionAExpire: true),
        quandSessionExpire: () => renvoye = true,
      );
      await testeur.pumpAndSettle();

      expect(find.text('Session expirée'), findsOneWidget);
      // ⚠️ L'écran ne décide pas lui-même de renvoyer à la connexion : il
      // prévient celui qui l'a ouvert, pour que la sortie soit la même que
      // depuis l'accueil. Deux sorties pour la même cause laisseraient
      // l'application dans deux états qu'aucun écran ne sait montrer.
      expect(renvoye, isTrue);
    });

    testWidgets('pendant la lecture, l\'écran attend au lieu de mentir', (
      testeur,
    ) async {
      final attente = Completer<Historique>();
      await poser(testeur, attente: attente);
      await testeur.pump();

      expect(find.byKey(const Key('historique-en-attente')), findsOneWidget);
      expect(find.text('Aucune pièce remise'), findsNothing);

      attente.complete(
        Historique(
          pieces: [piece(identifiant: 'PJ-1', deposeLe: '2026-09-18')],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.byKey(const Key('historique-en-attente')), findsNothing);
      expect(find.text('1 pièce au cabinet'), findsOneWidget);
    });
  });

  group('Le choix du dossier', () {
    testWidgets('n\'apparaît pas quand le compte n\'en a qu\'un', (
      testeur,
    ) async {
      await poser(testeur, dossiers: const ['M081234567890P']);
      await testeur.pumpAndSettle();

      // Une liste déroulante à un seul choix est un bouton qui ne fait rien.
      expect(find.byKey(const Key('choix-dossier')), findsNothing);
    });

    testWidgets('apparaît dès qu\'il y en a deux, et relit le serveur', (
      testeur,
    ) async {
      final session = await poser(
        testeur,
        dossiers: const ['M081234567890P', 'M099887766554A'],
      );
      await testeur.pumpAndSettle();
      expect(session.demandes, ['M081234567890P']);

      await testeur.tap(find.byKey(const Key('choix-dossier')));
      await testeur.pumpAndSettle();
      await testeur.tap(find.text('M099887766554A').last);
      await testeur.pumpAndSettle();

      // ⚠️ On vérifie la DEMANDE, pas seulement l'affichage. Un sélecteur qui
      // change le titre sans relire montrerait les pièces du dossier précédent
      // sous le nom du nouveau — et l'adhérent qui tient deux sociétés
      // conclurait que le cabinet a perdu ses pièces.
      expect(session.demandes, ['M081234567890P', 'M099887766554A']);
    });
  });

  group("Revenir dans l'application", () {
    testWidgets("redemande au serveur, sans attendre un geste", (
      testeur,
    ) async {
      // ⚠️ CONSTATÉ SUR LE TECNO, ET PAR ACCIDENT. Le téléphone est passé sur
      // une autre application pendant l'essai ; le comptable a lu une pièce
      // dans l'intervalle ; au retour, l'historique affichait encore l'état
      // d'avant — « Reçue par le cabinet » sur une pièce déjà lue, et « 7 prises
      // en compte » au lieu de 8. Rien ne signalait que la liste était périmée.
      final session = await poser(
        testeur,
        historique: Historique(
          pieces: [piece(identifiant: 'PJ-1', deposeLe: '2026-09-20')],
        ),
      );
      await testeur.pumpAndSettle();
      expect(session.demandes.length, 1);

      // Le cabinet a travaillé pendant que l'adhérent était ailleurs.
      session.historique = Historique(
        pieces: [
          piece(
            identifiant: 'PJ-1',
            deposeLe: '2026-09-20',
            etat: 'LUE',
            emetteur: 'CIMENCAM DOUALA',
            montant: 127500,
          ),
        ],
      );

      testeur.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await testeur.pumpAndSettle();

      expect(session.demandes.length, 2);
      expect(find.text('CIMENCAM DOUALA'), findsOneWidget);
      expect(find.text('127 500 F'), findsOneWidget);
    });

    testWidgets("mais un volet de notifications ne déclenche rien", (
      testeur,
    ) async {
      // ⚠️ Sur Android, dérouler le volet des notifications passe par
      // `inactive`. Relire à chaque fois ferait des appels que rien ne
      // justifie, sur un forfait que l'adhérent paie.
      final session = await poser(testeur);
      await testeur.pumpAndSettle();
      expect(session.demandes.length, 1);

      testeur.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await testeur.pumpAndSettle();

      expect(session.demandes.length, 1);
    });
  });

  testWidgets('Tirer vers le bas redemande au serveur', (testeur) async {
    final session = await poser(
      testeur,
      historique: Historique(
        pieces: [piece(identifiant: 'PJ-1', deposeLe: '2026-09-18')],
      ),
    );
    await testeur.pumpAndSettle();
    expect(session.demandes.length, 1);

    await testeur.fling(find.text('1 pièce au cabinet'), const Offset(0, 320), 1000);
    await testeur.pumpAndSettle();

    expect(session.demandes.length, 2);
  });

  testWidgets(
    'Sans réseau, le geste de rafraîchir reste possible sur le message',
    (testeur) async {
      // ⚠️ Le message d'erreur est posé dans une zone qui DÉFILE. Centré, il ne
      // répondait à aucun geste : l'adhérent voyait « pas de réseau » et n'avait
      // aucun moyen de réessayer une fois la connexion revenue, sinon fermer
      // l'application.
      final session = await poser(
        testeur,
        historique: const Historique(serveurJoignable: false),
      );
      await testeur.pumpAndSettle();
      expect(session.demandes.length, 1);

      await testeur.fling(find.text('Pas de réseau'), const Offset(0, 320), 1000);
      await testeur.pumpAndSettle();

      expect(session.demandes.length, 2);
    },
  );
}
