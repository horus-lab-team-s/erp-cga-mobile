import 'dart:io';

import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/domaine/depot.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:cga_mobile/ecrans/accueil.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/appareil_photo.dart';
import 'package:cga_mobile/ports/service_de_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// L'écran que l'adhérent regarde tous les jours : ce qu'il dit de sa file, et
/// ce qu'il lui laisse faire. Rien n'en était vérifié.
/// ─────────────────────────────────────────────────────────────────────────────

class SessionFeinte implements ServiceDeSession {
  SessionFeinte({this.dossiers = const ['M081234567890P'], this.panne = false});

  final List<String> dossiers;
  final bool panne;
  bool fermee = false;

  @override
  Future<bool> ouvrirUneSession(String c, String m) async => true;

  @override
  Future<void> fermerLaSession() async => fermee = true;

  @override
  Future<List<String>> mesDossiers() async {
    if (panne) throw const _Panne();
    return dossiers;
  }
}

class _Panne implements Exception {
  const _Panne();
}

class AppareilFeint implements AppareilPhoto {
  AppareilFeint(this.cache);

  final Directory cache;
  int prises = 0;

  @override
  Future<String?> photographier() async {
    prises++;
    final f = File('${cache.path}/p$prises.jpg');
    await f.writeAsBytes([0xFF, 0xD8, prises, 0xFF, 0xD9]);
    return f.path;
  }
}

Depot depot(String id) => Depot(
  identifiant: id,
  dossier: 'M081234567890P',
  cheminDuFichier: '/tmp/$id.jpg',
  prisLe: DateTime(2026, 9, 19),
);

