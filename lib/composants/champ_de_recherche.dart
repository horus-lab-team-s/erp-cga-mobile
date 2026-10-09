import 'package:flutter/material.dart';

import '../marque.dart';

/// Le champ qui filtre une longue liste, sur place.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ DANS LA LISTE, ET NON DANS LA BARRE DU HAUT.
///
/// Une loupe en barre de titre ouvre un mode : la barre se transforme, le titre
/// disparaît, et il faut une croix pour en sortir. C'est le geste des
/// applications de messagerie, où l'on cherche dans des milliers d'éléments.
/// Ici l'adhérent filtre soixante lignes : le champ posé en tête de liste se
/// voit, se remplit et se vide sans jamais changer d'écran — et il défile avec
/// le contenu, donc il ne mange rien quand on n'en a pas besoin.
///
/// ⚠️ IL NE S'AFFICHE QU'AU-DELÀ D'UN SEUIL. Sur trois documents, un champ de
/// recherche est du bruit : on lit les trois plus vite qu'on ne tape. Le seuil
/// appartient à l'écran qui l'emploie, parce qu'une ligne d'accusé et une ligne
/// de pièce n'occupent pas la même hauteur.
///
/// ⚠️ PAS DE BOUTON « CHERCHER ». Le filtre s'applique à la frappe. Un bouton
/// ajouterait un geste à chaque essai, alors qu'on cherche rarement juste du
/// premier coup.
/// ─────────────────────────────────────────────────────────────────────────────
class ChampDeRecherche extends StatefulWidget {
  const ChampDeRecherche({
    super.key,
    required this.valeur,
    required this.surChangement,
    required this.invite,
  });

  /// Ce qui est tapé. ⚠️ L'écran le détient : le champ ne garde aucun état, et
  /// se reconstruit sans perdre ce qui est saisi.
  final String valeur;

  final ValueChanged<String> surChangement;

  /// Ce qu'on peut taper, en toutes lettres. ⚠️ « Rechercher » seul ne dit pas
  /// sur QUOI porte la recherche, et l'on tâtonne.
  final String invite;

  @override
  State<ChampDeRecherche> createState() => _EtatDuChamp();
}

class _EtatDuChamp extends State<ChampDeRecherche> {
  /// ─────────────────────────────────────────────────────────────────────────
  /// ⚠️ UN CONTRÔLEUR TENU, ET NON REFABRIQUÉ À CHAQUE CONSTRUCTION.
  ///
  /// La première écriture de ce composant fabriquait un
  /// `TextEditingController.fromValue(...)` dans `build`. Cela paraît marcher :
  /// le texte s'affiche, le filtre s'applique. Mais la liste se reconstruit à
  /// CHAQUE frappe, donc le champ recevait un contrôleur neuf à chaque lettre,
  /// et la **région de composition** était perdue avec l'ancien.
  ///
  /// Sur un clavier Android, cette région porte le mot en cours : la saisie
  /// prédictive, la correction automatique, et surtout les accents composés —
  /// le « é » obtenu en maintenant le « e ». C'est-à-dire précisément ce dont
  /// se sert quelqu'un qui tape « février ». Le champ existe pour chercher en
  /// français ; le casser sur les accents serait une ironie coûteuse.
  ///
  /// Le contrôleur vit donc ici, et l'écran reste la source : on ne recopie la
  /// valeur que lorsqu'elle DIFFÈRE du texte saisi — sinon, remettre le même
  /// texte replacerait le curseur à chaque frappe.
  /// ─────────────────────────────────────────────────────────────────────────
  late final _controleur = TextEditingController(text: widget.valeur);

  @override
  void didUpdateWidget(ChampDeRecherche ancien) {
    super.didUpdateWidget(ancien);
    if (widget.valeur != _controleur.text) {
      _controleur.value = TextEditingValue(
        text: widget.valeur,
        selection: TextSelection.collapsed(offset: widget.valeur.length),
      );
    }
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final valeur = widget.valeur;
    return TextField(
      key: const Key('champ-de-recherche'),
      controller: _controleur,
      onChanged: widget.surChangement,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.invite,
        prefixIcon: Icon(
          Icons.search,
          size: 20,
          color: couleurs.onSurfaceVariant,
        ),
        suffixIcon: valeur.isEmpty
            ? null
            : IconButton(
                key: const Key('effacer-la-recherche'),
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Effacer',
                onPressed: () => widget.surChangement(''),
              ),
        filled: true,
        fillColor: couleurs.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Marque.rayonPastille),
          borderSide: BorderSide(color: couleurs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Marque.rayonPastille),
          borderSide: BorderSide(color: couleurs.outlineVariant),
        ),
      ),
    );
  }
}

/// Ce qu'on affiche quand le filtre ne laisse rien passer.
///
/// ⚠️ **JAMAIS « AUCUN DOCUMENT ».** C'est la règle tenue partout dans cette
/// application : ne pas laisser croire à un adhérent que le cabinet n'a rien
/// pour lui alors que c'est sa recherche qui ne rend rien. La phrase nomme donc
/// ce qui a été cherché, et propose le seul geste utile — effacer.
class RienNeCorrespond extends StatelessWidget {
  const RienNeCorrespond({
    super.key,
    required this.recherche,
    required this.surEffacer,
  });

  final String recherche;
  final VoidCallback surEffacer;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Padding(
      key: const Key('rien-ne-correspond'),
      padding: const EdgeInsets.symmetric(vertical: Marque.espace8),
      child: Column(
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 34,
            color: couleurs.onSurfaceVariant,
          ),
          const SizedBox(height: Marque.espace3),
          Text(
            'Rien ne correspond à « $recherche »',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: couleurs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vos autres documents sont toujours là.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: couleurs.onSurfaceVariant),
          ),
          const SizedBox(height: Marque.espace3),
          TextButton(
            key: const Key('tout-revoir'),
            onPressed: surEffacer,
            child: const Text('Tout revoir'),
          ),
        ],
      ),
    );
  }
}
