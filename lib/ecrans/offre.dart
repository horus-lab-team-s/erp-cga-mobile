import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../domaine/offre.dart';
import '../domaine/vitrine.dart';
import '../marque.dart';
import '../ports/service_public.dart';
import 'article.dart';
import 'suivi.dart';
import 'public/bandeau.dart';
import 'public/carte_service.dart';
import 'public/sections.dart';

export 'public/bandeau.dart' show hauteurDuBandeau;

/// La page publique : tout ce que la vitrine dit, sur un seul écran.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ LE PREMIER ÉCRAN DE L'APPLICATION, ET NON LA CONNEXION
///
/// L'application s'ouvrait sur un mur de connexion. Or le compte naît de la
/// souscription réglée : exiger un compte pour voir l'offre demandait d'avoir
/// acheté pour savoir ce qu'on achète.
///
/// ⚠️ LA VITRINE ENTIÈRE, ET PLUS SEULEMENT LE CATALOGUE.
///
/// La première version ne montrait que les tarifs. Un commerçant qui découvre
/// le cabinet a d'autres questions avant « combien » : qui êtes-vous, qu'est-ce
/// qu'un centre agréé m'apporte, comment ça se passe, comment je vous joins.
/// La vitrine y répond sur sept pages ; cet écran y répond en une, dans le même
/// ordre, avec une rangée d'onglets pour aller droit à une section.
///
/// ⚠️ DEUX FAMILLES DE PRESTATIONS, ET LA DISTINCTION N'EST PAS DÉCORATIVE.
/// Trois se souscrivent en ligne ; deux — la création d'entreprise et le
/// ponctuel — passent par un examen du cabinet. Le serveur refuse en 422 une
/// souscription sur les secondes : leur donner le même bouton promettrait ce
/// qu'il refuse.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranOffre extends StatefulWidget {
  const EcranOffre({
    super.key,
    required this.servicePublic,
    required this.quandSeConnecter,
    required this.quandSouscrire,
  });

  final ServicePublic servicePublic;
  final VoidCallback quandSeConnecter;

  /// Appelé avec le service choisi. ⚠️ Seulement pour ceux qui se souscrivent
  /// en ligne : voir l'en-tête.
  final void Function(Service) quandSouscrire;

  @override
  State<EcranOffre> createState() => _EtatDeLOffre();
}

/// Les sections vers lesquelles mènent les onglets, dans l'ordre de la page.
const _sections = ['Offres', 'Adhésion', 'Étapes', 'Conseils', 'Nous joindre'];

class _EtatDeLOffre extends State<EcranOffre> {
  Offre? _offre;
  Annonce? _annonce;
  List<Article>? _articles;
  List<Institution> _institutions = const [];
  bool _lectureEnCours = true;

  final _defilement = ScrollController();
  final _ancres = List.generate(_sections.length, (_) => GlobalKey());
  int _sectionVisible = 0;

  @override
  void initState() {
    super.initState();
    _defilement.addListener(_suivreLaSection);
    _relire();
  }

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  /// ⚠️ LES QUATRE LECTURES PARTENT ENSEMBLE, et aucune n'attend l'autre. Le
  /// blog ou l'annonce qui ne répondent pas ne doivent pas retenir le
  /// catalogue : c'est lui que le visiteur vient voir.
  Future<void> _relire() async {
    setState(() => _lectureEnCours = true);
    final p = widget.servicePublic;
    final offre = p.offreDuJour();
    final annonce = p.annonceDuJour();
    final articles = p.articles();
    final institutions = p.institutions();
    final o = await offre;
    if (!mounted) return;
    setState(() {
      _offre = o;
      _lectureEnCours = false;
    });
    final (a, ar, i) = (await annonce, await articles, await institutions);
    if (!mounted) return;
    setState(() {
      _annonce = a;
      _articles = ar;
      _institutions = i;
    });
  }

  /// La hauteur de ce qui reste épinglé en haut : barre d'état, barre
  /// d'outils, onglets. Une section qu'on rejoint doit commencer SOUS eux.
  double get _hautEpingle =>
      MediaQuery.paddingOf(context).top +
      kToolbarHeight +
      OngletsDeSections.hauteur;

  /// Où commence une section DANS LA PAGE, quel que soit le défilement.
  ///
  /// ⚠️ ET NON « OÙ ELLE EST À L'ÉCRAN ». La première version lisait la
  /// position à l'écran pendant le défilement. Or l'écouteur du défilement est
  /// appelé AVANT que la page soit remise en page : la position lue était
  /// celle de l'image précédente. Au bas de la page, l'écran croyait encore
  /// être en haut, marquait « Offres » comme section lue, et un onglet touché
  /// calculait sa cible à partir de positions périmées : il ne menait nulle
  /// part.
  ///
  /// `getOffsetToReveal` rend le défilement auquel la section arrive en haut
  /// de la zone visible. Il ne dépend que de la mise en page de la section
  /// dans la page, pas de l'endroit où l'on se trouve.
  double? _debutDe(int i) {
    final boite = _ancres[i].currentContext?.findRenderObject();
    if (boite == null || !boite.attached) return null;
    final vue = RenderAbstractViewport.maybeOf(boite);
    return vue?.getOffsetToReveal(boite, 0).offset;
  }

