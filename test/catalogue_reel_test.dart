import 'dart:convert';
import 'dart:io';

import 'package:cga_mobile/contenu/vitrine.dart';
import 'package:cga_mobile/domaine/offre.dart';
import 'package:cga_mobile/ecrans/offre.dart';
import 'package:cga_mobile/marque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soutien/public_feint.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// LE CATALOGUE DU SERVEUR, TEL QU'IL EST, SUR UN ÉCRAN DE TÉLÉPHONE
///
/// ⚠️ POURQUOI UN JEU DE DONNÉES COPIÉ DU SERVEUR ET NON ÉCRIT À LA MAIN
///
/// Les jeux écrits à la main ressemblent à ce qu'on croit que le serveur
/// envoie. Deux défauts s'y sont cachés, et c'est le téléphone qui les a
/// montrés :
///
///   · les montants arrivent en CHAÎNE (« 12500 »), pas en nombre ;
///   · trois prestations ont un montant `null` — sur étude —, et les lire
///     comme zéro faisait annoncer « dès 0 F par mois » une offre qui commence
///     à 12 500.
///
/// Ce fichier est la réponse littérale de
/// `GET /souscription/services?a_la_date=…`. Il se remplace en la recopiant.
///
/// ⚠️ ET ON REND L'ÉCRAN À 360 px DE LARGE, la largeur d'un téléphone d'entrée
/// de gamme, et non les 800 × 600 du cadre d'essai. C'est la surface par défaut
/// qui avait laissé passer un débordement de 62 px sur la ligne de prix.
/// ─────────────────────────────────────────────────────────────────────────────

Offre lireLeCatalogue() {
  final brut = File(
    'test/donnees/catalogue-du-serveur.json',
  ).readAsStringSync();
  final json = jsonDecode(brut) as List;
  return Offre(
    services: [
      for (final s in json) Service.depuisJson(s as Map<String, dynamic>),
    ],
  );
}

