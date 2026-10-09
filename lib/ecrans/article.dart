import 'package:flutter/material.dart';

import '../composants/carte.dart';
import '../composants/joindre.dart';
import '../contenu/cabinet.dart';
import '../domaine/vitrine.dart';
import '../marque.dart';
import '../ports/service_public.dart';
import 'public/sections.dart';

/// Un article du blog, lu dans l'application.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ LU DANS L'APPLICATION, ET NON OUVERT DANS UN NAVIGATEUR.
///
/// Renvoyer vers le site ferait quitter l'application au milieu d'un
/// parcours, sur une page qui charge une seconde fois le logo, le menu et le
/// pied de page, en 3G. Le serveur sert le texte découpé en blocs — paragraphe,
/// intertitre, encadré, liste — : l'application les dessine avec sa propre
/// typographie.
///
/// ⚠️ Et l'article se termine sur une ACTION, comme sur la vitrine : un
/// lecteur qui vient d'apprendre que l'IGS se paie sans bénéfice a une
/// question, et la réponse est à un appui.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranArticle extends StatefulWidget {
  const EcranArticle({
    super.key,
    required this.servicePublic,
    required this.slug,
  });

  final ServicePublic servicePublic;
  final String slug;

  @override
  State<EcranArticle> createState() => _EtatDeLArticle();
}

class _EtatDeLArticle extends State<EcranArticle> {
  ArticleComplet? _article;
  bool _enCours = true;

  @override
  void initState() {
    super.initState();
    _lire();
  }

  Future<void> _lire() async {
    setState(() => _enCours = true);
    final lu = await widget.servicePublic.article(widget.slug);
    if (!mounted) return;
    setState(() {
      _article = lu;
      _enCours = false;
    });
  }

  void _ouvrir(Article voisin) => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) =>
          EcranArticle(servicePublic: widget.servicePublic, slug: voisin.slug),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = _article;
    if (_enCours && a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_outlined, size: 40),
              const SizedBox(height: 14),
              Text(
                "L'article n'a pas pu être chargé.",
                key: const Key('article-introuvable'),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _lire, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final texte = Theme.of(context).textTheme;
    final couleurs = Theme.of(context).colorScheme;
    final image = a.article.image;
    return Scaffold(
      backgroundColor: couleurs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: Marque.indigo900,
            foregroundColor: Colors.white,
            // ⚠️ UNE PASTILLE SOMBRE SOUS LA FLÈCHE. Vue sur le téléphone : la
            // flèche blanche posée sur la photo claire d'une salle de réunion
            // disparaissait contre le mur. La pastille indigo à 70 % lui donne
            // un fond sûr, quelle que soit la photo de l'article.
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: IconButton(
                key: const Key('article-retour'),
                tooltip: 'Revenir',
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  backgroundColor: Marque.indigo900.withValues(alpha: 0.7),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: ImageDeLaVitrine(
                adresse: image == null
                    ? null
                    : widget.servicePublic.imageDeLaVitrine(image),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Etiquette(
                    libelleDeRubrique(a.article.rubrique),
                    couleur: couleurs.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(a.article.titre, style: texte.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    '${_date(a.article.date)} · '
                    '${a.article.minutes} min de lecture',
                    style: texte.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    a.article.accroche,
                    style: texte.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final bloc in a.corps) _Bloc(bloc: bloc),
                  const SizedBox(height: 20),
                  _Appel(),
                  if (a.voisins.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text('À lire ensuite', style: texte.titleMedium),
                    const SizedBox(height: 10),
                    for (final v in a.voisins)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Carte(
                          key: Key('voisin-${v.slug}'),
                          surAppui: () => _ouvrir(v),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      libelleDeRubrique(v.rubrique),
                                      style: texte.labelSmall?.copyWith(
                                        color: couleurs.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(v.titre, style: texte.titleSmall),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                  ],
                  SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// « 23 janvier 2026 ». ⚠️ Jamais « 2026-01-23 » : une date ISO se lit comme
/// un code, pas comme un jour.
String _date(DateTime d) {
  const mois = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${d.day} ${mois[d.month - 1]} ${d.year}';
}

class _Bloc extends StatelessWidget {
  const _Bloc({required this.bloc});
  final BlocDArticle bloc;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final couleurs = Theme.of(context).colorScheme;
    // ⚠️ Un `switch` exhaustif sur une classe scellée : un nouveau type de
    // bloc côté serveur oblige à le traiter ici, le compilateur y veille.
    return switch (bloc) {
      Paragraphe(:final texte) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          texte,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
      ),
      Intertitre(:final texte) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text(texte, style: Theme.of(context).textTheme.titleMedium),
      ),
      Encadre(:final titre, texte: final corps) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: couleurs.secondaryContainer,
          borderRadius: BorderRadius.circular(Marque.rayonBloc),
          border: Border(
            left: BorderSide(color: couleurs.onSecondaryContainer, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titre != null) ...[
              Text(
                titre,
                style: texte.titleSmall?.copyWith(
                  color: couleurs.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              corps,
              style: texte.bodyMedium?.copyWith(
                color: couleurs.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
      Liste(:final points) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 9, right: 10),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: couleurs.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        p,
                        style: texte.bodyLarge?.copyWith(height: 1.55),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      BlocInconnu(:final texte) =>
        texte.isEmpty
            ? const SizedBox()
            : Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(texte),
              ),
    };
  }
}

/// La question que l'article fait naître, et où la poser.
class _Appel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final couleurs = Theme.of(context).colorScheme;
    // ⚠️ SUR L'INDIGO PÂLE, ET NON SUR L'INDIGO 900. Le bouton magenta posé sur
    // l'indigo 900 ne s'en détachait qu'à 2,05:1, sous les 3:1 exigés du bord
    // d'un composant : on voyait le texte du bouton flotter, pas le bouton.
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: couleurs.secondaryContainer,
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Une question sur votre situation ?',
            style: texte.titleMedium?.copyWith(
              color: couleurs.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Un expert du cabinet vous répond sur WhatsApp.',
            style: texte.bodyMedium?.copyWith(
              color: couleurs.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('article-whatsapp'),
            onPressed: () => joindre(
              context,
              Cabinet.whatsappLien,
              aCopier: Cabinet.whatsapp,
            ),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Écrire au cabinet'),
          ),
        ],
      ),
    );
  }
}
