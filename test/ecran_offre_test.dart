import 'package:cga_mobile/contenu/vitrine.dart';
import 'package:cga_mobile/domaine/offre.dart';
import 'package:cga_mobile/ecrans/offre.dart';
import 'package:cga_mobile/marque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soutien/public_feint.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// Le premier écran de l'application, celui qu'un visiteur voit AVANT tout
/// compte. ⚠️ Deux cas comptent plus que l'affichage :
///
///   · une prestation « sur étude » ne doit PAS offrir de souscrire — le
///     serveur refuse en 422, et un bouton promettrait ce qu'il refuse ;
///   · un tarif reconstitué doit le DIRE. Un prix annoncé engage le cabinet.
/// ─────────────────────────────────────────────────────────────────────────────

Service service({
  String code = 'ADHESION',
  String libelle = 'Suivi comptable et fiscal',
  String periodicite = 'MENSUELLE',
  bool enLigne = true,
  List<Map<String, dynamic>> formules = const [],
  List<Map<String, dynamic>> tarifs = const [
    {'montant': '12500', 'du': '2020-01-01', 'au': null, 'motif': null},
  ],
}) => Service.depuisJson({
  'code': code,
  'libelle': libelle,
  'nature': 'ABONNEMENT',
  'periodicite': periodicite,
  'tarifs': tarifs,
  'formules': formules,
  'inclus': const [],
  'ouvre_un_dossier': true,
  'souscriptible_en_ligne': enLigne,
  'unite': 'FCFA par mois',
  'resume': 'Tenue des comptes et déclarations.',
});

