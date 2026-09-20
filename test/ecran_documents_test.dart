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
  }) async {
    final s = SessionFeinte(documents: documents);
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranDocuments(
          session: s,
          dossiers: const ['M081234567890P'],
          quandSessionExpire: () {},
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
      find.textContaining('février 2024 · Impôts (DGI) · déposé le 15 mars 2024'),
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
}
