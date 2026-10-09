import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../composants/carte.dart';
import '../../composants/joindre.dart';
import '../../contenu/cabinet.dart';
import '../../contenu/vitrine.dart';
import '../../domaine/vitrine.dart';
import '../../marque.dart';

/// Les sections de la page publique, dans l'ordre de la vitrine.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ LA VITRINE EN UNE PAGE, ET NON SEPT ÉCRANS.
///
/// Le site répartit son contenu sur sept pages reliées par un menu. Sur un
/// téléphone, un menu de sept entrées se cache derrière une icône que personne
/// n'ouvre. La page publique de l'application reprend donc les mêmes sections
/// L'UNE SOUS L'AUTRE, avec en haut une rangée d'onglets qui y mène
/// directement : on fait défiler pour découvrir, on touche un onglet pour
/// aller droit au but.
///
/// Chaque section porte son titre en deux temps, comme la vitrine : un
/// « surtitre » court en capitales, qui dit de quoi l'on parle, puis le titre,
/// qui dit ce que l'on y gagne.
/// ─────────────────────────────────────────────────────────────────────────────

/// Le titre d'une section : un surtitre, un titre, parfois un chapeau.
class TitreDeSection extends StatelessWidget {
  const TitreDeSection({
    super.key,
    required this.kicker,
    required this.titre,
    this.detail,
    this.surFondSombre = false,
  });

  final String kicker;
  final String titre;
  final String? detail;

