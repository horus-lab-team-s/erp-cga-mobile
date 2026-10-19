import 'package:flutter/material.dart';

import '../marque.dart';

/// La carte, dessinée une seule fois pour toute l'application.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI CE COMPOSANT EXISTE
///
/// Sept écrans dessinaient chacun la leur, et toujours de la même façon : un
/// `Container` blanc, un filet gris dur, un rayon de 14. Le résultat tenait,
/// mais il donnait à l'application l'apparence d'un formulaire administratif —
/// une suite de rectangles encadrés.
///
/// Trois défauts se cachaient dans cette répétition :
///
///   · le fond de page et la carte ne différaient que d'un pour cent, donc le
///     filet dur était le SEUL moyen de voir la carte ;
///   · les rayons divergeaient d'un écran à l'autre — 10, 12, 14, 18 ;
///   · l'état d'alerte se disait par un filet rouge autour de toute la carte,
///     ce qui crie autant pour un retard de trois jours que pour un rejet.
///
/// Ici, la carte est blanche sur un fond teinté, séparée par une ombre très
/// basse, et l'alerte se dit par un BANDEAU LATÉRAL, qui se remarque sans
/// encadrer.
///
/// ⚠️ ET LA COULEUR NE PORTE JAMAIS SEULE L'INFORMATION — § 10.7. Le bandeau
/// rouge accompagne un mot, il ne le remplace pas : chaque écran qui passe
/// `ton: TonDeCarte.alerte` écrit aussi, dans la carte, ce qui ne va pas.
/// ─────────────────────────────────────────────────────────────────────────────
enum TonDeCarte {
  /// Le cas ordinaire.
  neutre,

  /// Quelque chose demande un geste de l'adhérent.
  alerte,

  /// Ce que l'écran met en avant : une seule par écran.
  accent,
}

/// Le relief d'une carte : posée seule, ou répétée dans une liste.
enum ReliefDeCarte {
  /// Une carte que l'écran met en avant : l'ombre pleine.
  posee,

  /// Un élément d'une liste : une ombre presque nulle.
  ///
  /// ⚠️ VU SUR L'APPAREIL : huit cartes à ombre pleine, l'une sous l'autre,
  /// font vibrer la page. Autant de reliefs que de lignes, et plus de hiérarchie.
  liste,
}

