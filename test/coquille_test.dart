import 'dart:async';
import 'dart:io';

import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/domaine/document_recu.dart';
import 'package:cga_mobile/domaine/echeance.dart';
import 'package:cga_mobile/domaine/mon_entreprise.dart';
import 'package:cga_mobile/domaine/preuve.dart';
import 'package:cga_mobile/domaine/depot.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/piece_remise.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:cga_mobile/ecrans/coquille.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/appareil_photo.dart';
import 'package:cga_mobile/ports/service_de_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soutien/espace_feint.dart';
import 'soutien/tableau_feint.dart';

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

class AppareilFeint implements AppareilPhoto {
  AppareilFeint(this.cache);
  final Directory cache;

  @override
  Future<String?> photographier() async => null;
}

/// Un dépôt dans la file, pour éprouver le compteur de la barre.
Depot depotDEssai(String id) => Depot(
  identifiant: id,
  dossier: 'M081234567890P',
  cheminDuFichier: '/tmp/$id.jpg',
  prisLe: DateTime(2026, 9, 27),
);

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
    EspaceFeint? espace,
  }) async {
    final s = session ?? SessionFeinte();
    espace ??= EspaceFeint();
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: Coquille(
          session: s,
          file: file,
          priseDeVue: prise,
          remettre: (_) async => Reponse.accepte,
          quandDeconnecte: () {},
          tableau: TableauFeint(),
          espace: espace,
        ),
      ),
    );
    await testeur.pumpAndSettle();
    return s;
  }

  testWidgets('Les cinq destinations sont là, et nommées', (testeur) async {
    await poser(testeur);

    // ⚠️ Cinq, et c'est le maximum : au-delà, une barre du bas se tasse et les
    // libellés deviennent illisibles sur un téléphone étroit. Le prochain écran
    // obligera à choisir ce qui descend d'un rang.
    expect(find.byKey(const Key('onglet-accueil')), findsOneWidget);
    expect(find.byKey(const Key('onglet-deposer')), findsOneWidget);
    expect(find.byKey(const Key('onglet-echeances')), findsOneWidget);
    expect(find.byKey(const Key('onglet-plus')), findsOneWidget);
    expect(find.byKey(const Key('onglet-documents')), findsOneWidget);
    for (final libelle in [
      'Accueil',
      'Échéances',
      'Déposer',
      'Documents',
      'Plus',
    ]) {
      expect(
        find.text(libelle),
        findsWidgets,
        reason: 'le mot accompagne l\'icône',
      );
    }
  });

  testWidgets('Le dépôt est mis en avant : plus grand que les autres onglets', (
    testeur,
  ) async {
    // ⚠️ L'adhérent ouvre l'application une facture à la main : le dépôt est ce
    // qu'il vient faire, le reste est de la consultation. Cinq onglets de même
    // taille ne le disaient pas.
    await poser(testeur);
    final depot = testeur.getSize(find.byKey(const Key('onglet-deposer')));
    // Une cible ronde et large : le pouce la trouve sans viser. Les recommandations
    // d'accessibilité demandent 48 points ; le geste principal en prend davantage.
    expect(depot.width, depot.height, reason: 'un rond, pas un onglet de plus');
    expect(depot.height, greaterThanOrEqualTo(56));
    final icones = testeur.widgetList<Icon>(find.byType(Icon)).toList();
    final appareil = icones.firstWhere(
      (i) => i.icon == Icons.photo_camera_rounded,
    );
    final maison = icones.firstWhere((i) => i.icon == Icons.home);
    expect(appareil.size, greaterThan(maison.size!));
    // ⚠️ ET IL EST AU CENTRE DE LA BARRE, sous le pouce : c'est la demande du
    // cabinet, et ce qui distingue le geste principal des quatre écrans qu'on
    // consulte. Son centre tombe à moins de deux points du milieu de l'écran.
    final centre = testeur.getCenter(find.byKey(const Key('onglet-deposer')));
    final milieu =
        testeur.view.physicalSize.width / testeur.view.devicePixelRatio / 2;
    expect((centre.dx - milieu).abs(), lessThan(2));
  });

  testWidgets(
    "Sur son propre onglet, le bouton central déclenche l'appareil photo",
    (testeur) async {
      // ⚠️ Sans cela, le bouton le plus visible de l'application ne ferait RIEN
      // sur l'écran où l'adhérent l'attend le plus. Ici, aucun dossier n'est
      // rattaché : la prise de vue s'arrête et le dit, au lieu de se taire.
      await poser(testeur, session: SessionFeinte(dossiers: const []));
      await testeur.tap(find.byKey(const Key('onglet-deposer')));
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('onglet-deposer')));
      await testeur.pumpAndSettle();

      expect(
        find.text('Aucun dossier ouvert à votre nom. Voyez avec le cabinet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Chaque destination reste touchable au pouce', (testeur) async {
    // ⚠️ Quarante-huit points de haut au minimum : c'est le seuil des règles
    // d'accessibilité, et la taille d'un pouce sur une dalle de six pouces. La
    // barre a changé de forme ; ce cas empêche qu'elle s'amincisse un jour sans
    // que personne ne le mesure.
    await poser(testeur);
    for (final cle in [
      'onglet-accueil',
      'onglet-echeances',
      'onglet-deposer',
      'onglet-documents',
      'onglet-plus',
    ]) {
      final taille = testeur.getSize(find.byKey(Key(cle)));
      expect(taille.height, greaterThanOrEqualTo(48), reason: cle);
      expect(taille.width, greaterThanOrEqualTo(48), reason: cle);
    }
  });

  testWidgets('Chaque onglet ouvre bien son écran', (testeur) async {
    await poser(testeur);
    // ⚠️ L'application connectée s'ouvre sur l'ACCUEIL, et non plus sur
    // l'appareil photo : l'adhérent veut d'abord savoir où il en est.
    expect(find.byKey(const Key('salutation')), findsOneWidget);

    await testeur.tap(find.byKey(const Key('onglet-deposer')));
    await testeur.pumpAndSettle();
    expect(find.text('Mes justificatifs'), findsOneWidget);

    await testeur.tap(find.byKey(const Key('onglet-echeances')));
    await testeur.pumpAndSettle();
    expect(find.text('Mes échéances'), findsOneWidget);

    // 18 octobre 2026 : « Plus » remplace « Entreprise », et mène à elle.
    await testeur.tap(find.byKey(const Key('onglet-plus')));
    await testeur.pumpAndSettle();
    // ⚠️ On vise le titre de l'ÉCRAN, pas n'importe quel texte : le libellé de
    // l'onglet vit dans le même arbre, et un `find.text` nu les confondrait.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Mon espace'),
      ),
      findsOneWidget,
    );
    await testeur.tap(find.byKey(const Key('plus-entreprise')));
    await testeur.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Mon entreprise'),
      ),
      findsOneWidget,
    );
    await testeur.pageBack();
    await testeur.pumpAndSettle();

    await testeur.tap(find.byKey(const Key('onglet-documents')));
    await testeur.pumpAndSettle();
    expect(find.text('Mes documents'), findsOneWidget);
  });

  testWidgets(
    'Des honoraires dus se signalent à l\'accueil et mènent au paiement',
    (testeur) async {
      // 18 octobre 2026 : le règlement est rangé sous « Plus » ; sans cette carte,
      // un adhérent en retard ne le trouverait qu'en cherchant.
      await poser(testeur, espace: EspaceFeint(honoraires: honorairesDEssai()));
      // ⚠️ Remontée AU-DESSUS de la barre flottante, qui prendrait le toucher.
      await Scrollable.ensureVisible(
        testeur.element(find.byKey(const Key('accueil-honoraires'))),
        alignment: 0.3,
      );
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('accueil-honoraires')));
      await testeur.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Mes honoraires'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Rien n\'est dû : l\'accueil ne parle pas d\'honoraires', (
    testeur,
  ) async {
    await poser(testeur);
    expect(find.byKey(const Key('accueil-honoraires')), findsNothing);
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
      await testeur.tap(find.byKey(const Key('onglet-documents')));
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
            tableau: TableauFeint(),
            espace: EspaceFeint(),
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
      // ⚠️ Deux lectures désormais — l'accueil résume les échéances, l'onglet
      // les détaille —, mais toutes sur le bon dossier.
      expect(session.demandesDEcheances, isNotEmpty);
      expect(session.demandesDEcheances, everyElement('M081234567890P'));
    },
  );

  testWidgets('Une panne réseau au lancement ne fait pas planter la coquille', (
    testeur,
  ) async {
    // ⚠️ Ce cas vivait sur l'écran d'accueil, qui lisait alors les dossiers
    // lui-même. Il a déménagé avec la responsabilité.
    await poser(testeur, session: SessionFeinte(panne: true));

    expect(find.text('Aucun dossier à votre nom'), findsOneWidget);
    expect(find.byKey(const Key('onglet-deposer')), findsOneWidget);
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

  // ══ Ce que la barre dit sans qu'on ouvre l'onglet ═════════════════════════
  //
  // ⚠️ UNE PIÈCE QUI ATTEND EST LA SEULE CHOSE QUE L'APPLICATION SAIT ET QUE LE
  // SERVEUR IGNORE. Hors réseau, elle n'existe que sur ce téléphone. Rien ne la
  // signalait tant qu'on n'ouvrait pas l'onglet du dépôt : on consultait ses
  // échéances sans savoir qu'une facture attendait à deux écrans de là.
  group('Le compteur du bouton de dépôt', () {
    testWidgets('reste muet quand rien n\'attend', (testeur) async {
      await poser(testeur);

      expect(find.text('1'), findsNothing);
      expect(find.text('9+'), findsNothing);
    });

    testWidgets('annonce ce qui attend, depuis n\'importe quel onglet', (
      testeur,
    ) async {
      await file.ajouter(depotDEssai('A'));
      await poser(testeur);

      // On reste sur l'accueil : le compteur doit se voir de là.
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets(
      's\'arrête à « 9+ », parce que trois chiffres ne se lisent pas',
      (testeur) async {
        for (var i = 0; i < 12; i++) {
          await file.ajouter(depotDEssai('P$i'));
        }
        await poser(testeur);

        expect(find.text('9+'), findsOneWidget);
        expect(find.text('12'), findsNothing);
      },
    );
  });
}
