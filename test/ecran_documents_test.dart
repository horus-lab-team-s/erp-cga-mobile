import 'package:cga_mobile/domaine/document_recu.dart';
import 'package:cga_mobile/domaine/echeance.dart';
import 'package:cga_mobile/domaine/mon_entreprise.dart';
import 'package:cga_mobile/domaine/piece_remise.dart';
import 'package:cga_mobile/domaine/preuve.dart';
import 'package:cga_mobile/ecrans/documents.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/service_de_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// Les accusés de dépôt : la preuve que le cabinet a déposé au nom de
/// l'adhérent. ⚠️ Deux cas comptent plus que l'affichage lui-même :
///
///   · le montant arrive en CHAÎNE sur cette route, là où la liste des pièces
///     le rend en nombre. Un transtypage direct rendrait `null` partout ;
///   · un accusé sans justificatif archivé le DIT, au lieu de laisser croire à
///     une preuve pleine.
/// ─────────────────────────────────────────────────────────────────────────────

class SessionFeinte implements ServiceDeSession {
  SessionFeinte({this.documents = const Documents()});
  Documents documents;

  @override
  Future<bool> ouvrirUneSession(String c, String m) async => true;
  @override
  Future<void> fermerLaSession() async {}
  @override
  Future<List<String>> mesDossiers() async => const ['M081234567890P'];
  @override
  Future<Historique> mesPieces(String d) async => const Historique();
  @override
  Future<Echeancier> mesEcheances(String d) async => const Echeancier();
  @override
  Future<Preuve> envoyerLaPreuve({
    required String dossier,
    required Echeance echeance,
    required String cheminDeLaPhoto,
  }) async => Preuve.recue;
  @override
  Future<Fiche> monEntreprise(String d) async => const Fiche();
  @override
  Future<SortDuSignalement> signalerUnChangement({
    required String dossier,
    required String nature,
    required String message,
  }) async => SortDuSignalement.transmis;

  @override
  Future<Documents> mesDocuments(String dossier) async => documents;
}

DocumentRecu document({
  String numero = 'DGI-2024-02-121877',
  String titre = 'TVA du mois',
  String periode = 'février 2024',
  String guichet = 'Impôts (DGI)',
  String deposeLe = '2024-03-15T08:48:00',
  Object? montant = '1340000.00',
  bool verifiable = false,
}) => DocumentRecu.depuisJson({
  'numero': numero,
  'titre': titre,
  'periode': periode,
  'depose_le': deposeLe,
  'guichet': guichet,
  'montant_constate': montant,
  'verifiable': verifiable,
});