class Carte extends StatelessWidget {
  const Carte({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Marque.espace4),
    this.ton = TonDeCarte.neutre,
    this.relief = ReliefDeCarte.posee,
    this.surAppui,
    this.lueur,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final TonDeCarte ton;
  final ReliefDeCarte relief;

  /// Quand elle se touche. ⚠️ Le retour visuel passe par un `InkWell` posé
  /// SOUS le contenu et découpé au rayon : une carte qu'on touche sans qu'il
  /// ne se passe rien à l'écran laisse croire que l'appui n'a pas été pris.
  final VoidCallback? surAppui;

  /// La teinte vers laquelle la carte descend, et qui colore son ombre.
  /// `null` : l'indigo de la marque, ou la couleur du ton.
  final Color? lueur;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final rayon = BorderRadius.circular(Marque.rayonDeContenant);

    final accent = switch (ton) {
      TonDeCarte.neutre => null,
      TonDeCarte.alerte => couleurs.error,
      TonDeCarte.accent => couleurs.primary,
    };

    // ⚠️ 19 octobre 2026 : PLUS DE CARTE BLANCHE À PLAT. Le blanc pur cerné d'un
    // filet gris restait le rendu d'un formulaire. La carte descend désormais du
    // blanc vers une pointe de sa teinte — l'indigo de la marque, ou celle que
    // l'écran lui donne —, et son ombre est teintée de la même couleur : elle
    // paraît éclairée plutôt que découpée. Le filet gris disparaît en mode clair ;
    // un liseré blanc, à peine visible, garde le bord net au soleil.
    // La teinte par défaut est un lilas, entre l'indigo et le magenta : l'indigo
    // seul, à cette dose, rendait un gris froid, et la carte paraissait blanche.
    final lueurDeLaCarte =
        lueur ??
        accent ??
        Color.lerp(Marque.indigo700, Marque.magenta600, 0.45)!;
    final fond = couleurs.surfaceContainerLow;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fond,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fond,
            Color.alphaBlend(
              lueurDeLaCarte.withValues(alpha: sombre ? 0.12 : 0.10),
              fond,
            ),
          ],
        ),
        borderRadius: rayon,
        // ⚠️ L'OMBRE NE SE VOIT PAS EN MODE SOMBRE : une ombre est un
        // assombrissement, et l'on n'assombrit pas un fond déjà noir. Le
        // relief y passe donc par un filet, seule solution qui tienne.
        boxShadow: sombre
            ? null
            : [
                BoxShadow(
                  color: lueurDeLaCarte.withValues(alpha: 0.05),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: lueurDeLaCarte.withValues(
                    alpha: relief == ReliefDeCarte.posee ? 0.10 : 0.06,
                  ),
                  blurRadius: relief == ReliefDeCarte.posee ? 28 : 14,
                  offset: Offset(0, relief == ReliefDeCarte.posee ? 10 : 4),
                ),
              ],
        border: sombre
            ? Border.all(color: couleurs.outlineVariant)
            : Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: ClipRRect(
        borderRadius: rayon,
        child: _cliquable(
          Stack(
            children: [
              // Un halo dans le coin haut droit, pour la carte posée seule : la
              // lumière semble venir de l'écran, et la carte cesse d'être un
              // rectangle découpé. Pas sur les listes, où dix halos feraient
              // une tapisserie.
              if (relief == ReliefDeCarte.posee)
                Positioned(
                  top: -48,
                  right: -48,
                  child: IgnorePointer(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            lueurDeLaCarte.withValues(
                              alpha: sombre ? 0.16 : 0.09,
                            ),
                            lueurDeLaCarte.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                // Le bandeau mange 4 points : le contenu s'en écarte d'autant,
                // sans quoi le texte viendrait le toucher.
                padding: accent == null
                    ? EdgeInsets.zero
                    : const EdgeInsets.only(left: 3),
                child: Padding(padding: padding, child: child),
              ),
              if (accent != null)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  // ⚠️ TROIS POINTS, ET NON QUATRE. Sur une liste d'échéances en
                  // retard, le bandeau de quatre points lisait comme une barre
                  // d'erreur pleine hauteur : la page entière paraissait en faute.
                  width: 3,
                  child: ColoredBox(color: accent),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ⚠️ 19 octobre 2026 : l'`InkWell` se posait PAR-DESSUS le contenu, et captait
  /// tous les appuis. Le bouton « copier le numéro » d'un document ouvrait le reçu
  /// à la place. L'encre est désormais SOUS le contenu : un bouton intérieur garde
  /// son appui, le reste de la carte ouvre.
  Widget _cliquable(Widget contenu) {
    if (surAppui == null) return contenu;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: surAppui, child: contenu),
      ),
    );
  }
}

/// Un bloc posé À L'INTÉRIEUR d'une carte : un barème, un récapitulatif.
///
/// ⚠️ Pas d'ombre ici. Une ombre dans une ombre donne un empilement sale ; le
/// creux se dit par un fond légèrement plus soutenu que la carte.
class Bloc extends StatelessWidget {
  const Bloc({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(Marque.rayonBloc),
    ),
    child: child,
  );
}

/// Une étiquette courte : un état, une tranche, un guichet.
///
/// ⚠️ Elle porte TOUJOURS un mot. Une pastille de couleur seule ne dit rien à
/// qui ne distingue pas les teintes, et rien du tout à qui découvre l'écran.
/// Le titre d'une section d'écran, dessiné une seule fois.
///
/// ⚠️ Trois variantes coexistaient — petites capitales ici, titre gras là,
/// texte gris ailleurs. Le même niveau de lecture doit avoir la même forme,
/// sinon l'œil cherche la hiérarchie au lieu de la recevoir.
class TitreDeSection extends StatelessWidget {
  const TitreDeSection(this.texte, {super.key, this.complement});

  final String texte;

  /// Ce qui se dit à droite du titre : « Tout voir », un compte.
  final Widget? complement;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texteDuTheme = Theme.of(context).textTheme;
    // ⚠️ 19 octobre 2026 : un trait magenta devant le titre, et le titre en gras
    // et dans l'encre de l'institution. Le titre gris se confondait avec le texte
    // courant ; on le cherchait au lieu de le voir.
    final titre = Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Marque.magenta600, Marque.indigo700],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: Marque.espace2 + 2),
        Expanded(
          child: Text(
            texte,
            style: texteDuTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: couleurs.secondary,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
    if (complement == null) return titre;
    return Row(
      children: [
        Expanded(child: titre),
        complement!,
      ],
    );
  }
}

class Etiquette extends StatelessWidget {
  const Etiquette(
    this.texte, {
    super.key,
    this.couleur,
    this.icone,
    this.texteSombre = false,
  });

  /// L'avertissement : fond ambre pâle, icône ambre, TEXTE EN ENCRE SOMBRE.
  ///
  /// ⚠️ L'AMBRE NE SERT JAMAIS DE COULEUR DE TEXTE, règle déjà écrite dans les
  /// jetons du web (`tokens.css`, `--warning`). Mesuré ici : l'ambre en texte
  /// de 13 px sur sa propre teinte tient 3,75:1, sous les 4,5:1 exigés. Il ne
  /// porte donc que l'icône — un objet graphique, dont le seuil est de 3:1 —
  /// et le mot s'écrit en encre.
  const Etiquette.avertissement(this.texte, {super.key})
    : couleur = Marque.alerte,
      icone = Icons.warning_amber_rounded,
      texteSombre = true;

