import 'package:cga_mobile/contenu/vitrine.dart';
import 'package:cga_mobile/domaine/offre.dart';
import 'package:cga_mobile/domaine/vitrine.dart';
import 'package:cga_mobile/ecrans/offre.dart';
import 'package:cga_mobile/marque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'soutien/public_feint.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// LA PAGE PUBLIQUE : LA VITRINE EN UNE PAGE
///
/// Ces cas tiennent ce qui a été demandé : un visiteur sans compte doit
/// trouver dans l'application ce que la vitrine lui dit — les services, ce que
/// l'adhésion change, comment ça se passe, les articles, comment joindre le
/// cabinet —, et y accéder sans chercher.
/// ─────────────────────────────────────────────────────────────────────────────

final _article = Article(
  slug: 'a-qui-s-applique-l-igs',
  rubrique: 'coinFiscaliste',
  titre: "À qui s'applique réellement l'Impôt Général Synthétique ?",
  accroche: 'Beaucoup en entendent parler sans savoir s\'ils sont concernés.',
  date: DateTime(2026, 1, 23),
  minutes: 4,
  image: '/images/pages/cabinet-a.jpg',
);

final _complet = ArticleComplet(
  article: _article,
  corps: const [
    Intertitre("Qu'est-ce que l'IGS ?"),
    Paragraphe('Un régime simplifié.'),
    Encadre(
      titre: 'Le point que tout le monde manque',
      texte:
          'Même sans '
          'bénéfice.',
    ),
    Liste(['Le chiffre d\'affaires', 'La nature de l\'activité']),
  ],
  voisins: const [],
);

PublicFeint _serveur() => PublicFeint(
  offre: Offre(
    services: [
      Service.depuisJson({
        'code': 'ADHESION',
        'libelle': 'Suivi comptable et fiscal',
        'nature': 'ABONNEMENT',
        'periodicite': 'MENSUELLE',
        'tarifs': [
          {'montant': '12500', 'du': '2020-01-01', 'au': null},
        ],
        'formules': const [],
        'souscriptible_en_ligne': true,
      }),
    ],
  ),
  annonce: const Annonce(
    etiquette: 'Offre',
    texte: 'Votre SARL immatriculée pour 275 000 FCFA.',
    lien: '/blog/a-qui-s-applique-l-igs',
    libelleLien: "Voir l'offre",
  ),
  lesArticles: [_article],
  articlesComplets: {_article.slug: _complet},
  lesInstitutions: const [
    Institution(cle: 'dgi', nom: 'Direction Générale des Impôts'),
  ],
);

Future<PublicFeint> _poser(WidgetTester testeur) async {
  // Un téléphone ordinaire, et non le cadre d'essai de 800 × 600.
  testeur.view.physicalSize = const Size(360 * 3, 780 * 3);
  testeur.view.devicePixelRatio = 3;
  addTearDown(testeur.view.reset);
  final s = _serveur();
  await testeur.pumpWidget(
    MaterialApp(
      theme: themeClair(),
      home: EcranOffre(
        servicePublic: s,
        quandSeConnecter: () {},
        quandSouscrire: (_) {},
      ),
    ),
  );
  await testeur.pumpAndSettle();
  return s;
}

/// Le défileur vertical de la page, et non ceux des rangées latérales.
final _page = find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;

/// Touche un onglet, après l'avoir fait venir dans le champ comme le ferait
/// un pouce : à 360 points, les derniers dépassent à droite.
///
/// ⚠️ PAR UN GLISSEMENT DE LA RANGÉE, À LA MAIN. `ensureVisible` et
/// `dragUntilVisible` finissent tous deux par faire défiler TOUS les
/// défileurs parents : la page entière sautait, et le cas ne voyait plus ce
/// que fait l'onglet.
Future<void> _toucherOnglet(WidgetTester testeur, int i) async {
  final onglet = find.byKey(Key('onglet-section-$i'));
  for (var essai = 0; essai < 8; essai++) {
    final r = testeur.getRect(onglet);
    if (r.left >= 0 && r.right <= 360) break;
    await testeur.drag(
      find.byKey(const Key('rangee-onglets')),
      const Offset(-80, 0),
    );
    await testeur.pumpAndSettle();
  }
  await testeur.tap(find.byKey(Key('onglet-section-$i')));
  await testeur.pumpAndSettle();
}