  /// Sur l'indigo : le texte passe en blanc, le surtitre en indigo éclairci.
  final bool surFondSombre;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final encre = surFondSombre ? Colors.white : couleurs.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kicker.toUpperCase(),
            style: texte.labelMedium?.copyWith(
              // ⚠️ CALCULÉ, ET LE PREMIER CHOIX NE TENAIT PAS. Le magenta 600
              // tombe à 2,05:1 sur l'indigo 900. Le magenta éclairci du thème
              // sombre, essayé ensuite, n'y fait que 4,04:1 — sous les 4,5:1
              // d'un texte de 13 px. L'indigo éclairci du thème sombre y tient
              // 7,08:1, et reste dans la marque.
              color: surFondSombre ? Marque.indigo700Sombre : couleurs.primary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(titre, style: texte.titleLarge?.copyWith(color: encre)),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              style: texte.bodyMedium?.copyWith(
                color: surFondSombre
                    ? Colors.white.withValues(alpha: 0.82)
                    : couleurs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// La rangée d'onglets qui mène à chaque section.
///
/// ⚠️ ÉPINGLÉE SOUS LA BARRE DU HAUT : elle reste à portée pendant qu'on fait
/// défiler. L'onglet de la section visible est marqué, par la couleur ET par
/// un fond — la couleur seule ne dit rien à qui ne distingue pas les teintes.
///
/// ⚠️ ELLE SUIT LA LECTURE. Cinq onglets ne tiennent pas dans 360 points :
/// « Nous joindre », le plus utile à un prospect, était hors champ à droite,
/// et le restait même quand on lisait sa section. L'onglet actif est
/// maintenant ramené dans le champ à chaque changement.
///
/// ⚠️ Une `Row` dans un défileur, et non une liste paresseuse : une liste ne
/// construit pas ce qui dépasse, et l'on ne peut pas amener à l'écran un
/// onglet qui n'existe pas encore.
class OngletsDeSections extends StatefulWidget {
  const OngletsDeSections({
    super.key,
    required this.sections,
    required this.active,
    required this.surChoix,
  });

  final List<String> sections;
  final int active;
  final void Function(int) surChoix;

  static const hauteur = 52.0;

  @override
  State<OngletsDeSections> createState() => _EtatDesOnglets();
}

class _EtatDesOnglets extends State<OngletsDeSections> {
  late final _cles = List.generate(widget.sections.length, (_) => GlobalKey());
  final _rangee = ScrollController();

  @override
  void dispose() {
    _rangee.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(OngletsDeSections ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.active == widget.active) return;
    // Après le dessin : l'onglet doit avoir sa taille avant qu'on le déplace.
    WidgetsBinding.instance.addPostFrameCallback((_) => _centrer());
  }

  /// Ramène l'onglet actif au milieu de la rangée.
  ///
  /// ⚠️ SANS `Scrollable.ensureVisible`, et c'est la raison de ce code.
  /// `ensureVisible` fait défiler TOUS les défileurs parents : il amenait
  /// l'onglet dans le champ de la rangée, puis faisait sauter la page entière
  /// jusqu'en bas pour « montrer » un onglet qui est épinglé et déjà visible.
  /// On ne fait défiler ici que la rangée, par son propre contrôleur.
  void _centrer() {
    final boite = _cles[widget.active].currentContext?.findRenderObject();
    if (boite == null || !boite.attached || !_rangee.hasClients) return;
    final vue = RenderAbstractViewport.maybeOf(boite);
    if (vue == null) return;
    final cible = vue
        .getOffsetToReveal(boite, 0.5)
        .offset
        .clamp(0.0, _rangee.position.maxScrollExtent);
    _rangee.animateTo(
      cible,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Container(
      height: OngletsDeSections.hauteur,
      decoration: BoxDecoration(
        color: couleurs.surface,
        border: Border(bottom: BorderSide(color: couleurs.outlineVariant)),
      ),
      child: SingleChildScrollView(
        key: const Key('rangee-onglets'),
        controller: _rangee,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            for (var i = 0; i < widget.sections.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _Onglet(
                key: _cles[i],
                cle: i,
                libelle: widget.sections[i],
                choisi: i == widget.active,
                surAppui: () => widget.surChoix(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({
    super.key,
    required this.cle,
    required this.libelle,
    required this.choisi,
    required this.surAppui,
  });

  final int cle;
  final String libelle;
  final bool choisi;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Material(
      color: choisi ? couleurs.primaryContainer : Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Marque.rayonCarte)),
      ),
      child: InkWell(
        key: Key('onglet-section-$cle'),
        customBorder: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Marque.rayonCarte)),
        ),
        onTap: surAppui,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            libelle,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 14,
              color: choisi ? couleurs.primary : couleurs.onSurfaceVariant,
              fontWeight: choisi ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Les quatre chiffres du cabinet.
class ChiffresDuCabinet extends StatelessWidget {
  const ChiffresDuCabinet({super.key});

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Carte(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (var ligne = 0; ligne < 2; ligne++) ...[
              if (ligne == 1)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: couleurs.outlineVariant,
                ),
              IntrinsicHeight(
                child: Row(
                  children: [
                    for (var col = 0; col < 2; col++) ...[
                      if (col == 1)
                        VerticalDivider(
                          width: 1,
                          indent: 12,
                          endIndent: 12,
                          color: couleurs.outlineVariant,
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // La pastille teintée : elle pose le signe
                                  // sans lui donner le poids d'un bouton.
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: couleurs.primaryContainer,
                                      borderRadius: BorderRadius.circular(
                                        Marque.rayonBloc,
                                      ),
                                    ),
                                    child: Icon(
                                      chiffresDuCabinet[ligne * 2 + col].icone,
                                      size: 17,
                                      color: couleurs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: Marque.espace2),
                                  Expanded(
                                    child: Text(
                                      chiffresDuCabinet[ligne * 2 + col].valeur,
                                      style: texte.titleLarge?.copyWith(
                                        color: couleurs.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Marque.espace2),
                              Text(
                                chiffresDuCabinet[ligne * 2 + col].libelle,
                                style: texte.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// L'offre du moment, telle que le serveur l'annonce.
class BandeauAnnonce extends StatelessWidget {
  const BandeauAnnonce({
    super.key,
    required this.annonce,
    required this.surLire,
  });

  final Annonce annonce;

  /// `null` quand l'annonce ne renvoie pas à un article que l'application
  /// sait ouvrir.
  final VoidCallback? surLire;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: couleurs.primaryContainer,
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('annonce'),
          onTap: surLire,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.local_offer_outlined, color: couleurs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        annonce.etiquette.toUpperCase(),
                        style: texte.labelSmall?.copyWith(
                          color: couleurs.primary,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        annonce.texte,
                        style: texte.bodyMedium?.copyWith(
                          color: couleurs.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (surLire != null && annonce.libelleLien != null) ...[
                        const SizedBox(height: 8),
                        // ⚠️ Une icône et non le caractère « → » : sur le
                        // rendu d'essai, la flèche sortait en carré, faute de
                        // glyphe dans la police. Une icône ne dépend d'aucune
                        // police installée sur le téléphone.
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              annonce.libelleLien!,
                              style: texte.labelLarge?.copyWith(
                                color: couleurs.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: couleurs.primary,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ce que l'adhésion change : la section sombre de la page.
///
/// ⚠️ LA SEULE SECTION SUR FOND INDIGO, comme sur la vitrine. Elle casse le
/// rythme des cartes blanches à l'endroit où l'on explique POURQUOI adhérer :
/// l'œil qui fait défiler s'y arrête.
class SectionAdhesion extends StatelessWidget {
  const SectionAdhesion({super.key});

  static const _icones = [
    Icons.percent,
    Icons.savings_outlined,
    Icons.fact_check_outlined,
    Icons.handshake_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: Marque.indigo900,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TitreDeSection(
            kicker: Adhesion.kicker,
            titre: Adhesion.titre,
            detail: Adhesion.detail,
            surFondSombre: true,
          ),
          const SizedBox(height: 20),
          for (final (i, a) in Adhesion.avantages.indexed)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // Un blanc à 7 % : la carte se devine sur l'indigo sans
                  // devenir un rectangle clair qui écraserait le texte.
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(Marque.rayonCarte),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Marque.magenta600Sombre.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icones[i], size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.titre,
                            style: texte.titleSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a.detail,
                            style: texte.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Les trois étapes, en frise verticale.
class SectionEtapes extends StatelessWidget {
  const SectionEtapes({super.key});

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TitreDeSection(kicker: Etapes.kicker, titre: Etapes.titre),
        const SizedBox(height: 18),
        for (final (i, e) in Etapes.liste.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ⚠️ Le numéro ET le trait : la frise se lit comme une
                  // suite. Le trait s'arrête à la dernière étape, sans quoi
                  // il promettrait une quatrième.
                  SizedBox(
                    width: 36,
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: couleurs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: texte.titleSmall?.copyWith(
                              color: couleurs.onPrimary,
                            ),
                          ),
                        ),
                        if (i < Etapes.liste.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: couleurs.outlineVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.titre, style: texte.titleSmall),
                          const SizedBox(height: 4),
                          Text(e.detail, style: texte.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Une image publiée par la vitrine, avec un repli qui ne ment pas.
///
/// ⚠️ Pas de réseau, image absente : on affiche un aplat indigo pâle et une
/// icône, jamais une image « d'attente » qui ressemblerait à du contenu.
class ImageDeLaVitrine extends StatelessWidget {
  const ImageDeLaVitrine({
    super.key,
    required this.adresse,
    this.icone = Icons.article_outlined,
  });

  final Uri? adresse;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final repli = ColoredBox(
      color: couleurs.secondaryContainer,
      child: Center(
        child: Icon(icone, color: couleurs.onSecondaryContainer, size: 28),
      ),
    );
    final a = adresse;
    if (a == null) return repli;
    return Image.network(
      a.toString(),
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => repli,
      loadingBuilder: (_, enfant, progres) => progres == null ? enfant : repli,
    );
  }
}

/// Le blog : une rangée d'articles à faire glisser.
class SectionBlog extends StatelessWidget {
  const SectionBlog({
    super.key,
    required this.articles,
    required this.imageDe,
    required this.surOuvrir,
  });

  /// `null` : le serveur n'a pas répondu.
  final List<Article>? articles;
  final Uri Function(String) imageDe;
  final void Function(Article) surOuvrir;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final liste = articles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TitreDeSection(kicker: Blog.kicker, titre: Blog.titre),
        const SizedBox(height: 16),
        if (liste == null)
          // ⚠️ Pas de réseau se dit, sans occuper la place d'une section.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Les articles se chargent depuis le serveur. Ils reparaîtront '
              'dès que la connexion revient.',
              style: texte.bodySmall,
            ),
          )
        else if (liste.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Aucun article publié pour le moment.',
              style: texte.bodySmall,
            ),
          )
        else
          SizedBox(
            height: 292,
            child: ListView.separated(
              key: const Key('rangee-articles'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: liste.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(
                // ⚠️ 78 % de la largeur : la carte suivante dépasse du bord,
                // et c'est ce qui dit qu'on peut faire glisser. Une carte
                // pleine largeur cacherait qu'il y en a d'autres.
                width: MediaQuery.sizeOf(context).width * 0.78,
                child: CarteArticle(
                  article: liste[i],
                  image: liste[i].image == null
                      ? null
                      : imageDe(liste[i].image!),
                  surOuvrir: () => surOuvrir(liste[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Un article, en carte.
class CarteArticle extends StatelessWidget {
  const CarteArticle({
    super.key,
    required this.article,
    required this.image,
    required this.surOuvrir,
  });

  final Article article;
  final Uri? image;
  final VoidCallback surOuvrir;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return Carte(
      key: Key('article-${article.slug}'),
      padding: EdgeInsets.zero,
      surAppui: surOuvrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 128,
            width: double.infinity,
            child: ImageDeLaVitrine(adresse: image),
          ),
          // ⚠️ `Expanded` et un `Spacer` : la rangée donne à chaque carte la
          // même hauteur, et un titre court laissait un grand blanc SOUS la
          // durée de lecture, comme une carte à moitié chargée. La durée est
          // maintenant posée en pied de carte ; le blanc tombe entre le titre
          // et elle, où il se lit comme de l'air.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Etiquette(
                    libelleDeRubrique(article.rubrique),
                    couleur: couleurs.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.titre,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: texte.titleSmall,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 15,
                        color: couleurs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${article.minutes} min de lecture',
                        style: texte.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Les institutions dans le cadre desquelles le cabinet exerce.
class SectionPartenaires extends StatelessWidget {
  const SectionPartenaires({
    super.key,
    required this.institutions,
    required this.imageDe,
  });

  final List<Institution> institutions;
  final Uri Function(String) imageDe;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TitreDeSection(
          kicker: Partenaires.kicker,
          titre: Partenaires.titre,
          detail: Partenaires.detail,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final i in institutions)
                Container(
                  width: (MediaQuery.sizeOf(context).width - 50) / 2,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Marque.rayonBloc),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: i.logo == null
                            ? const SizedBox()
                            : Image.network(
                                imageDe(i.logo!).toString(),
                                fit: BoxFit.contain,
                                // Le nom est écrit dessous : le logo n'a rien
                                // à ajouter pour un lecteur d'écran.
                                excludeFromSemantics: true,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.account_balance_outlined),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        i.nom,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: texte.labelSmall?.copyWith(height: 1.3),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nous joindre : les trois canaux de la vitrine, et les services sur devis.
class SectionJoindre extends StatelessWidget {
  const SectionJoindre({super.key});

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TitreDeSection(
          kicker: 'Nous joindre',
          titre: Joindre.titre,
          detail: Joindre.detail,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Carte(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _Canal(
                  cle: 'joindre-whatsapp',
                  icone: Icons.chat_outlined,
                  titre: 'WhatsApp',
                  valeur: Cabinet.whatsapp,
                  detail: 'Le canal le plus utilisé par nos clients.',
                  surAppui: () => joindre(
                    context,
                    Cabinet.whatsappLien,
                    aCopier: Cabinet.whatsapp,
                  ),
                ),
                Divider(indent: 70, color: couleurs.outlineVariant),
                _Canal(
                  cle: 'joindre-telephone',
                  icone: Icons.call_outlined,
                  titre: 'Téléphone',
                  valeur: Cabinet.telephone,
                  detail: 'Standard du cabinet, aux heures d\'ouverture.',
                  surAppui: () => joindre(
                    context,
                    Cabinet.telephoneLien,
                    aCopier: Cabinet.telephone,
                  ),
                ),
                Divider(indent: 70, color: couleurs.outlineVariant),
                _Canal(
                  cle: 'joindre-courriel',
                  icone: Icons.mail_outline,
                  titre: 'Courriel',
                  valeur: Cabinet.courriel,
                  detail: 'Pour les demandes détaillées et les pièces jointes.',
                  surAppui: () => joindre(
                    context,
                    Cabinet.courrielLien,
                    aCopier: Cabinet.courriel,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Les services de la vitrine qui ne sont pas au barème : ils se
        // traitent par un appel, et c'est ici qu'on appelle.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Et aussi, sur devis', style: texte.titleSmall),
        ),
        const SizedBox(height: 10),
        for (final s in autresServices)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Bloc(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.titre, style: texte.titleSmall),
                  const SizedBox(height: 4),
                  Text(s.detail, style: texte.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Canal extends StatelessWidget {
  const _Canal({
    required this.cle,
    required this.icone,
    required this.titre,
    required this.valeur,
    required this.detail,
    required this.surAppui,
  });

  final String cle;
  final IconData icone;
  final String titre;
  final String valeur;
  final String detail;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return InkWell(
      key: Key(cle),
      onTap: surAppui,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: couleurs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 20, color: couleurs.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre, style: texte.bodySmall),
                  Text(valeur, style: texte.titleSmall),
                  Text(detail, style: texte.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: couleurs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Le pied de page : l'agrément, et l'entrée de l'espace adhérent.
class PiedDePage extends StatelessWidget {
  const PiedDePage({
    super.key,
    required this.surSeConnecter,
    required this.surSuivre,
  });
  final VoidCallback surSeConnecter;

  /// Suivre une souscription déjà réglée, par sa référence.
  final VoidCallback surSuivre;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: Marque.indigo900,
      padding: EdgeInsets.fromLTRB(
        20,
        28,
        20,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(Marque.logoBlanc, height: 40, semanticLabel: Cabinet.nom),
          const SizedBox(height: 14),
          Text(
            Cabinet.agrement,
            style: texte.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            key: const Key('pied-se-connecter'),
            onPressed: surSeConnecter,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.login),
            label: const Text('Déjà adhérent ? Accéder à votre dossier'),
          ),
          TextButton.icon(
            key: const Key('pied-suivre'),
            onPressed: surSuivre,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.track_changes),
            label: const Text('Vous avez souscrit ? Suivre votre souscription'),
          ),
        ],
      ),
    );
  }
}