void main() {
  Future<PublicFeint> poser(
    WidgetTester testeur, {
    Offre offre = const Offre(),
    void Function(Service)? quandSouscrire,
  }) async {
    final p = PublicFeint(offre: offre);
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranOffre(
          servicePublic: p,
          quandSeConnecter: () {},
          quandSouscrire: quandSouscrire ?? (_) {},
        ),
      ),
    );
    return p;
  }

  testWidgets('Le prix est le sujet, et il porte son rythme', (testeur) async {
    await poser(testeur, offre: Offre(services: [service()]));
    await testeur.pumpAndSettle();

    expect(find.text('12 500 F'), findsOneWidget);
    expect(find.text('par mois'), findsOneWidget);
  });

  testWidgets('Un service à formules annonce « dès », jamais un forfait', (
    testeur,
  ) async {
    // ⚠️ Le prix dépend du chiffre d'affaires : annoncer celui d'une tranche
    // sans le dire ferait croire à un prix ferme.
    await poser(
      testeur,
      offre: Offre(
        services: [
          service(
            tarifs: const [],
            formules: const [
              {
                'code': 'LIBERATOIRE',
                'libelle': 'Impôt libératoire',
                'plancher': '0',
                'plafond': '50000000',
                'tarifs': [
                  {'montant': '12500', 'du': '2020-01-01', 'au': null},
                ],
                'inclus': [],
              },
              {
                'code': 'REEL',
                'libelle': 'Régime du réel',
                'plancher': '50000000',
                'plafond': null,
                'tarifs': [
                  {'montant': '35000', 'du': '2020-01-01', 'au': null},
                ],
                'inclus': [],
              },
            ],
          ),
        ],
      ),
    );
    await testeur.pumpAndSettle();

    expect(find.text('dès'), findsOneWidget);
    // ⚠️ DEUX FOIS, et c'est voulu : le prix d'entrée en grand, puis la ligne
    // de la tranche qui le porte. On vérifie les deux séparément plutôt que
    // d'assouplir le compte, sans quoi le cas ne verrait plus la différence
    // entre « le barème s'affiche » et « le barème a disparu ».
    expect(find.text('12 500 F'), findsNWidgets(2));
    expect(find.text('35 000 F'), findsOneWidget);
    expect(find.text('Impôt libératoire'), findsOneWidget);
    expect(find.text('Régime du réel'), findsOneWidget);
    // Les bornes de chiffre d'affaires : c'est ce qui permet au commerçant de
    // reconnaître SA tranche sans téléphoner au cabinet.
    expect(find.text('CA jusqu\u2019à 50 M'), findsOneWidget);
    expect(find.text('CA au-delà de 50 M'), findsOneWidget);
  });

  group('Ce qui ne se souscrit pas en ligne', () {
    testWidgets('n\'offre pas de bouton, et dit pourquoi', (testeur) async {
      // ⚠️ Le serveur refuse en 422 une souscription sur ces prestations. Un
      // bouton promettrait ce qu'il refuse ; un bouton grisé laisserait croire
      // à une panne.
      await poser(
        testeur,
        offre: Offre(
          services: [
            service(
              code: 'CREATION',
              libelle: 'Création d\'entreprise',
              enLigne: false,
              periodicite: 'UNIQUE',
              // ⚠️ Comme au référentiel : la création d'entreprise porte un
              // tarif SANS MONTANT. Le jeu d'essai lui laissait le tarif par
              // défaut de 12 500, ce qui n'existe pour elle nulle part.
              tarifs: const [
                {'montant': null, 'du': '2020-01-01', 'au': null},
              ],
            ),
          ],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.byKey(const Key('souscrire-CREATION')), findsNothing);
      // ⚠️ LE FAIT MONÉTAIRE SUR LA CARTE, LE CHEMIN SOUS LE TITRE DE SECTION,
      // et chacun une seule fois. Sur le téléphone, la carte enchaînait
      // « Montant établi après étude », « Le cabinet vous adresse une
      // proposition après examen », juste sous un intertitre qui disait déjà
      // « Le cabinet examine votre dossier, puis vous adresse une
      // proposition ». Trois fois la même idée sur un demi-écran.
      expect(
        find.text('Montant établi après étude de votre dossier.'),
        findsOneWidget,
      );
      expect(find.textContaining('adresse une proposition'), findsOneWidget);
    });

    testWidgets('est rangé à part, sous son propre titre', (testeur) async {
      await poser(
        testeur,
        offre: Offre(
          services: [
            service(),
            service(code: 'CREATION', enLigne: false),
          ],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.text('Souscrire depuis ce téléphone'), findsOneWidget);
      expect(find.byKey(const Key('souscrire-ADHESION')), findsOneWidget);

      // ⚠️ Le cadre d'essai fait 800 × 600 : le second titre passe sous la
      // ligne de flottaison et la liste ne le construit pas. On fait défiler,
      // comme le ferait un visiteur, plutôt que d'agrandir artificiellement
      // l'écran — ce qui masquerait un vrai débordement le jour où il y en
      // aurait un.
      // ⚠️ Le défileur VERTICAL, désigné comme tel : la page porte aussi la
      // rangée d'onglets et celle des articles, qui défilent de côté.
      await testeur.scrollUntilVisible(
        find.text('Chiffré après examen de votre dossier'),
        260,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await testeur.pumpAndSettle();
      expect(
        find.text('Chiffré après examen de votre dossier'),
        findsOneWidget,
      );
      expect(find.text('SUR ÉTUDE'), findsOneWidget);
    });
  });

  group("Le prix est une décision du gérant", () {
    // ─────────────────────────────────────────────────────────────────────────
    // ⚠️ Tant que la direction du cabinet n'a pas arrêté un prix, il vient du
    // catalogue de démonstration : il s'affiche INDICATIF et ne se paie pas.
    //
    // L'écran affichait à la place le motif brut du serveur — « ⚠️ Tarif
    // reconstitué — voir l'en-tête du module » —, une note de développeur
    // qu'aucun prospect ne peut comprendre.
    // ─────────────────────────────────────────────────────────────────────────

    Service avec(String? statut) => service(
      tarifs: [
        {
          'montant': '12500',
          'du': '2020-01-01',
          'au': null,
          'motif': "⚠️ Tarif reconstitué — voir l'en-tête du module",
          'statut': statut,
        },
      ],
    );

    testWidgets('un prix non fixé se dit indicatif', (testeur) async {
      await poser(testeur, offre: Offre(services: [avec('A_VALIDER')]));
      await testeur.pumpAndSettle();
      expect(find.text('Tarif indicatif'), findsOneWidget);
      expect(find.textContaining('confirme ce prix'), findsOneWidget);
    });

    testWidgets('un prix fixé par le gérant ne porte aucune réserve', (
      testeur,
    ) async {
      await poser(testeur, offre: Offre(services: [avec('FIXE')]));
      await testeur.pumpAndSettle();
      expect(find.text('Tarif indicatif'), findsNothing);
    });

    testWidgets('la note de développeur ne sort jamais', (testeur) async {
      await poser(testeur, offre: Offre(services: [avec('A_VALIDER')]));
      await testeur.pumpAndSettle();
      expect(find.textContaining("l'en-tête du module"), findsNothing);
    });
  });

  testWidgets('Souscrire remonte le service choisi', (testeur) async {
    Service? choisi;
    await poser(
      testeur,
      offre: Offre(services: [service()]),
      quandSouscrire: (s) => choisi = s,
    );
    await testeur.pumpAndSettle();

    // Le bouton est sous la photo de la carte et sous les chiffres du
    // cabinet : on le fait venir à l'écran, comme le ferait un pouce.
    await testeur.ensureVisible(find.byKey(const Key('souscrire-ADHESION')));
    await testeur.pumpAndSettle();
    await testeur.tap(find.byKey(const Key('souscrire-ADHESION')));
    await testeur.pumpAndSettle();

    expect(choisi?.code, 'ADHESION');
  });

  testWidgets('Pas de réseau le dit, sans parler de connexion', (
    testeur,
  ) async {
    // ⚠️ Cet écran est PUBLIC : renvoyer vers une connexion serait absurde
    // pour quelqu'un qui n'a pas de compte et n'en demande pas.
    await poser(testeur, offre: const Offre(serveurJoignable: false));
    await testeur.pumpAndSettle();

    expect(find.text('Pas de réseau'), findsOneWidget);
    expect(find.textContaining('Session'), findsNothing);
  });

  group("Un tarif sans montant n'est pas un tarif à zéro", () {
    // ─────────────────────────────────────────────────────────────────────────
    // ⚠️ CONSTATÉ SUR LE TÉLÉPHONE, PAS EN TEST.
    //
    // L'écran annonçait « dès 0 F par mois » pour l'adhésion au centre agréé,
    // dont le premier tarif réel est 12 500, et « 0 F une fois » pour la
    // création d'entreprise. La cause : le référentiel porte des tarifs SANS
    // montant — le régime du réel, la création, le ponctuel —, la lecture
    // faisait `double.tryParse('null') ?? 0`, et zéro gagnait le classement du
    // prix d'entrée.
    //
    // Un prix inventé affiché à un prospect engage le cabinet. Ces trois cas
    // tiennent la règle : absent veut dire SUR ÉTUDE, jamais gratuit.
    // ─────────────────────────────────────────────────────────────────────────

    const reelSansMontant = {
      'code': 'REEL',
      'libelle': 'Régime du réel',
      'plancher': '100000000',
      'plafond': null,
      'tarifs': [
        {'montant': null, 'du': '2020-01-01', 'au': null, 'motif': null},
      ],
      'inclus': [],
    };
    const liberatoire = {
      'code': 'LIBERATOIRE',
      'libelle': 'Impôt libératoire',
      'plancher': '0',
      'plafond': '50000000',
      'tarifs': [
        {'montant': '12500', 'du': '2020-01-01', 'au': null, 'motif': null},
      ],
      'inclus': [],
    };

    testWidgets('le prix d\'entrée ignore la tranche sur étude', (
      testeur,
    ) async {
      await poser(
        testeur,
        offre: Offre(
          services: [
            service(
              tarifs: const [],
              formules: const [liberatoire, reelSansMontant],
            ),
          ],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.text('0 F'), findsNothing);
      // Le premier prix réellement pratiqué, et lui seul.
      expect(find.text('12 500 F'), findsNWidgets(2));
    });

    testWidgets('la tranche sur étude le dit, au lieu de rester vide', (
      testeur,
    ) async {
      await poser(
        testeur,
        offre: Offre(
          services: [
            service(
              tarifs: const [],
              formules: const [liberatoire, reelSansMontant],
            ),
          ],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.text('sur étude'), findsOneWidget);
    });

    testWidgets('un service entièrement sur étude annonce l\'examen', (
      testeur,
    ) async {
      // La création d'entreprise : un seul tarif, sans montant.
      await poser(
        testeur,
        offre: Offre(
          services: [
            service(
              code: 'CREATION',
              libelle: "Création d'entreprise",
              enLigne: false,
              periodicite: 'UNIQUE',
              tarifs: const [
                {'montant': null, 'du': '2020-01-01', 'au': null},
              ],
            ),
          ],
        ),
      );
      await testeur.pumpAndSettle();

      expect(find.text('0 F'), findsNothing);
      expect(
        find.text('Montant établi après étude de votre dossier.'),
        findsOneWidget,
      );
    });
  });

  group('Le bandeau ne déborde pas', () {
    // ─────────────────────────────────────────────────────────────────────────
    // ⚠️ POURQUOI CE CAS EXISTE
    //
    // Une version du bandeau réservait 232 px en dur : elle débordait de 9,3 px
    // sur le téléphone d'essai — les rayures jaunes et noires de Flutter en
    // travers de la marque. La suivante réservait 144 px au-dessus de la barre :
    // elle laissait cette fois une centaine de pixels d'indigo vide.
    //
    // Le cas le plus dur n'est ni l'un ni l'autre : c'est **l'adhérent qui a
    // réglé son téléphone en gros caractères**. Le titre passe alors de une
    // ligne à deux et la promesse de deux à quatre, sur un écran étroit. Si la
    // hauteur ne suit pas, l'écran d'accueil du cabinet s'ouvre sur un
    // débordement.
    // ─────────────────────────────────────────────────────────────────────────

    for (final (nom, echelle, largeur) in const [
      ('en taille normale', 1.0, 360.0),
      ('en gros caractères', 1.6, 360.0),
      ('sur un écran étroit, en gros caractères', 1.6, 320.0),
    ]) {
      testWidgets(nom, (testeur) async {
        testeur.view.physicalSize = Size(largeur * 3, 800 * 3);
        testeur.view.devicePixelRatio = 3.0;
        addTearDown(testeur.view.reset);

        final p = PublicFeint(offre: Offre(services: [service()]));
        await testeur.pumpWidget(
          MaterialApp(
            theme: themeClair(),
            builder: (contexte, enfant) => MediaQuery(
              data: MediaQuery.of(contexte).copyWith(
                textScaler: TextScaler.linear(echelle),
                // Une barre d'état de téléphone à encoche.
                padding: const EdgeInsets.only(top: 44),
              ),
              child: enfant!,
            ),
            home: EcranOffre(
              servicePublic: p,
              quandSeConnecter: () {},
              quandSouscrire: (_) {},
            ),
          ),
        );
        await testeur.pumpAndSettle();

        // ⚠️ `takeException` rend le débordement visible : sans cette ligne, le
        // cas passerait au vert avec les rayures à l'écran.
        expect(testeur.takeException(), isNull);
        expect(find.text(Promesse.titre), findsOneWidget);
      });
    }

    testWidgets('la hauteur réservée suit l\'agrandissement du texte', (
      testeur,
    ) async {
      late double normale;
      late double agrandie;
      for (final (echelle, garder) in [
        (1.0, (double h) => normale = h),
        (1.6, (double h) => agrandie = h),
      ]) {
        await testeur.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 800),
              textScaler: TextScaler.linear(echelle),
            ),
            child: Builder(
              builder: (contexte) {
                garder(hauteurDuBandeau(contexte));
                return const SizedBox();
              },
            ),
          ),
        );
      }
      // Pas « différente » : PLUS GRANDE. Une hauteur qui ne bougerait pas
      // serait exactement le défaut qu'on corrige.
      expect(agrandie, greaterThan(normale));
    });
  });
}