/// Déroule l'envoi, puis s'arrête pendant que le bandeau est encore là.
///
/// ⚠️ TROIS PIÈGES, ET LES TROIS ONT COÛTÉ DES CAS ROUGES MAL COMPRIS.
///
/// 1. `pumpAndSettle` avance l'horloge jusqu'à ce que plus rien ne soit
///    programmé, donc **au-delà des quatre secondes** au bout desquelles un
///    bandeau se retire seul. Il s'affichait puis disparaissait, et l'on
///    cherchait le défaut dans l'écran.
///
/// 2. Deux battements ne suffisent pas : l'envoi enchaîne quatre attentes, et
///    chacune demande son tour de boucle.
///
/// 3. **Le plus fourbe.** L'envoi interroge le disque pour savoir s'il reste des
///    copies à effacer. Or `pump` n'avance qu'une horloge FEINTE : une lecture
///    de disque, elle, se termine sur la vraie boucle d'événements, et aucun
///    nombre de battements ne la fait aboutir. L'envoi restait bloqué là,
///    silencieusement, et l'on ne voyait qu'un bandeau manquant.
///
///    `runAsync` exécute hors de l'horloge feinte : c'est ce qui laisse
///    l'attente réelle se terminer.
Future<void> pousserJusquAuBandeau(WidgetTester testeur) async {
  for (var i = 0; i < 8; i++) {
    await testeur.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await testeur.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  late Directory racine;
  late Directory cache;
  late FileDAttente file;
  late PriseDeVue prise;

  setUp(() async {
    racine = await Directory.systemTemp.createTemp('cga-accueil-');
    cache = await Directory('${racine.path}/cache').create();
    file = FileDAttente(MagasinEnMemoire());
    prise = PriseDeVue(
      appareil: AppareilFeint(cache),
      file: file,
      photos: Directory('${racine.path}/photos'),
    );
  });

  tearDown(() async {
    if (await racine.exists()) await racine.delete(recursive: true);
  });

  Future<void> poser(
    WidgetTester testeur, {
    SessionFeinte? session,
    Future<Reponse> Function(Depot)? remettre,
    VoidCallback? quandDeconnecte,
  }) async {
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranAccueil(
          session: session ?? SessionFeinte(),
          file: file,
          priseDeVue: prise,
          remettre: remettre ?? (_) async => Reponse.accepte,
          quandDeconnecte: quandDeconnecte ?? () {},
        ),
      ),
    );
    await testeur.pumpAndSettle();
  }

  group('Ce que les compteurs disent', () {
    testWidgets('une file vide est une bonne nouvelle, pas un vide', (
      testeur,
    ) async {
      await poser(testeur);

      expect(find.text('Tout est parti.'), findsOneWidget);
      expect(find.text('Rien à reprendre.'), findsOneWidget);
      expect(
        testeur
            .widget<Text>(find.byKey(const Key('compteur-attente-nombre')))
            .data,
        '0',
      );
    });

    testWidgets('un compte non nul dit quoi en attendre', (testeur) async {
      await file.ajouter(depot('A'));
      await poser(testeur);

      expect(
        testeur
            .widget<Text>(find.byKey(const Key('compteur-attente-nombre')))
            .data,
        '1',
      );
      expect(
        find.textContaining('Partiront dès que le réseau'),
        findsOneWidget,
      );
    });

    testWidgets("une pièce refusée dit qu'il faut la reprendre", (
      testeur,
    ) async {
      await file.ajouter(depot('A'));
      await file.vider((_) async => Reponse.refuse);
      await poser(testeur);

      expect(
        testeur
            .widget<Text>(find.byKey(const Key('compteur-reprendre-nombre')))
            .data,
        '1',
      );
      // ⚠️ Un nombre ne dit pas quoi faire. La phrase, si.
      expect(find.textContaining('À rephotographier'), findsOneWidget);
    });
  });

  group('Le dossier', () {
    testWidgets('est écrit en toutes lettres', (testeur) async {
      await poser(testeur);

      expect(find.text('Dossier M081234567890P'), findsOneWidget);
    });

    testWidgets('plusieurs dossiers se comptent', (testeur) async {
      await poser(
        testeur,
        session: SessionFeinte(dossiers: const ['M081', 'M082']),
      );

      expect(find.text('2 dossiers à votre nom'), findsOneWidget);
    });

    testWidgets('sans dossier connu, on ne laisse pas photographier', (
      testeur,
    ) async {
      // ⚠️ Le bouton resterait actif, l'adhérent prendrait sa photo, et le
      // refus n'arriverait qu'après — quand la facture est rangée.
      await poser(testeur, session: SessionFeinte(dossiers: const []));

      final bouton = testeur.widget<FloatingActionButton>(
        find.byKey(const Key('bouton-photographier')),
      );
      expect(bouton.onPressed, isNull);
      expect(find.textContaining('Aucun dossier connu'), findsOneWidget);
    });

    testWidgets("une panne réseau au lancement ne fait pas planter l'écran", (
      testeur,
    ) async {
      await poser(testeur, session: SessionFeinte(panne: true));

      expect(find.textContaining('Aucun dossier connu'), findsOneWidget);
    });
  });

  group('Envoyer', () {
    testWidgets('est impossible quand il n\'y a rien à envoyer', (
      testeur,
    ) async {
      await poser(testeur);

      final bouton = testeur.widget<IconButton>(
        find.byKey(const Key('bouton-envoyer')),
      );
      expect(bouton.onPressed, isNull);
    });

    testWidgets('vide la file et le dit', (testeur) async {
      await file.ajouter(depot('A'));
      var appels = 0;
      await poser(
        testeur,
        remettre: (_) async {
          appels++;
          return Reponse.accepte;
        },
      );

      await testeur.tap(find.byKey(const Key('bouton-envoyer')));
      await pousserJusquAuBandeau(testeur);

      expect(appels, 1);
      expect(find.text('1 pièce envoyée.'), findsOneWidget);
      expect(
        testeur
            .widget<Text>(find.byKey(const Key('compteur-attente-nombre')))
            .data,
        '0',
      );
    });

    testWidgets('sans réseau, rassure au lieu d\'alarmer', (testeur) async {
      await file.ajouter(depot('A'));
      await poser(testeur, remettre: (_) async => Reponse.indisponible);

      await testeur.tap(find.byKey(const Key('bouton-envoyer')));
      await pousserJusquAuBandeau(testeur);

      expect(
        find.textContaining("Vos pièces partiront dès qu'il revient"),
        findsOneWidget,
      );
    });

    testWidgets('une session expirée renvoie à la connexion', (testeur) async {
      var sorti = false;
      await file.ajouter(depot('A'));
      await poser(
        testeur,
        remettre: (_) async => Reponse.sessionExpiree,
        quandDeconnecte: () => sorti = true,
      );

      await testeur.tap(find.byKey(const Key('bouton-envoyer')));
      await pousserJusquAuBandeau(testeur);

      expect(sorti, isTrue);
      // ⚠️ Et la pièce reste : rien n'a été refusé, personne n'a demandé.
      expect((await file.enAttente()).length, 1);
    });
  });

  group('Se déconnecter', () {
    testWidgets('ferme la session et prévient', (testeur) async {
      final session = SessionFeinte();
      var sorti = false;
      await poser(
        testeur,
        session: session,
        quandDeconnecte: () => sorti = true,
      );

      await testeur.tap(find.byKey(const Key('bouton-sortir')));
      await testeur.pumpAndSettle();

      expect(session.fermee, isTrue);
      expect(sorti, isTrue);
    });
  });
}