void main() {
  testWidgets("l'onglet de la section lue revient DANS le champ", (
    testeur,
  ) async {
    // ⚠️ « Nous joindre » dépasse à droite de la rangée sur un téléphone de
    // 360 points. Quand on lit sa section, il doit être visible, sans quoi
    // l'onglet marqué comme actif est justement celui qu'on ne voit pas.
    await _poser(testeur);
    await testeur.drag(_page, const Offset(0, -20000));
    await testeur.pumpAndSettle();

    final onglet = testeur.getRect(find.byKey(const Key('onglet-section-4')));
    expect(onglet.left, greaterThanOrEqualTo(0));
    expect(onglet.right, lessThanOrEqualTo(360));
  });

  testWidgets('chaque section de la vitrine est là, dans le même ordre', (
    testeur,
  ) async {
    await _poser(testeur);
    final titres = [
      'Souscrire depuis ce téléphone',
      Adhesion.titre,
      Etapes.titre,
      Blog.titre,
      Partenaires.titre,
      Joindre.titre,
    ];
    var precedent = -double.infinity;
    for (final t in titres) {
      await testeur.scrollUntilVisible(find.text(t), 300, scrollable: _page);
      // L'ordre se vérifie en position ABSOLUE dans la page : position à
      // l'écran plus ce qu'on a déjà fait défiler.
      final position =
          testeur.state<ScrollableState>(_page).position.pixels +
          testeur.getTopLeft(find.text(t)).dy;
      expect(position, greaterThan(precedent), reason: t);
      precedent = position;
    }
  });

  testWidgets('un onglet mène à sa section, et le titre arrive VISIBLE', (
    testeur,
  ) async {
    // ⚠️ `ensureVisible` aurait posé le titre DERRIÈRE la barre et les
    // onglets épinglés. On vérifie qu'il arrive dessous.
    await _poser(testeur);
    await _toucherOnglet(testeur, 2);

    final haut = testeur.getTopLeft(find.text(Etapes.titre)).dy;
    final basDesOnglets = testeur
        .getBottomLeft(find.byKey(const Key('onglet-section-0')))
        .dy;
    expect(haut, greaterThan(basDesOnglets));
    expect(haut, lessThan(780 / 2), reason: 'la section doit être EN HAUT');
  });

  testWidgets("l'onglet de la section lue se marque en défilant", (
    testeur,
  ) async {
    await _poser(testeur);
    await _toucherOnglet(testeur, 4);

    final onglet = testeur.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const Key('onglet-section-4')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(onglet.color, isNot(Colors.transparent));
  });

  testWidgets("l'annonce ouvre l'article qu'elle annonce", (testeur) async {
    final s = await _poser(testeur);
    await testeur.tap(find.byKey(const Key('annonce')));
    await testeur.pumpAndSettle();

    expect(s.articlesDemandes, ['a-qui-s-applique-l-igs']);
    expect(find.text(_article.titre), findsOneWidget);
  });

  testWidgets("un article se lit dans l'application, blocs compris", (
    testeur,
  ) async {
    await _poser(testeur);
    await testeur.scrollUntilVisible(
      find.byKey(Key('article-${_article.slug}')),
      300,
      scrollable: _page,
    );
    // ⚠️ Attendre la fin du défilement avant de toucher : sans cela, l'appui
    // part à l'ancienne position de la carte, hors de l'écran, et ne touche
    // rien.
    await testeur.pumpAndSettle();
    await testeur.tap(find.byKey(Key('article-${_article.slug}')));
    await testeur.pumpAndSettle();

    // ⚠️ Une date qui se lit, pas « 2026-01-23 ».
    expect(find.textContaining('23 janvier 2026'), findsOneWidget);
    // Chaque sorte de bloc est rendue — intertitre, encadré, liste —, et l'on
    // fait défiler l'article pour les lire, comme un lecteur.
    for (final t in [
      "Qu'est-ce que l'IGS ?",
      'Le point que tout le monde manque',
      'Le chiffre d\'affaires',
    ]) {
      await testeur.scrollUntilVisible(find.text(t), 200, scrollable: _page);
      expect(find.text(t), findsOneWidget, reason: t);
    }
    // Et l'article finit sur une action.
    await testeur.scrollUntilVisible(
      find.byKey(const Key('article-whatsapp')),
      300,
      scrollable: _page,
    );
    expect(find.byKey(const Key('article-whatsapp')), findsOneWidget);
  });

  testWidgets('les trois moyens de joindre le cabinet', (testeur) async {
    await _poser(testeur);
    await _toucherOnglet(testeur, 4);
    for (final cle in [
      'joindre-whatsapp',
      'joindre-telephone',
      'joindre-courriel',
    ]) {
      await testeur.scrollUntilVisible(
        find.byKey(Key(cle)),
        200,
        scrollable: _page,
      );
      expect(find.byKey(Key(cle)), findsOneWidget, reason: cle);
    }
  });

  testWidgets('aucun témoignage inventé', (testeur) async {
    // ⚠️ La vitrine publie quatre témoignages : des noms inventés sur des
    // portraits de banque d'images. Ils n'entrent pas dans l'application.
    await _poser(testeur);
    await testeur.drag(_page, const Offset(0, -20000));
    await testeur.pumpAndSettle();
    for (final nom in [
      'Estelle Mbarga',
      'Rodrigue Fotso',
      'Aïcha Ndongo',
      'Serge Ekwalla',
    ]) {
      expect(find.textContaining(nom), findsNothing, reason: nom);
    }
  });

  testWidgets('sans blog ni annonce, la page reste entière', (testeur) async {
    // Le serveur ne sert que le catalogue : le reste se tait ou le dit, sans
    // jamais masquer les offres.
    testeur.view.physicalSize = const Size(360 * 3, 780 * 3);
    testeur.view.devicePixelRatio = 3;
    addTearDown(testeur.view.reset);
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranOffre(
          servicePublic: PublicFeint(offre: _serveur().offre),
          quandSeConnecter: () {},
          quandSouscrire: (_) {},
        ),
      ),
    );
    await testeur.pumpAndSettle();

    expect(find.byKey(const Key('annonce')), findsNothing);
    expect(find.text('Souscrire depuis ce téléphone'), findsOneWidget);
    await testeur.scrollUntilVisible(
      find.textContaining('reparaîtront'),
      300,
      scrollable: _page,
    );
    expect(testeur.takeException(), isNull);
  });
}
