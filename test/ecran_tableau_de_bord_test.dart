import 'package:cga_mobile/domaine/document_recu.dart';
import 'package:cga_mobile/domaine/echeance.dart';
import 'package:cga_mobile/domaine/mon_entreprise.dart';
import 'package:cga_mobile/domaine/mon_mois.dart';
import 'package:cga_mobile/domaine/piece_remise.dart';
import 'package:cga_mobile/domaine/preuve.dart';
import 'package:cga_mobile/ecrans/tableau_de_bord.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/service_de_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soutien/tableau_feint.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// L'ACCUEIL CONNECTÉ
///
/// Ce qu'il doit tenir : dire d'abord où en est le mois, dans les mots du
/// serveur ; laisser répondre au cabinet en un appui ; résumer les échéances
/// et les documents ; et mener, de chaque bloc, à l'onglet qui le détaille.
/// ─────────────────────────────────────────────────────────────────────────────

const _dossier = 'M081234567890P';

class _Session implements ServiceDeSession {
  _Session({this.echeancier = const Echeancier(), this.documents});

  Echeancier echeancier;
  Documents? documents;

  @override
  Future<bool> ouvrirUneSession(String c, String m) async => true;
  @override
  Future<void> fermerLaSession() async {}
  @override
  Future<List<String>> mesDossiers() async => const [_dossier];
  @override
  Future<Historique> mesPieces(String dossier) async => const Historique();
  @override
  Future<Echeancier> mesEcheances(String dossier) async => echeancier;
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
  Future<Documents> mesDocuments(String dossier) async =>
      documents ?? const Documents();
}

Echeance _echeance(String etat, String echeance, {int autres = 0}) =>
    Echeance.depuisJson({
      'code_obligation': 'CNPS',
      'titre': 'Cotisations sociales',
      'periode': 'juillet 2026',
      'periode_debut': '2026-07-01',
      'periode_fin': '2026-07-31',
      'echeance': echeance,
      'etat': etat,
      'autres_periodes_en_retard': autres,
    });

class _Traces {
  final onglets = <int>[];
  var mesPieces = 0;
  final piecesOuvertes = <String>[];
  var sessionExpiree = 0;
  var deconnexions = 0;
}

Future<_Traces> _poser(
  WidgetTester testeur, {
  TableauFeint? tableau,
  _Session? session,
}) async {
  testeur.view.physicalSize = const Size(360 * 3, 780 * 3);
  testeur.view.devicePixelRatio = 3;
  addTearDown(testeur.view.reset);
  final t = _Traces();
  await testeur.pumpWidget(
    MaterialApp(
      theme: themeClair(),
      home: EcranTableauDeBord(
        session: session ?? _Session(),
        tableau: tableau ?? TableauFeint(),
        dossiers: const [_dossier],
        quandSessionExpire: () => t.sessionExpiree++,
        allerALOnglet: t.onglets.add,
        ouvrirMesPieces: () => t.mesPieces++,
        ouvrirPiece: t.piecesOuvertes.add,
        seDeconnecter: () => t.deconnexions++,
      ),
    ),
  );
  await testeur.pumpAndSettle();
  return t;
}

final _page = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

Future<void> _amener(WidgetTester testeur, Finder cible) async {
  await testeur.scrollUntilVisible(cible, 200, scrollable: _page);
  await testeur.pumpAndSettle();
}

