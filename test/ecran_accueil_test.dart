import 'dart:io';

import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/domaine/depot.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/document_recu.dart';
import 'package:cga_mobile/domaine/echeance.dart';
import 'package:cga_mobile/domaine/mon_entreprise.dart';
import 'package:cga_mobile/domaine/preuve.dart';
import 'package:cga_mobile/domaine/piece_remise.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:cga_mobile/ecrans/apercu_du_depot.dart';
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

  /// ⚠️ La doublure rend un historique VIDE et non une erreur : ces cas-ci
  /// portent sur la file d'attente, pas sur l'historique. Celui-ci a ses
  /// propres cas, dans `ecran_historique_test.dart`.
  @override
  Future<Historique> mesPieces(String dossier) async => const Historique();

  /// ⚠️ La doublure rend un échéancier VIDE : ces cas-ci ne portent pas sur les
  /// échéances, qui ont leur propre fichier.
  @override
  Future<Echeancier> mesEcheances(String dossier) async => const Echeancier();

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
    List<String> dossiers = const ['M081234567890P'],
    VoidCallback? ouvrirLHistorique,
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
          // ⚠️ Les dossiers viennent désormais de la coquille, qui les lit une
          // fois pour les trois écrans. L'accueil ne les relit plus.
          dossiers: dossiers,
          ouvrirLHistorique: ouvrirLHistorique,
        ),
      ),
    );
    await testeur.pumpAndSettle();
  }

  group('Les deux façons de remettre une pièce (18 octobre 2026)', () {
    testWidgets('sans galerie branchée, seul l\'appareil photo est proposé', (
      testeur,
    ) async {
      await poser(testeur);

      expect(find.byKey(const Key('bouton-photographier')), findsOneWidget);
      expect(find.byKey(const Key('bouton-galerie')), findsNothing);
    });

    testWidgets('la galerie remet une pièce déjà reçue en image', (
      testeur,
    ) async {
      final galerie = AppareilFeint(cache);
      prise = PriseDeVue(
        appareil: AppareilFeint(cache),
        galerie: galerie,
        file: file,
        photos: Directory('${racine.path}/photos'),
      );
      final remis = <Depot>[];
      await poser(
        testeur,
        remettre: (d) async {
          remis.add(d);
          return Reponse.accepte;
        },
      );

      await testeur.runAsync(() async {
        await testeur.tap(find.byKey(const Key('bouton-galerie')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await testeur.pumpAndSettle();

      // 19 octobre 2026 : l'aperçu AVANT l'envoi, et ce que l'adhérent en dit.
      expect(find.text('Vérifier la pièce'), findsOneWidget);
      await testeur.scrollUntilVisible(
        find.byKey(const Key('nature-FACTURE_ACHAT')),
        300,
        scrollable: _defilementDeLApercu(),
      );
      await testeur.ensureVisible(
        find.byKey(const Key('nature-FACTURE_ACHAT')),
      );
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('nature-FACTURE_ACHAT')));
      await testeur.pump();
      await testeur.enterText(
        find.byKey(const Key('apercu-emetteur')),
        'QUINCAILLERIE DU WOURI',
      );
      await testeur.enterText(
        find.byKey(const Key('apercu-montant')),
        '178875',
      );
      await testeur.scrollUntilVisible(
        find.byKey(const Key('apercu-envoyer')),
        300,
        scrollable: _defilementDeLApercu(),
      );
      await testeur.ensureVisible(find.byKey(const Key('apercu-envoyer')));
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('apercu-envoyer')));
      await pousserJusquAuBandeau(testeur);

      expect(galerie.prises, 1);
      expect(
        find.text('Enregistrée. Elle partira toute seule.'),
        findsOneWidget,
      );
      final remise = remis.single.connaissance!.versLaRemise();
      expect(remise['type'], 'FACTURE_ACHAT');
      expect(remise['emetteur'], 'QUINCAILLERIE DU WOURI');
      expect(remise['montant_ttc'], 178875);
      expect(
        remise.containsKey('commentaire'),
        isFalse,
        reason: 'rien de vide ne part',
      );
    });

    testWidgets('reprendre la photo rouvre la source, sans rien mettre en file', (
      testeur,
    ) async {
      final galerie = AppareilFeint(cache);
      prise = PriseDeVue(
        appareil: AppareilFeint(cache),
        galerie: galerie,
        file: file,
        photos: Directory('${racine.path}/photos'),
      );
      await poser(testeur);

      await testeur.runAsync(() async {
        await testeur.tap(find.byKey(const Key('bouton-galerie')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await testeur.pumpAndSettle();
      await testeur.scrollUntilVisible(
        find.byKey(const Key('apercu-reprendre')),
        300,
        scrollable: _defilementDeLApercu(),
      );
      await testeur.ensureVisible(find.byKey(const Key('apercu-reprendre')));
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('apercu-reprendre')));
      // La copie s'efface et la source se rouvre : du disque, hors de l'horloge feinte.
      for (var i = 0; i < 6; i++) {
        await testeur.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await testeur.pump(const Duration(milliseconds: 100));
      }
      await testeur.pumpAndSettle();

      expect(galerie.prises, 2);
      expect(find.text('Vérifier la pièce'), findsOneWidget);
      expect(await file.enAttente(), isEmpty);
    });
  });

  group('Un scan déjà fait (19 octobre 2026)', () {
    testWidgets('un PDF passe par sa fiche, garde son extension et part', (
      testeur,
    ) async {
      final scans = _ScanFeint(cache);
      prise = PriseDeVue(
        appareil: AppareilFeint(cache),
        fichiers: scans,
        file: file,
        photos: Directory('${racine.path}/photos'),
      );
      final remis = <Depot>[];
      await poser(
        testeur,
        remettre: (d) async {
          remis.add(d);
          return Reponse.accepte;
        },
      );

      await testeur.scrollUntilVisible(
        find.byKey(const Key('bouton-fichier')),
        200,
      );
      await testeur.runAsync(() async {
        await testeur.tap(find.byKey(const Key('bouton-fichier')));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await testeur.pumpAndSettle();

      expect(find.text('Vérifier le scan'), findsOneWidget);
      expect(find.byKey(const Key('apercu-scan')), findsOneWidget);
      expect(find.textContaining('Document PDF'), findsOneWidget);
      await testeur.scrollUntilVisible(
        find.byKey(const Key('apercu-envoyer')),
        300,
        scrollable: _defilementDeLApercu(),
      );
      expect(find.text('Choisir un autre fichier'), findsOneWidget);
      await testeur.ensureVisible(find.byKey(const Key('apercu-envoyer')));
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('apercu-envoyer')));
      await pousserJusquAuBandeau(testeur);

      expect(scans.prises, 1);
      expect(remis.single.cheminDuFichier, endsWith('.pdf'));
    });

    testWidgets('sans source de fichiers, on ne propose pas le scan', (
      testeur,
    ) async {
      await poser(testeur);
      expect(find.byKey(const Key('bouton-fichier')), findsNothing);
    });
  });

  group("Le verdict, en tête d'écran", () {
    testWidgets('une file vide conclut, au lieu de compter', (testeur) async {
      await poser(testeur);

      // ⚠️ L'adhérent ne vient pas lire un tableau de bord : il vient savoir si
      // ses pièces sont parties. La phrase conclut à sa place.
      expect(find.text('Tout est parti'), findsOneWidget);
      expect(
        find.textContaining('photographiées sur ce téléphone'),
        findsOneWidget,
      );
      // ⚠️ Et JAMAIS « rien ne vous attend » : l'écran ne connaît que sa
      // propre file, pas ce que le cabinet attend encore. Sur le téléphone,
      // l'accueil disait « Il manque 3 justificatifs » au même moment.
      expect(find.textContaining('Rien ne vous attend'), findsNothing);
    });

    testWidgets('une pièce en attente dit quoi en attendre', (testeur) async {
      await file.ajouter(depot('A'));
      await poser(testeur);

      expect(find.text('Une pièce attend'), findsOneWidget);
      // ⚠️ LA PHRASE A CHANGÉ LE 27 SEPTEMBRE, ET CE N'EST PAS DU STYLE.
      //
      // Elle disait « vous pouvez fermer ». C'était faux : rien n'envoyait la
      // file, et l'adhérent fermait l'application en croyant sa facture
      // remise. Elle dit maintenant à quelle condition les pièces partent.
      expect(find.textContaining('toutes seules'), findsOneWidget);
      expect(
        find.textContaining('cette application est ouverte'),
        findsOneWidget,
      );
      expect(find.textContaining('Vous pouvez fermer'), findsNothing);
    });

    testWidgets('plusieurs pièces se comptent dans la phrase', (testeur) async {
      await file.ajouter(depot('A'));
      await file.ajouter(depot('B'));
      await poser(testeur);

      expect(find.text('2 pièces attendent'), findsOneWidget);
    });

    testWidgets("une pièce à reprendre l'emporte sur dix qui attendent", (
      testeur,
    ) async {
      // ⚠️ L'état le plus GRAVE gouverne le verdict : une pièce à reprendre
      // demande un geste, alors que celles qui attendent le réseau n'en
      // demandent aucun.
      await file.ajouter(depot('refusee'));
      await file.vider((_) async => Reponse.refuse);
      await file.ajouter(depot('A'));
      await file.ajouter(depot('B'));
      await poser(testeur);

      expect(find.text('Une pièce à reprendre'), findsOneWidget);
      expect(
        find.textContaining('Photographiez-les à nouveau'),
        findsOneWidget,
      );
    });

    testWidgets('sans dossier, le verdict le dit et donne la suite', (
      testeur,
    ) async {
      await poser(testeur, dossiers: const []);

      expect(find.text('Aucun dossier à votre nom'), findsOneWidget);
      expect(
        find.textContaining('Appelez votre chargé de clientèle'),
        findsOneWidget,
      );
    });
  });

  group('Les pièces se montrent, et pas seulement leur nombre', () {
    testWidgets("chaque pièce en attente porte l'heure de sa prise de vue", (
      testeur,
    ) async {
      await file.ajouter(
        Depot(
          identifiant: 'A',
          dossier: 'M081234567890P',
          cheminDuFichier: '/tmp/a.jpg',
          prisLe: DateTime(2026, 9, 19, 14, 5),
        ),
      );
      await poser(testeur);

      // ⚠️ « 3 » ne dit pas DE QUELLE facture il s'agit. L'heure, si.
      expect(find.text('Prise le 19/09 à 14h05'), findsOneWidget);
      expect(find.text('Dossier M081234567890P'), findsOneWidget);
    });

    testWidgets('une pièce refusée montre le motif du cabinet', (
      testeur,
    ) async {
      await file.ajouter(depot('A'));
      await file.vider((_) async => Reponse.refuse);
      await poser(testeur);

      expect(
        find.textContaining("Le cabinet ne l'a pas prise"),
        findsOneWidget,
      );
    });

    testWidgets("une vignette illisible ne fait pas tomber l'écran", (
      testeur,
    ) async {
      // ⚠️ Le fichier peut avoir disparu. Sans garde, l'adhérent perdrait
      // l'accès à TOUTE sa file pour une seule vignette.
      await file.ajouter(depot('introuvable'));
      await poser(testeur);

      expect(find.text('Une pièce attend'), findsOneWidget);
      expect(testeur.takeException(), isNull);
    });
  });

  group('Le dossier', () {
    testWidgets('est écrit en toutes lettres', (testeur) async {
      await poser(testeur);

      expect(find.text('M081234567890P'), findsOneWidget);
    });

    testWidgets("l'écran ne porte plus son propre appareil photo", (
      testeur,
    ) async {
      // ⚠️ UN SEUL APPAREIL PHOTO DANS L'APPLICATION. L'écran portait un bouton
      // flottant, et la barre du bas a reçu son bouton central : l'adhérent
      // voyait deux appareils photo à trois centimètres l'un de l'autre, sans
      // savoir lequel faisait quoi. Le geste vit désormais dans la barre, qui
      // le déclenche quand l'onglet est déjà ouvert (voir `coquille_test`).
      await poser(testeur, dossiers: const []);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Aucun dossier à votre nom'), findsOneWidget);
    });

    testWidgets("sans dossier connu, l'écran le dit au lieu de se taire", (
      testeur,
    ) async {
      // ⚠️ La panne réseau au lancement a déménagé : ce n'est plus cet écran qui
      // lit les dossiers, c'est la coquille. Le cas est repris dans
      // `coquille_test.dart`. Ici on ne vérifie plus que ce que l'écran fait de
      // la liste qu'on lui donne.
      await poser(testeur, dossiers: const []);

      expect(find.text('Aucun dossier à votre nom'), findsOneWidget);
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

    testWidgets('vide la file et le dit, après un envoi sans réseau', (
      testeur,
    ) async {
      // ⚠️ LE PREMIER ENVOI ÉCHOUE EXPRÈS.
      //
      // Depuis que la file part toute seule à l'ouverture, une file qu'on
      // laisse pleine se vide avant qu'on ait pu appuyer. Le cas réel du
      // bouton est donc celui-ci : la tentative automatique n'a pas eu de
      // réseau, l'adhérent en retrouve un, et appuie.
      await file.ajouter(depot('A'));
      var appels = 0;
      await poser(
        testeur,
        remettre: (_) async {
          appels++;
          return appels == 1 ? Reponse.indisponible : Reponse.accepte;
        },
      );

      expect(appels, 1, reason: 'La tentative automatique a bien eu lieu.');
      expect(find.text('Une pièce attend'), findsOneWidget);

      await testeur.tap(find.byKey(const Key('bouton-envoyer')));
      await pousserJusquAuBandeau(testeur);

      expect(appels, 2);
      expect(find.text('1 pièce envoyée.'), findsOneWidget);
      expect(find.text('Tout est parti'), findsOneWidget);
    });

    testWidgets('la file part toute seule, sans qu\'on appuie sur rien', (
      testeur,
    ) async {
      // ─────────────────────────────────────────────────────────────────────
      // ⚠️ LE CAS QUI MANQUAIT, ET QUI A COÛTÉ UNE PIÈCE PERDUE.
      //
      // Constaté le 27 septembre sur un téléphone réel : une pièce
      // photographiée restait sur l'appareil indéfiniment. Le seul déclencheur
      // d'envoi était le nuage de la barre du haut — que personne n'a de raison
      // d'aller chercher, puisque l'écran venait de dire que les pièces
      // partiraient toutes seules.
      //
      // Aucun cas ne couvrait le départ automatique, parce qu'aucun cas ne
      // couvrait l'ABSENCE de geste. Celui-ci n'appuie sur rien.
      // ─────────────────────────────────────────────────────────────────────
      await file.ajouter(depot('A'));
      await file.ajouter(depot('B'));
      var appels = 0;
      await poser(
        testeur,
        remettre: (_) async {
          appels++;
          return Reponse.accepte;
        },
      );

      await pousserJusquAuBandeau(testeur);

      expect(appels, 2, reason: 'Les deux pièces sont parties.');
      expect(find.text('Tout est parti'), findsOneWidget);
      expect(await file.enAttente(), isEmpty);
    });

    testWidgets('elle repart quand on revient dans l\'application', (
      testeur,
    ) async {
      // ─────────────────────────────────────────────────────────────────────
      // ⚠️ LE MOMENT LE PLUS UTILE DE TOUTE LA FILE.
      //
      // On photographie une facture dans une boutique sans réseau, on range le
      // téléphone, on ressort dans la rue où la 3G revient, et l'on rouvre
      // l'application. C'est à cet instant qu'il faut réessayer — pas à la
      // prochaine reprise, pas au prochain appui.
      // ─────────────────────────────────────────────────────────────────────
      await file.ajouter(depot('A'));
      var appels = 0;
      await poser(
        testeur,
        remettre: (_) async {
          appels++;
          // Pas de réseau au départ ; il revient ensuite.
          return appels == 1 ? Reponse.indisponible : Reponse.accepte;
        },
      );

      expect(appels, 1);
      expect(find.text('Une pièce attend'), findsOneWidget);

      testeur.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pousserJusquAuBandeau(testeur);

      expect(appels, 2, reason: 'Le retour a relancé l\'envoi.');
      expect(find.text('Tout est parti'), findsOneWidget);
      expect(await file.enAttente(), isEmpty);
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
      expect(
        session.fermee,
        isFalse,
        reason: 'un seul appui ne déconnecte plus',
      );
      await testeur.tap(find.byKey(const Key('confirmer-deconnexion')));
      await testeur.pumpAndSettle();

      expect(session.fermee, isTrue);
      expect(sorti, isTrue);
    });
  });

  // ══ La porte de l'historique ══════════════════════════════════════════════
  //
  // ⚠️ POURQUOI CETTE CARTE EXISTE, ET POURQUOI ELLE ARRIVE SI TARD.
  //
  // L'historique des pièces remises — avec le document de chacune — était
  // complet depuis des semaines. Son SEUL point d'entrée était une tuile tout
  // en bas de l'accueil : exactement la section que la barre du bas recouvrait.
  // Le défaut de mise en page du 27 septembre ne cachait pas trois tuiles
  // décoratives, il cachait la porte d'un écran entier.
  group('Tout ce que j\'ai envoyé', () {
    testWidgets('la porte est là, et elle mène bien quelque part', (
      testeur,
    ) async {
      var ouvert = 0;
      await poser(testeur, ouvrirLHistorique: () => ouvert++);

      expect(find.byKey(const Key('vers-historique')), findsOneWidget);
      expect(find.text("Tout ce que j'ai envoyé"), findsOneWidget);
      // ⚠️ La pièce jointe est annoncée : c'est elle qu'on vient chercher, pas
      // une ligne de journal.
      expect(find.textContaining('le document de chacune'), findsOneWidget);

      await testeur.tap(find.byKey(const Key('vers-historique')));
      await testeur.pumpAndSettle();
      expect(ouvert, 1);
    });

    testWidgets('elle se tait tant que le dossier n\'est pas connu', (
      testeur,
    ) async {
      // La coquille ne passe rien tant qu'elle n'a pas lu les dossiers : une
      // porte qui ouvre sur un écran incapable de rien demander vaut moins que
      // pas de porte du tout.
      await poser(testeur);

      expect(find.byKey(const Key('vers-historique')), findsNothing);
    });
  });
}

/// La liste de l'aperçu, et non celle de l'écran de dépôt qu'il recouvre.
Finder _defilementDeLApercu() => find
    .descendant(
      of: find.byType(EcranApercuDuDepot),
      matching: find.byType(Scrollable),
    )
    .first;

/// Un scan PDF tel que le rend le sélecteur de fichiers : une copie provisoire.
class _ScanFeint implements AppareilPhoto {
  _ScanFeint(this.cache);
  final Directory cache;
  int prises = 0;

  @override
  Future<String?> photographier() async {
    prises++;
    final f = File('${cache.path}/facture-$prises.pdf');
    await f.writeAsBytes('%PDF-1.4 scan'.codeUnits);
    return f.path;
  }
}