  /// Fait défiler jusqu'à une section.
  ///
  /// ⚠️ SANS `Scrollable.ensureVisible` : celui-ci alignait la section sur le
  /// haut de la zone de défilement, c'est-à-dire DERRIÈRE la barre et les
  /// onglets épinglés — le titre arrivait caché. On retranche ce qui est
  /// épinglé.
  void _allerA(int i) {
    final debut = _debutDe(i);
    if (debut == null) return;
    final cible = (debut - _hautEpingle - 8).clamp(
      0.0,
      _defilement.position.maxScrollExtent,
    );
    _defilement.animateTo(
      cible,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  /// Marque l'onglet de la section qu'on est en train de lire.
  void _suivreLaSection() {
    final ou = _defilement.offset + _hautEpingle;
    var visible = 0;
    for (var i = 0; i < _ancres.length; i++) {
      final debut = _debutDe(i);
      // Une section devient « la section lue » dès que son haut passe à 120
      // points sous les onglets : plus tôt, l'onglet sautait avant qu'on y
      // soit ; plus tard, il retardait sur la lecture.
      if (debut != null && debut <= ou + 120) visible = i;
    }
    // ⚠️ Au bas de la page, la dernière section est la section lue, même si
    // elle est trop courte pour que son haut monte jusqu'aux onglets : sans
    // cela, « Nous joindre » ne s'allumait jamais.
    if (_defilement.position.maxScrollExtent - _defilement.offset < 4) {
      visible = _ancres.length - 1;
    }
    if (visible != _sectionVisible) setState(() => _sectionVisible = visible);
  }

  void _lireArticle(String slug) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          EcranArticle(servicePublic: widget.servicePublic, slug: slug),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final o = _offre;
    final couleurs = Theme.of(context).colorScheme;
    final hautDeLEcran = MediaQuery.paddingOf(context).top;
    return Scaffold(
      // ⚠️ LE FOND TEINTÉ, ET NON LE BLANC : sur le fond teinté, le blanc
      // des cartes est ce qui les fait exister.
      backgroundColor: couleurs.surfaceContainerLowest,
      body: RefreshIndicator(
        onRefresh: _relire,
        // Sous la barre et les onglets, pas derrière.
        edgeOffset: hautDeLEcran + kToolbarHeight + OngletsDeSections.hauteur,
        child: CustomScrollView(
          controller: _defilement,
          slivers: [
            // ⚠️ La barre épinglée porte la marque et l'accès au compte ; le
            // fond porte la ville et la promesse, qui s'effacent au
            // défilement.
            SliverAppBar(
              pinned: true,
              expandedHeight: hauteurDuBandeau(context),
              backgroundColor: Marque.indigo900,
              foregroundColor: Colors.white,
              titleSpacing: 20,
              title: const LogoDuBandeau(),
              actions: [
                BoutonConnexion(surAppui: widget.quandSeConnecter),
                const SizedBox(width: 14),
              ],
              flexibleSpace: FlexibleSpaceBar(
                // ⚠️ `pin` et non le parallaxe par défaut : le texte glissait
                // plus vite que le bandeau et passait sous la barre.
                collapseMode: CollapseMode.pin,
                background: FondDuBandeau(hautDeLEcran: hautDeLEcran),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _EnteteDOnglets(
                OngletsDeSections(
                  sections: _sections,
                  active: _sectionVisible,
                  surChoix: _allerA,
                ),
              ),
            ),

            switch ((_lectureEnCours, o)) {
              (true, null) => const SliverFillRemaining(
                key: Key('offre-en-attente'),
                child: Center(child: CircularProgressIndicator()),
              ),
              (_, null) => const SliverFillRemaining(
                hasScrollBody: false,
                child: _PasDeReseau(),
              ),
              (_, final Offre x) when !x.serveurJoignable =>
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _PasDeReseau(),
                ),
              // ⚠️ UN SEUL BLOC, ET NON UNE LISTE PARESSEUSE. Une liste ne
              // construit que ce qui est à l'écran : les sections du bas
              // n'existaient pas encore quand on touchait leur onglet, et
              // l'onglet ne menait nulle part. La page compte une dizaine de
              // sections : les construire toutes coûte moins qu'un onglet
              // mort.
              (_, final Offre x) => SliverToBoxAdapter(
                child: _Corps(
                  offre: x,
                  annonce: _annonce,
                  articles: _articles,
                  institutions: _institutions,
                  ancres: _ancres,
                  servicePublic: widget.servicePublic,
                  surSouscrire: widget.quandSouscrire,
                  surLireArticle: _lireArticle,
                  surSeConnecter: widget.quandSeConnecter,
                ),
              ),
            },
          ],
        ),
      ),
    );
  }
}

/// Le corps de la page, section après section.
class _Corps extends StatelessWidget {
  const _Corps({
    required this.offre,
    required this.annonce,
    required this.articles,
    required this.institutions,
    required this.ancres,
    required this.servicePublic,
    required this.surSouscrire,
    required this.surLireArticle,
    required this.surSeConnecter,
  });