void main() {
  group('Le mois', () {
    testWidgets('se dit dans les mots du serveur, en premier', (testeur) async {
      await _poser(testeur);
      expect(find.text('Il manque 3 justificatifs'), findsOneWidget);
      expect(find.textContaining('AOÛT 2026'), findsOneWidget);
      // Le bandeau est AU-DESSUS de tout le reste.
      final bandeau = testeur.getTopLeft(
        find.byKey(const Key('bandeau-du-mois')),
      );
      final demandes = testeur.getTopLeft(
        find.text('Ce que le cabinet vous demande'),
      );
      expect(bandeau.dy, lessThan(demandes.dy));
    });

    testWidgets('« aucune pièce » ne se présente jamais comme « complet »', (
      testeur,
    ) async {
      // ⚠️ L'erreur la plus coûteuse de l'écran : annoncer complet le mois de
      // l'entreprise qui a oublié d'envoyer ses factures.
      final mois = MonMois.depuisJson({
        'nom_du_mois': 'août 2026',
        'bandeau': {
          'etat': 'AUCUNE_PIECE',
          'titre': "Aucune pièce d'août 2026 n'est arrivée",
          'detail': 'Envoyez vos factures et votre relevé.',
        },
        'attendues': const [],
      });
      expect(mois.etat.demandeUnGeste, isTrue);
      await _poser(testeur, tableau: TableauFeint(mois: mois));
      expect(find.textContaining('Aucune pièce'), findsOneWidget);
      expect(find.textContaining('complet'), findsNothing);
    });

    testWidgets('un état inconnu ne rassure pas', (testeur) async {
      expect(EtatDuMois.depuis('NOUVEL_ETAT'), EtatDuMois.aucunePiece);
    });
  });

  group('La salutation', () {
    testWidgets('nomme la personne, en entier', (testeur) async {
      await _poser(testeur);
      expect(find.text('Bonjour, Jean-Pierre NKOA'), findsOneWidget);
    });

    testWidgets('sans nom connu, dit bonjour sans inventer', (testeur) async {
      await _poser(testeur, tableau: TableauFeint(nom: null));
      expect(find.text('Bonjour'), findsOneWidget);
    });
  });

  group('Répondre au cabinet', () {
    testWidgets('une réponse toute faite part, et la carte le dit', (
      testeur,
    ) async {
      final tableau = TableauFeint();
      await _poser(testeur, tableau: tableau);
      final bouton = find.byKey(const Key('PLUS_TARD-DP-2026-010'));
      await _amener(testeur, bouton);
      await testeur.tap(bouton);
      await testeur.pumpAndSettle();

      expect(tableau.reponses, [('DP-2026-010', NatureDeReponse.plusTard)]);
      expect(find.byKey(const Key('repondu-DP-2026-010')), findsOneWidget);
      expect(find.textContaining('Réponse transmise'), findsOneWidget);
    });

    testWidgets('une demande répondue sort du compte des pièces à envoyer', (
      testeur,
    ) async {
      // ⚠️ 19 octobre 2026 : la tuile comptait aussi les demandes répondues, et
      // l'accueil disait 3 sous une phrase qui disait 2.
      await _poser(testeur);
      Finder nombre(String texte) => find.descendant(
        of: find.byKey(const Key('chiffre-attendues')),
        matching: find.text(texte),
      );
      expect(nombre('2'), findsOneWidget);

      final bouton = find.byKey(const Key('PLUS_TARD-DP-2026-010'));
      await _amener(testeur, bouton);
      await testeur.tap(bouton);
      await testeur.pumpAndSettle();

      expect(nombre('1'), findsOneWidget);
    });

    testWidgets('« déjà reçue » n\'est pas présenté comme un échec', (
      testeur,
    ) async {
      // ⚠️ Le 409 : le cabinet a déjà la réponse du jour. Un message d'échec
      // ferait recommencer l'adhérent, ou appeler pour rien.
      await _poser(
        testeur,
        tableau: TableauFeint(sortDeLaReponse: SortDeLaReponse.dejaRecue),
      );
      final bouton = find.byKey(const Key('INTROUVABLE-DP-2026-002'));
      await _amener(testeur, bouton);
      await testeur.tap(bouton);
      await testeur.pumpAndSettle();

      expect(find.textContaining('déjà votre réponse'), findsOneWidget);
      expect(find.byKey(const Key('repondu-DP-2026-002')), findsOneWidget);
    });

    testWidgets('sans réseau, la réponse n\'est pas marquée comme partie', (
      testeur,
    ) async {
      await _poser(
        testeur,
        tableau: TableauFeint(sortDeLaReponse: SortDeLaReponse.indisponible),
      );
      final bouton = find.byKey(const Key('PLUS_TARD-DP-2026-002'));
      await _amener(testeur, bouton);
      await testeur.tap(bouton);
      await testeur.pumpAndSettle();

      expect(find.textContaining("n'est pas partie"), findsOneWidget);
      expect(find.byKey(const Key('repondu-DP-2026-002')), findsNothing);
      expect(bouton, findsOneWidget);
    });

    testWidgets('une session expirée renvoie à la connexion', (testeur) async {
      final t = await _poser(
        testeur,
        tableau: TableauFeint(sortDeLaReponse: SortDeLaReponse.sessionExpiree),
      );
      final bouton = find.byKey(const Key('PLUS_TARD-DP-2026-002'));
      await _amener(testeur, bouton);
      await testeur.tap(bouton);
      await testeur.pumpAndSettle();
      expect(t.sessionExpiree, 1);
    });

    testWidgets('« Déposer la pièce » mène à l\'onglet de dépôt', (
      testeur,
    ) async {
      final t = await _poser(testeur);
      final bouton = find.byKey(const Key('deposer-DP-2026-002'));
      await _amener(testeur, bouton);
      await testeur.tap(bouton);
      expect(t.onglets, [EcranTableauDeBord.ongletDeposer]);
    });

    testWidgets('une pièce à corriger se revoit en un appui', (testeur) async {
      // ⚠️ « Facture F-2026-0424 à corriger » ne dit rien à l'adhérent sans
      // l'image : il doit revoir CE QU'IL AVAIT ENVOYÉ pour comprendre.
      final t = await _poser(testeur);
      final lien = find.byKey(const Key('voir-piece-DP-2026-002'));
      await _amener(testeur, lien);
      await testeur.tap(lien);
      expect(t.piecesOuvertes, ['PJ-2026-0013']);
      // Une demande qui ne corrige rien n'a pas de lien.
      expect(find.byKey(const Key('voir-piece-DP-2026-010')), findsNothing);
    });

    testWidgets('le retard et la correction se disent en MOTS', (
      testeur,
    ) async {
      await _poser(testeur);
      expect(find.text('En retard'), findsWidgets);
      expect(find.text('À corriger'), findsOneWidget);
    });
  });

  group('Les échéances', () {
    testWidgets('en retard : le nombre de PÉRIODES, et le chemin', (
      testeur,
    ) async {
      final t = await _poser(
        testeur,
        session: _Session(
          echeancier: Echeancier(
            echeances: [_echeance('EN_RETARD', '2026-08-15', autres: 4)],
          ),
        ),
      );
      final resume = find.byKey(const Key('resume-echeances'));
      await _amener(testeur, resume);
      expect(find.text('5 périodes en retard'), findsOneWidget);
      await testeur.tap(resume);
      expect(t.onglets, [EcranTableauDeBord.ongletEcheances]);
    });

    testWidgets('à jour : la prochaine, avec sa date en toutes lettres', (
      testeur,
    ) async {
      await _poser(
        testeur,
        session: _Session(
          echeancier: Echeancier(
            echeances: [_echeance('A_VENIR', '2026-10-15')],
          ),
        ),
      );
      await _amener(testeur, find.byKey(const Key('resume-echeances')));
      expect(find.text('Prochaine : Cotisations sociales'), findsOneWidget);
      expect(find.textContaining('15 octobre 2026'), findsOneWidget);
    });
  });

  testWidgets('les derniers documents du cabinet, deux au plus', (
    testeur,
  ) async {
    final docs = [
      for (var i = 1; i <= 4; i++)
        DocumentRecu(
          numero: 'N-$i',
          titre: 'Déclaration $i',
          periode: 'mois $i',
          deposeLe: DateTime(2026, i, 10),
          guichet: 'DGI',
          verifiable: true,
        ),
    ];
    await _poser(
      testeur,
      session: _Session(documents: Documents(documents: docs)),
    );
    await _amener(testeur, find.byKey(const Key('voir-documents')));
    expect(find.textContaining('Déclaration'), findsNWidgets(2));
  });

  testWidgets("on se déconnecte depuis l'accueil", (testeur) async {
    // ⚠️ La déconnexion n'existait que sur l'onglet Déposer, à côté de
    // l'appareil photo : constaté en parcours, personne ne l'y cherche.
    final t = await _poser(testeur);
    await testeur.tap(find.byKey(const Key('accueil-sortir')));
    await testeur.pumpAndSettle();
    // 19 octobre 2026 : un seul appui ne suffit plus, on confirme.
    expect(t.deconnexions, 0);
    await testeur.tap(find.byKey(const Key('confirmer-deconnexion')));
    await testeur.pumpAndSettle();
    expect(t.deconnexions, 1);
  });

  testWidgets('« Mes pièces envoyées » s\'ouvre depuis les raccourcis', (
    testeur,
  ) async {
    final t = await _poser(testeur);
    await _amener(testeur, find.byKey(const Key('raccourci-pieces')));
    await testeur.tap(find.byKey(const Key('raccourci-pieces')));
    expect(t.mesPieces, 1);
  });

  testWidgets('rien ne déborde, en gros caractères', (testeur) async {
    testeur.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(testeur.platformDispatcher.clearTextScaleFactorTestValue);
    await _poser(testeur);
    for (var i = 0; i < 10; i++) {
      await testeur.drag(_page, const Offset(0, -300));
      await testeur.pumpAndSettle();
      expect(testeur.takeException(), isNull, reason: 'défilement $i');
    }
  });
}