void main() {
  Future<SessionFeinte> poser(
    WidgetTester testeur, {
    Documents documents = const Documents(),
    VoidCallback? ouvrirLHistorique,
    void Function(String dossier, String numero)? ouvrirLeRecu,
  }) async {
    final s = SessionFeinte(documents: documents);
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranDocuments(
          session: s,
          dossiers: const ['M081234567890P'],
          quandSessionExpire: () {},
          ouvrirLHistorique: ouvrirLHistorique,
          ouvrirLeRecu: ouvrirLeRecu,
        ),
      ),
    );
    return s;
  }

  group('Le montant, selon la forme que le serveur lui donne', () {
    test('en chaîne, comme sur cette route', () {
      // ⚠️ « 1340000.00 » : cette route sérialise un décimal en TEXTE, là où la
      // liste des pièces rend un nombre. Un transtypage direct vers un décimal
      // rendrait `null` sur toutes les lignes, et aucun montant ne s'afficherait.
      expect(document(montant: '1340000.00').montantConstate, 1340000.0);
    });

    test('en nombre, si le serveur change d\'avis', () {
      expect(document(montant: 1340000).montantConstate, 1340000.0);
      expect(document(montant: 1340000.75).montantConstate, 1340000.75);
    });

    test('absent, sans faire tomber la ligne', () {
      expect(document(montant: null).montantConstate, isNull);
    });
  });

  testWidgets('Un accusé montre son titre, sa période, son guichet', (
    testeur,
  ) async {
    await poser(testeur, documents: Documents(documents: [document()]));
    await testeur.pumpAndSettle();

    expect(find.text('TVA du mois'), findsOneWidget);
    expect(find.text('1 340 000 F'), findsOneWidget);
    expect(
      find.textContaining(
        'février 2024 · Impôts (DGI) · déposé le 15 mars 2024',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Le numéro se copie d\'un appui', (testeur) async {
    // ⚠️ C'est la seule référence que l'administration reconnaîtra. La lire à
    // voix haute au téléphone ou la recopier à la main invite la faute.
    final copies = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (appel) async {
          if (appel.method == 'Clipboard.setData') {
            copies.add((appel.arguments as Map)['text'] as String);
          }
          return null;
        });

    await poser(testeur, documents: Documents(documents: [document()]));
    await testeur.pumpAndSettle();

    await testeur.tap(find.byKey(const Key('copier-DGI-2024-02-121877')));
    await testeur.pumpAndSettle();

    expect(copies, const ['DGI-2024-02-121877']);
    expect(find.textContaining('copié'), findsOneWidget);
  });

  testWidgets('Sur une carte qui ouvre le reçu, copier copie, et n\'ouvre pas', (
    testeur,
  ) async {
    // 19 octobre 2026 : l'encre de la carte recouvrait le bouton, et l'appui ouvrait
    // le reçu à la place. Le cas échappait au test, qui ne branchait pas le reçu.
    final copies = <String>[];
    final ouverts = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (appel) async {
          if (appel.method == 'Clipboard.setData') {
            copies.add((appel.arguments as Map)['text'] as String);
          }
          return null;
        });

    await poser(
      testeur,
      documents: Documents(documents: [document()]),
      ouvrirLeRecu: (dossier, numero) => ouverts.add(numero),
    );
    await testeur.pumpAndSettle();

    await testeur.tap(find.byKey(const Key('copier-DGI-2024-02-121877')));
    await testeur.pumpAndSettle();

    expect(copies, const ['DGI-2024-02-121877']);
    expect(ouverts, isEmpty);
  });

  group('La force de la preuve', () {
    testWidgets('un accusé sans justificatif archivé le DIT', (testeur) async {
      // ⚠️ Il repose alors sur la parole de celui qui a saisi le numéro. Le
      // taire laisserait l'adhérent s'en prévaloir devant l'administration en
      // croyant tenir une pièce.
      await poser(
        testeur,
        documents: Documents(documents: [document(verifiable: false)]),
      );
      await testeur.pumpAndSettle();

      expect(
        find.textContaining('Aucun justificatif n\'est archivé'),
        findsOneWidget,
      );
    });

    testWidgets('un accusé justifié ne dit rien de tel', (testeur) async {
      await poser(
        testeur,
        documents: Documents(documents: [document(verifiable: true)]),
      );
      await testeur.pumpAndSettle();

      expect(find.textContaining('Aucun justificatif'), findsNothing);
    });
  });

  testWidgets('Pas de réseau ne se dit jamais « aucun accusé »', (
    testeur,
  ) async {
    await poser(testeur, documents: const Documents(serveurJoignable: false));
    await testeur.pumpAndSettle();

    expect(find.text('Pas de réseau'), findsOneWidget);
    expect(find.text('Aucun accusé de dépôt'), findsNothing);
  });

  testWidgets('Un dossier réellement sans accusé le dit, et rassure', (
    testeur,
  ) async {
    await poser(testeur);
    await testeur.pumpAndSettle();

    expect(find.text('Aucun accusé de dépôt'), findsOneWidget);
    expect(find.text('Pas de réseau'), findsNothing);
  });

  // ══ L'autre sens ══════════════════════════════════════════════════════════
  //
  // ⚠️ CET ÉCRAN NE MONTRAIT QU'UNE MOITIÉ DES DOCUMENTS DE L'ADHÉRENT.
  //
  // Les accusés déposés PAR le cabinet y étaient ; les pièces remises AU
  // cabinet vivaient sur un écran distinct auquel rien ne menait depuis ici.
  // Or « Documents » est l'onglet où l'on cherche un document, quel qu'en soit
  // le sens : y taire la moitié revenait à la cacher.
  group('La porte vers les pièces remises', () {
    testWidgets('mène bien à l\'historique', (testeur) async {
      var ouvert = 0;
      await poser(
        testeur,
        documents: Documents(documents: [document()]),
        ouvrirLHistorique: () => ouvert++,
      );
      await testeur.pumpAndSettle();

      expect(find.byKey(const Key('vers-historique')), findsOneWidget);
      await testeur.tap(find.byKey(const Key('vers-historique')));
      await testeur.pumpAndSettle();
      expect(ouvert, 1);
    });
  });

  // ══ La recherche ══════════════════════════════════════════════════════════
  //
  // ⚠️ SOIXANTE-CINQ ACCUSÉS SUR UN ÉCRAN DE TÉLÉPHONE. Mesuré sur le jeu réel
  // du dossier de démonstration : retrouver celui de février 2024 demandait
  // quatorze glissements. La liste existait, l'information aussi ; c'est
  // l'accès qui manquait.
  group('Retrouver un accusé', () {
    List<DocumentRecu> beaucoup() => [
      for (var i = 1; i <= 10; i++)
        document(
          numero: 'DGI-2024-${i.toString().padLeft(2, '0')}-00$i',
          periode: i == 2 ? 'février 2024' : 'mois $i 2024',
          titre: i.isEven ? 'TVA du mois' : 'Acompte',
        ),
    ];

    testWidgets('le champ ne paraît pas sur une liste courte', (testeur) async {
      await poser(
        testeur,
        documents: Documents(documents: [document(), document()]),
      );
      await testeur.pumpAndSettle();

      // ⚠️ Sur deux accusés, on lit plus vite qu'on ne tape.
      expect(find.byKey(const Key('champ-de-recherche')), findsNothing);
    });

    testWidgets('il paraît dès que la liste dépasse un écran', (testeur) async {
      await poser(testeur, documents: Documents(documents: beaucoup()));
      await testeur.pumpAndSettle();

      expect(find.byKey(const Key('champ-de-recherche')), findsOneWidget);
    });

    testWidgets('« fevrier » sans accent trouve « février »', (testeur) async {
      // ⚠️ LE CAS QUI JUSTIFIE TOUT LE FICHIER `recherche.dart`. On ne va pas
      // chercher la touche des accents pour filtrer une liste.
      await poser(testeur, documents: Documents(documents: beaucoup()));
      await testeur.pumpAndSettle();

      await testeur.enterText(
        find.byKey(const Key('champ-de-recherche')),
        'fevrier',
      );
      await testeur.pumpAndSettle();

      expect(find.text('DGI-2024-02-0022'), findsNothing);
      expect(find.textContaining('février 2024'), findsOneWidget);
      expect(find.text('1 sur 10'), findsOneWidget);
    });

    testWidgets('rien trouvé ne se dit JAMAIS « aucun accusé »', (
      testeur,
    ) async {
      await poser(testeur, documents: Documents(documents: beaucoup()));
      await testeur.pumpAndSettle();

      await testeur.enterText(
        find.byKey(const Key('champ-de-recherche')),
        'quelque chose qui n\'existe pas',
      );
      await testeur.pumpAndSettle();

      expect(find.byKey(const Key('rien-ne-correspond')), findsOneWidget);
      expect(
        find.textContaining('Vos autres documents sont toujours là'),
        findsOneWidget,
      );
      // ⚠️ Le message des listes vides ne doit PAS apparaître : il dirait que
      // le cabinet n'a rien déposé, et ferait appeler en urgence.
      expect(find.text('Aucun accusé de dépôt'), findsNothing);
    });

    testWidgets('« Tout revoir » rend la liste entière', (testeur) async {
      await poser(testeur, documents: Documents(documents: beaucoup()));
      await testeur.pumpAndSettle();

      await testeur.enterText(
        find.byKey(const Key('champ-de-recherche')),
        'introuvable',
      );
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('tout-revoir')));
      await testeur.pumpAndSettle();

      expect(find.byKey(const Key('rien-ne-correspond')), findsNothing);
      expect(find.text('10 accusés de dépôt'), findsOneWidget);
    });
  });

  // ⚠️ LE CAS QUI TIENT LE CONTRÔLEUR DE TEXTE.
  //
  // La première écriture du champ fabriquait son `TextEditingController` dans
  // `build`. La liste se reconstruisant à chaque frappe, le champ recevait un
  // contrôleur neuf à chaque lettre et perdait la région de composition — donc
  // la saisie prédictive et les accents composés du clavier Android. Un champ
  // fait pour chercher « février » qui casse sur les accents.
  //
  // Ce cas frappe lettre par lettre et vérifie que le texte s'accumule, que le
  // curseur reste au bout, et que le filtre suit.
  testWidgets('le champ garde ce qu\'on tape, lettre après lettre', (
    testeur,
  ) async {
    await poser(
      testeur,
      documents: Documents(
        documents: [
          for (var i = 1; i <= 10; i++)
            document(
              numero: 'DGI-2024-${i.toString().padLeft(2, '0')}-00$i',
              periode: i == 2 ? 'février 2024' : 'mois $i 2024',
            ),
        ],
      ),
    );
    await testeur.pumpAndSettle();

    final champ = find.byKey(const Key('champ-de-recherche'));
    for (final morceau in ['f', 'fe', 'fev', 'fevr']) {
      await testeur.enterText(champ, morceau);
      await testeur.pumpAndSettle();
      final saisi = testeur.widget<TextField>(champ).controller!;
      expect(saisi.text, morceau);
      expect(
        saisi.selection.baseOffset,
        morceau.length,
        reason: 'Le curseur doit rester au bout de ce qui est tapé.',
      );
    }
    expect(find.textContaining('février 2024'), findsOneWidget);
  });

  testWidgets('Toucher un accusé ouvre son reçu de dépôt', (testeur) async {
    // 18 octobre 2026 : « je ne vois que les références ». Chaque accusé a sa
    // miniature, et son reçu PDF s'ouvre d'un toucher.
    final ouverts = <String>[];
    await poser(
      testeur,
      documents: Documents(documents: [document()]),
      ouvrirLeRecu: (dossier, numero) => ouverts.add('$dossier/$numero'),
    );
    await testeur.pumpAndSettle();

    expect(find.text('DÉPOSÉE'), findsOneWidget);
    await testeur.tap(find.text('Voir le reçu'));
    expect(ouverts.single, startsWith('M081234567890P/'));
  });
}