void main() {
  // La date du jeu de données : les tarifs sont datés, et celui de 2026 n'est
  // pas celui de 2024. Figer la date, c'est figer les montants attendus.
  final leJour = DateTime(2026, 9, 20);

  group('Ce que le catalogue du serveur donne à lire', () {
    late Offre offre;
    setUp(() => offre = lireLeCatalogue());

    test('les cinq prestations, rangées selon ce qui se règle en ligne', () {
      expect(offre.services, hasLength(5));
      expect(offre.enLigne.map((s) => s.code), [
        'ADHESION',
        'DOMICILIATION',
        'FORMATION',
      ]);
      expect(offre.surEtude.map((s) => s.code), ['CREATION', 'PONCTUEL']);
    });

    test("l'adhésion commence à 12 500, et non à zéro", () {
      final adhesion = offre.services.firstWhere((s) => s.code == 'ADHESION');
      // ⚠️ Le régime du réel, sans montant, ne doit pas gagner le classement.
      expect(adhesion.aPartirDe(leJour)?.montant, 12500);
    });

    test('le tarif de 2026 est servi, et non celui de 2024', () {
      final domiciliation = offre.services.firstWhere(
        (s) => s.code == 'DOMICILIATION',
      );
      expect(domiciliation.aPartirDe(leJour)?.montant, 180000);
      // Le barème de 2024 valait 160 000 et s'est arrêté au 1er janvier 2026.
      expect(domiciliation.aPartirDe(DateTime(2025, 6, 1))?.montant, 160000);
    });

    test("le prix porte l'unité du barème, pas une périodicité devinée", () {
      // ⚠️ La formation est facturée une fois, mais PAR PERSONNE. « 75 000 F
      // une fois » laissait croire qu'on paie pour tout un groupe.
      String rythme(String code) =>
          offre.services.firstWhere((s) => s.code == code).rythme;
      expect(rythme('FORMATION'), 'par personne');
      expect(rythme('ADHESION'), 'par mois');
      expect(rythme('DOMICILIATION'), 'pour douze mois');
    });

    test('les prestations sur étude n\'ont aucun montant à annoncer', () {
      for (final code in ['CREATION', 'PONCTUEL']) {
        final s = offre.services.firstWhere((s) => s.code == code);
        expect(s.aPartirDe(leJour), isNull, reason: code);
        expect(s.surEtudeLe(leJour), isTrue, reason: code);
      }
    });

    test('le tarif de 2024 se déclare reconstitué, celui de 2026 non', () {
      final adhesion = offre.services.firstWhere((s) => s.code == 'ADHESION');
      expect(adhesion.aPartirDe(DateTime(2025, 6, 1))?.motif, isNotNull);
      expect(adhesion.aPartirDe(leJour)?.motif, isNull);
    });
  });

  group("L'écran rend ce catalogue sans rien couper", () {
    Future<void> rendre(
      WidgetTester testeur, {
      double largeur = 360,
      double echelle = 1.0,
    }) async {
      testeur.view.physicalSize = Size(largeur * 3, 2400);
      testeur.view.devicePixelRatio = 3.0;
      addTearDown(testeur.view.reset);
      await testeur.pumpWidget(
        MaterialApp(
          theme: themeClair(),
          builder: (contexte, enfant) => MediaQuery(
            data: MediaQuery.of(contexte).copyWith(
              textScaler: TextScaler.linear(echelle),
              padding: const EdgeInsets.only(top: 44),
            ),
            child: enfant!,
          ),
          home: EcranOffre(
            servicePublic: PublicFeint(offre: lireLeCatalogue()),
            quandSeConnecter: () {},
            quandSouscrire: (_) {},
          ),
        ),
      );
      await testeur.pumpAndSettle();
    }

    testWidgets('aucun montant à zéro nulle part', (testeur) async {
      await rendre(testeur);
      // ⚠️ La formulation exacte du défaut vu sur le téléphone.
      expect(find.text('0 F'), findsNothing);
      expect(find.textContaining('dès 0'), findsNothing);
    });

    testWidgets("l'adhésion annonce son prix d'entrée et son barème", (
      testeur,
    ) async {
      await rendre(testeur);
      expect(find.text('dès'), findsOneWidget);
      // Le prix d'entrée, puis la tranche qui le porte.
      expect(find.text('12 500 F'), findsNWidgets(2));
      expect(find.text('35 000 F'), findsOneWidget);
      expect(find.text('sur étude'), findsOneWidget);
      expect(find.text('CA jusqu’à 50 M'), findsOneWidget);
      expect(find.text('CA de 50 M à 100 M'), findsOneWidget);
      expect(find.text('CA au-delà de 100 M'), findsOneWidget);
    });

    testWidgets('le bandeau réserve exactement la place de son texte', (
      testeur,
    ) async {
      // ─────────────────────────────────────────────────────────────────────
      // ⚠️ CE CAS MESURE L'ÉCART, IL NE SE CONTENTE PAS DE L'ABSENCE D'ERREUR.
      //
      // Deux défauts se sont succédé sur ce bandeau, et aucun ne lève
      // d'exception :
      //
      //   · une hauteur réservée trop courte coupe le texte ;
      //   · une hauteur trop longue laisse un aplat d'indigo vide — c'est ce
      //     qu'on a vu sur le téléphone, parce que `SliverAppBar` AJOUTE
      //     lui-même la barre d'état à la hauteur qu'on lui donne, et qu'on
      //     la comptait déjà.
      //
      // On mesure donc la distance entre le bas de la promesse et le bas du
      // bandeau. Elle doit valoir la marge basse voulue, et rien d'autre.
      // ─────────────────────────────────────────────────────────────────────
      await rendre(testeur);

      final basDuTexte = testeur.getRect(find.text(Promesse.detail)).bottom;
      final basDuBandeau = testeur
          .getRect(find.byType(FlexibleSpaceBar))
          .bottom;
      final ecart = basDuBandeau - basDuTexte;

      // 30 de marge basse, à la mise en page près. Le double comptage de la
      // barre d'état donnait 74.
      expect(ecart, greaterThan(24));
      expect(ecart, lessThan(38));
    });

    for (final (nom, largeur, echelle) in const [
      ('à 360 px', 360.0, 1.0),
      ('à 320 px', 320.0, 1.0),
      ('en gros caractères', 360.0, 1.6),
      ('à 320 px en gros caractères', 320.0, 1.6),
    ]) {
      testWidgets('rien ne déborde $nom', (testeur) async {
        await rendre(testeur, largeur: largeur, echelle: echelle);
        // ⚠️ On fait défiler tout l'écran : les cartes hors champ ne sont pas
        // construites, et c'est ainsi qu'un débordement de 62 px sur la
        // domiciliation est passé inaperçu sur le téléphone.
        for (var i = 0; i < 12; i++) {
          await testeur.drag(
            find.byType(CustomScrollView),
            const Offset(0, -260),
          );
          await testeur.pumpAndSettle();
          expect(
            testeur.takeException(),
            isNull,
            reason: '$nom, défilement $i',
          );
        }
      });
    }
  });
}
