import 'dart:async';
import 'dart:io';

import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/domaine/echeance.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/piece_remise.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:cga_mobile/ecrans/coquille.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/appareil_photo.dart';
import 'package:cga_mobile/ports/service_de_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// La charpente : les trois destinations, et surtout le fait que les dossiers
/// sont lus UNE SEULE FOIS pour les trois écrans. Chaque écran les relisait
/// pour son compte, ce qui faisait trois appels à chaque ouverture sur un
/// réseau qu'on sait mauvais, et pouvait laisser un sélecteur de dossier
/// présent sur un écran et absent sur l'autre.
/// ─────────────────────────────────────────────────────────────────────────────

class SessionFeinte implements ServiceDeSession {
  SessionFeinte({this.dossiers = const ['M081234567890P'], this.panne = false});

  final List<String> dossiers;
  final bool panne;

  /// Combien de fois les dossiers ont été demandés. ⚠️ C'est l'objet du cas le
  /// plus important de ce fichier.
  int demandesDeDossiers = 0;

  @override
  Future<bool> ouvrirUneSession(String c, String m) async => true;

  @override
  Future<void> fermerLaSession() async {}

  @override
  Future<List<String>> mesDossiers() async {
    demandesDeDossiers++;
    if (panne) throw const SocketException('réseau absent');
    final differee = attente;
    if (differee != null) return differee.future;
    return dossiers;
  }

  /// Quand elle est posée, la lecture des dossiers ne rend rien tant qu'on ne
  /// l'achève pas : c'est ce qui permet d'observer ce que font les écrans
  /// PENDANT l'attente.
  Completer<List<String>>? attente;

  /// Les dossiers sur lesquels l'écran des échéances a interrogé le serveur.
  final List<String> demandesDEcheances = [];

  @override
  Future<Historique> mesPieces(String dossier) async => const Historique();

  @override
  Future<Echeancier> mesEcheances(String dossier) async {
    demandesDEcheances.add(dossier);
    return const Echeancier();
  }
}

class AppareilFeint implements AppareilPhoto {
  AppareilFeint(this.cache);
  final Directory cache;

  @override
  Future<String?> photographier() async => null;
}

void main() {
  late Directory racine;
  late FileDAttente file;
  late PriseDeVue prise;

  setUp(() async {
    racine = await Directory.systemTemp.createTemp('coquille');
    file = FileDAttente(MagasinEnMemoire());
    prise = PriseDeVue(
      appareil: AppareilFeint(racine),
      file: file,
      photos: Directory('${racine.path}/photos'),
    );
  });

  tearDown(() async {
    if (await racine.exists()) await racine.delete(recursive: true);
  });

  Future<SessionFeinte> poser(
    WidgetTester testeur, {
    SessionFeinte? session,
  }) async {
    final s = session ?? SessionFeinte();
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: Coquille(
          session: s,
          file: file,
          priseDeVue: prise,
          remettre: (_) async => Reponse.accepte,
          quandDeconnecte: () {},
        ),
      ),
    );
    await testeur.pumpAndSettle();
    return s;
  }

  testWidgets('Les trois destinations sont là, et nommées', (testeur) async {
    await poser(testeur);

    // ⚠️ Trois, et pas cinq. « Mes documents » et « Mon entreprise » ne sont pas
    // écrits : les annoncer montrerait à l'adhérent des portes qui ne s'ouvrent
    // pas.
    expect(find.byKey(const Key('onglet-deposer')), findsOneWidget);
    expect(find.byKey(const Key('onglet-echeances')), findsOneWidget);
    expect(find.byKey(const Key('onglet-pieces')), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
  });

  testWidgets('Chaque onglet ouvre bien son écran', (testeur) async {
    await poser(testeur);
    expect(find.text('Mes justificatifs'), findsOneWidget);

    await testeur.tap(find.byKey(const Key('onglet-echeances')));
    await testeur.pumpAndSettle();
    expect(find.text('Mes échéances'), findsOneWidget);

    await testeur.tap(find.byKey(const Key('onglet-pieces')));
    await testeur.pumpAndSettle();
    expect(find.text('Pièces remises'), findsOneWidget);
  });

  testWidgets(
    'Les dossiers sont lus UNE FOIS, et non par chacun des trois écrans',
    (testeur) async {
      // ⚠️ LE CAS QUI JUSTIFIE LA COQUILLE. Chaque écran lisait `/transverse/moi`
      // pour son compte : trois appels à l'ouverture, plus un à chaque retour
      // d'onglet, sur le forfait de l'adhérent. Et si l'un des trois échouait,
      // le sélecteur de dossier apparaissait sur un écran et pas sur l'autre.
      final session = await poser(testeur);
      expect(session.demandesDeDossiers, 1);

      await testeur.tap(find.byKey(const Key('onglet-echeances')));
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('onglet-pieces')));
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('onglet-deposer')));
      await testeur.pumpAndSettle();

      expect(session.demandesDeDossiers, 1);
    },
  );

  testWidgets(
    "Les écrans qui interrogent le serveur attendent de connaître le dossier",
    (testeur) async {
      // ⚠️ LE DÉFAUT QUE SEUL L'APPAREIL A MONTRÉ. La coquille construisait les
      // trois écrans d'emblée, avec une liste de dossiers encore vide. Les
      // écrans d'échéances et d'historique interrogeaient donc le serveur sur
      // un dossier vide, recevaient 404, et retenaient « pas de réseau ».
      // L'adhérent ouvrait l'onglet sur un message de panne alors que tout
      // fonctionnait.
      final attente = Completer<List<String>>();
      final session = SessionFeinte()..attente = attente;
      await testeur.pumpWidget(
        MaterialApp(
          theme: themeClair(),
          home: Coquille(
            session: session,
            file: file,
            priseDeVue: prise,
            remettre: (_) async => Reponse.accepte,
            quandDeconnecte: () {},
          ),
        ),
      );
      await testeur.pump();

      // Tant que les dossiers ne sont pas connus, aucune interrogation.
      await testeur.tap(find.byKey(const Key('onglet-echeances')));
      await testeur.pump();
      expect(session.demandesDEcheances, isEmpty);

      attente.complete(const ['M081234567890P']);
      await testeur.pumpAndSettle();

      // Une fois connus, et sur le bon dossier, jamais sur une chaîne vide.
      expect(session.demandesDEcheances, const ['M081234567890P']);
    },
  );

  testWidgets('Une panne réseau au lancement ne fait pas planter la coquille', (
    testeur,
  ) async {
    // ⚠️ Ce cas vivait sur l'écran d'accueil, qui lisait alors les dossiers
    // lui-même. Il a déménagé avec la responsabilité.
    await poser(testeur, session: SessionFeinte(panne: true));

    expect(find.text('Aucun dossier à votre nom'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets("Changer d'onglet ne perd pas l'écran qu'on quitte", (
    testeur,
  ) async {
    // `IndexedStack` : chaque écran garde son état et sa position de
    // défilement. Reconstruire à chaque passage redemanderait au serveur à
    // chaque coup d'onglet.
    await poser(testeur);

    await testeur.tap(find.byKey(const Key('onglet-echeances')));
    await testeur.pumpAndSettle();
    await testeur.tap(find.byKey(const Key('onglet-deposer')));
    await testeur.pumpAndSettle();

    expect(find.byType(IndexedStack), findsOneWidget);
    expect(find.text('Mes justificatifs'), findsOneWidget);
  });
}