  final String texte;

  /// La teinte du texte et du fond. `null` : le ton neutre.
  final Color? couleur;
  final IconData? icone;

  /// Le texte en encre plutôt que dans la teinte : pour les teintes qui ne
  /// tiennent pas le contraste en petit texte.
  final bool texteSombre;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    // L'ambre de l'avertissement s'éclaircit en thème sombre (voir `Marque.alerteDe`).
    final teinte = couleur == Marque.alerte
        ? Marque.alerteDe(context)
        : couleur ?? couleurs.onSurfaceVariant;
    final encre = texteSombre ? couleurs.onSurface : teinte;
    return Container(
      // ⚠️ Plus discrète : 9/3 au lieu de 10/5. Une étiquette d'état accompagne
      // un titre ; à la taille d'un bouton, elle lui faisait concurrence.
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        // 10 % de la teinte : assez pour se détacher, assez peu pour que le
        // texte garde son contraste.
        color: couleur == null
            ? couleurs.surfaceContainer
            : teinte.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Marque.rayonPastille),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 14, color: teinte),
            const SizedBox(width: 5),
          ],
          // ⚠️ `Flexible` et une coupure propre : sans eux, une étiquette plus
          // longue que sa carte — « Le coin du fiscaliste » dans une carte
          // étroite, ou n'importe laquelle en gros caractères — débordait en
          // rayures jaunes et noires. Coupée, elle se lit encore ; débordante,
          // elle casse l'écran.
          Flexible(
            child: Text(
              texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: encre),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le chapeau d'un écran : ce qu'il faut retenir avant de lire le détail.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ INDIGO, ET NON PLUS MAGENTA.
///
/// Cinq écrans ouvraient sur ce bloc, tous teintés de magenta. Or le magenta
/// porte l'ACTION — § 10.7 —, et un résumé n'est pas une action : c'est
/// l'institution qui parle. Le magenta employé partout ne désignait plus rien,
/// et le bouton qui compte vraiment sur l'écran ne se détachait plus de son
/// chapeau.
///
/// L'indigo tient ce rôle, et il calme l'écran par-dessus le marché.
///
/// ⚠️ LE TON GRAVE RESTE ROUGE, et il porte une icône ET une phrase : la
/// couleur ne dit jamais seule ce qu'elle dit.
/// ─────────────────────────────────────────────────────────────────────────────
class Chapeau extends StatelessWidget {
  const Chapeau({
    super.key,
    required this.titre,
    required this.detail,
    this.icone,
    this.grave = false,
    this.dessous,
  });

  final String titre;
  final String detail;
  final IconData? icone;

  /// Quelque chose ne va pas et demande un geste.
  final bool grave;

  /// Ce que l'écran ajoute sous le texte : un rappel, un bouton.
  final Widget? dessous;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final fond = grave ? couleurs.errorContainer : couleurs.secondaryContainer;
    final encre = grave
        ? couleurs.onErrorContainer
        : couleurs.onSecondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Marque.espace4),
      decoration: BoxDecoration(
        color: fond,
        // Le chapeau passe du fond de son ton vers une pointe de magenta : il se
        // lit comme une surface éclairée, et non plus comme un aplat.
        gradient: grave
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  fond,
                  Color.alphaBlend(
                    couleurs.primaryContainer.withValues(alpha: 0.9),
                    fond,
                  ),
                ],
              ),
        borderRadius: BorderRadius.circular(Marque.rayonDeContenant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️ L'ICÔNE SUR LA MÊME LIGNE QUE LE TITRE, ET LE TITRE D'UN CRAN
          // PLUS BAS DANS L'ÉCHELLE.
          //
          // Vu sur l'appareil : l'icône seule sur sa ligne, puis « 6 périodes
          // en retard » en 23 points, occupaient le tiers de l'écran avant la
          // première échéance. Le chapeau annonce, il ne doit pas pousser dehors
          // ce qu'il annonce. Sur une ligne, il tient en deux fois moins de haut
          // et se lit d'un seul regard.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icone != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icone, color: encre, size: 21),
                ),
                const SizedBox(width: Marque.espace2),
              ],
              Expanded(
                child: Text(
                  titre,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: encre),
                ),
              ),
            ],
          ),
          const SizedBox(height: Marque.espace1),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              // 85 % : le détail passe au second plan sans cesser d'être
              // lisible. Sur l'indigo 100, cela donne encore 7,9:1.
              color: encre.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
          if (dessous != null) ...[
            const SizedBox(height: Marque.espace3),
            dessous!,
          ],
        ],
      ),
    );
  }
}
