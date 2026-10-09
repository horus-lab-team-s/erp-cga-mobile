/// Ce que la vitrine publie et que l'application reprend : le blog, l'annonce
/// du moment, les institutions.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ LUS SUR LE SERVEUR, JAMAIS RECOPIÉS.
///
/// Les textes qui changent — un article, l'offre du mois — viennent de
/// `/vitrine/...`, les mêmes routes que le site. Les recopier dans
/// l'application ferait vivre deux versions : le site annoncerait le pack SARL
/// à 275 000 F, et l'application celui de l'an dernier.
///
/// Seuls les textes STABLES — la promesse, les étapes, les avantages de
/// l'adhésion — sont recopiés, dans `contenu/vitrine.dart`.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// Le libellé d'une rubrique du blog, tel que la vitrine l'écrit.
///
/// ⚠️ Une rubrique inconnue rend son code plutôt que rien : un article sans
/// étiquette se lit, une étiquette vide laisserait une pastille muette.
String libelleDeRubrique(String code) => switch (code) {
  'saviezVous' => 'Le saviez-vous ?',
  'vraiOuFaux' => 'Vrai ou faux ?',
  'lundiComptable' => 'Lundi comptable',
  'mercrediJuridique' => 'Mercredi juridique',
  'coinFiscaliste' => 'Le coin du fiscaliste',
  'annonces' => 'Annonces',
  _ => code,
};

/// Un article, tel que le sommaire le présente.
class Article {
  const Article({
    required this.slug,
    required this.rubrique,
    required this.titre,
    required this.accroche,
    required this.date,
    required this.minutes,
    this.image,
  });

  final String slug;
  final String rubrique;
  final String titre;
  final String accroche;
  final DateTime date;
  final int minutes;

  /// Le chemin de l'image SUR LA VITRINE (« /images/pages/cabinet-a.jpg »).
  /// ⚠️ Un chemin et non une adresse : c'est à l'application de le rattacher à
  /// l'adresse du site, qui change entre la démonstration et la production.
  final String? image;

  static Article depuisJson(Map<String, dynamic> j) => Article(
    slug: j['slug'] as String,
    rubrique: j['rubrique'] as String? ?? '',
    titre: j['titre'] as String? ?? '',
    accroche: j['accroche'] as String? ?? '',
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime(2000),
    minutes: (j['minutes'] as num?)?.toInt() ?? 0,
    image: j['image'] as String?,
  );
}

/// Un morceau du corps d'un article.
///
/// ⚠️ Une classe scellée : l'écran qui les dessine est obligé, par le
/// compilateur, de traiter chaque sorte. Un nouveau type ajouté côté serveur
/// tombe dans [BlocInconnu] et reste lisible, au lieu de disparaître.
sealed class BlocDArticle {
  const BlocDArticle();

  static BlocDArticle depuisJson(Map<String, dynamic> j) => switch (j['type']) {
    'paragraphe' => Paragraphe('${j['texte'] ?? ''}'),
    'intertitre' => Intertitre('${j['texte'] ?? ''}'),
    'encadre' => Encadre(
      titre: j['titre'] as String?,
      texte: '${j['texte'] ?? ''}',
    ),
    'liste' => Liste([for (final p in (j['points'] as List? ?? [])) '$p']),
    _ => BlocInconnu('${j['texte'] ?? ''}'),
  };
}

class Paragraphe extends BlocDArticle {
  const Paragraphe(this.texte);
  final String texte;
}

class Intertitre extends BlocDArticle {
  const Intertitre(this.texte);
  final String texte;
}

class Encadre extends BlocDArticle {
  const Encadre({required this.texte, this.titre});
  final String? titre;
  final String texte;
}

class Liste extends BlocDArticle {
  const Liste(this.points);
  final List<String> points;
}

/// Une sorte de bloc que l'application ne connaît pas encore. Son texte, s'il
/// en a un, est rendu comme un paragraphe.
class BlocInconnu extends BlocDArticle {
  const BlocInconnu(this.texte);
  final String texte;
}

/// Un article entier, avec ceux qu'on propose de lire ensuite.
class ArticleComplet {
  const ArticleComplet({
    required this.article,
    required this.corps,
    required this.voisins,
  });

  final Article article;
  final List<BlocDArticle> corps;
  final List<Article> voisins;

  static ArticleComplet depuisJson(Map<String, dynamic> j) {
    final a = j['article'] as Map<String, dynamic>;
    return ArticleComplet(
      article: Article.depuisJson(a),
      corps: [
        for (final b in (a['corps'] as List? ?? []))
          BlocDArticle.depuisJson(b as Map<String, dynamic>),
      ],
      voisins: [
        for (final v in (j['voisins'] as List? ?? []))
          Article.depuisJson(v as Map<String, dynamic>),
      ],
    );
  }
}

/// L'annonce du moment : l'offre que le cabinet met en avant.
class Annonce {
  const Annonce({
    required this.etiquette,
    required this.texte,
    this.lien,
    this.libelleLien,
  });

  final String etiquette;
  final String texte;

  /// Un chemin de la vitrine (« /blog/pack-formalisation-sarl »).
  final String? lien;
  final String? libelleLien;

  /// Le slug de l'article, quand l'annonce renvoie au blog.
  ///
  /// ⚠️ L'application sait lire un article ; elle ne sait pas afficher une
  /// page quelconque du site. Un lien vers autre chose que `/blog/...` n'est
  /// donc pas proposé, plutôt que d'ouvrir un navigateur au milieu du
  /// parcours.
  String? get slugDArticle {
    final l = lien;
    if (l == null || !l.startsWith('/blog/')) return null;
    final slug = l.substring('/blog/'.length);
    return slug.isEmpty ? null : slug;
  }

  static Annonce depuisJson(Map<String, dynamic> j) => Annonce(
    etiquette: j['etiquette'] as String? ?? '',
    texte: j['texte'] as String? ?? '',
    lien: j['lien'] as String?,
    libelleLien: j['libelle_lien'] as String?,
  );
}

/// Une institution dans le cadre de laquelle le cabinet exerce.
class Institution {
  const Institution({required this.cle, required this.nom, this.logo});
  final String cle;
  final String nom;
  final String? logo;

  static Institution depuisJson(Map<String, dynamic> j) => Institution(
    cle: j['cle'] as String? ?? '',
    nom: j['nom'] as String? ?? '',
    logo: j['logo'] as String?,
  );
}