  final Offre offre;
  final Annonce? annonce;
  final List<Article>? articles;
  final List<Institution> institutions;
  final List<GlobalKey> ancres;
  final ServicePublic servicePublic;
  final void Function(Service) surSouscrire;
  final void Function(String slug) surLireArticle;
  final VoidCallback surSeConnecter;

  @override
  Widget build(BuildContext context) {
    final a = annonce;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const ChiffresDuCabinet(),
        if (a != null) ...[
          const SizedBox(height: 14),
          BandeauAnnonce(
            annonce: a,
            surLire: a.slugDArticle == null
                ? null
                : () => surLireArticle(a.slugDArticle!),
          ),
        ],

        // ── Les offres ─────────────────────────────────────────────────────
        const SizedBox(height: 32),
        TitreDeSection(
          key: ancres[0],
          kicker: 'Nos services',
          titre: 'Souscrire depuis ce téléphone',
          detail:
              'Vous réglez par paiement mobile ; le cabinet vous envoie votre '
              'accès dès la validation.',
        ),
        const SizedBox(height: 16),
        for (final s in offre.enLigne)
          CarteService(service: s, surSouscrire: () => surSouscrire(s)),
        if (offre.surEtude.isNotEmpty) ...[
          const SizedBox(height: 20),
          const TitreDeSection(
            kicker: 'Sur étude',
            titre: 'Chiffré après examen de votre dossier',
            detail:
                'Le cabinet examine votre dossier, puis vous adresse une '
                'proposition. Ces prestations ne se règlent pas en ligne.',
          ),
          const SizedBox(height: 16),
          for (final s in offre.surEtude)
            CarteService(service: s, surSouscrire: null),
        ],

        // ── L'adhésion ─────────────────────────────────────────────────────
        const SizedBox(height: 28),
        SectionAdhesion(key: ancres[1]),

        // ── Les étapes ─────────────────────────────────────────────────────
        const SizedBox(height: 32),
        SectionEtapes(key: ancres[2]),

        // ── Le blog ────────────────────────────────────────────────────────
        const SizedBox(height: 20),
        SectionBlog(
          key: ancres[3],
          articles: articles,
          imageDe: servicePublic.imageDeLaVitrine,
          surOuvrir: (article) => surLireArticle(article.slug),
        ),

        if (institutions.isNotEmpty) ...[
          const SizedBox(height: 32),
          SectionPartenaires(
            institutions: institutions,
            imageDe: servicePublic.imageDeLaVitrine,
          ),
        ],

        // ── Nous joindre ───────────────────────────────────────────────────
        const SizedBox(height: 32),
        SectionJoindre(key: ancres[4]),
        const SizedBox(height: 32),
        PiedDePage(
          surSeConnecter: surSeConnecter,
          surSuivre: () => _demanderLaReference(context),
        ),
      ],
    );
  }
}

/// Demande la référence d'une souscription, puis ouvre son suivi.
///
/// ⚠️ Une feuille avec un seul champ, et non un écran : on vient de trouver la
/// référence dans un SMS ou sur une capture, on la colle, on valide.
extension on _Corps {
  void _demanderLaReference(BuildContext context) {
    final champ = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (feuille) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(feuille).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Suivre une souscription',
              style: Theme.of(feuille).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              "La référence figure sur l'écran de paiement. Elle commence par "
              '« SO- ».',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('champ-reference'),
              controller: champ,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Référence'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              key: const Key('ouvrir-le-suivi'),
              onPressed: () {
                final ref = champ.text.trim();
                if (ref.isEmpty) return;
                Navigator.of(feuille).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EcranSuivi(
                      servicePublic: servicePublic,
                      reference: ref,
                    ),
                  ),
                );
              },
              child: const Text('Voir où elle en est'),
            ),
          ],
        ),
      ),
    ).whenComplete(champ.dispose);
  }
}

/// Épingle la rangée d'onglets sous la barre du haut.
class _EnteteDOnglets extends SliverPersistentHeaderDelegate {
  _EnteteDOnglets(this.onglets);
  final OngletsDeSections onglets;

  @override
  double get minExtent => OngletsDeSections.hauteur;
  @override
  double get maxExtent => OngletsDeSections.hauteur;

  @override
  Widget build(BuildContext context, double decalage, bool recouvert) =>
      onglets;

  @override
  bool shouldRebuild(_EnteteDOnglets ancien) =>
      ancien.onglets.active != onglets.active;
}

class _PasDeReseau extends StatelessWidget {
  const _PasDeReseau();

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 70, 32, 32),
      child: Column(
        children: [
          Icon(
            Icons.wifi_off_outlined,
            size: 44,
            color: couleurs.onSurfaceVariant,
          ),
          const SizedBox(height: 18),
          Text(
            'Pas de réseau',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: couleurs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "L'offre du cabinet se lit sur le serveur, parce que les tarifs "
            'changent. Elle reparaîtra dès que la connexion revient.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: couleurs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
