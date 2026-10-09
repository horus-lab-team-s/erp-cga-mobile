import 'package:flutter/material.dart';

import '../../contenu/cabinet.dart';
import '../../contenu/vitrine.dart';
import '../../marque.dart';

/// Le bandeau d'accueil : la ville, la promesse, l'accès au compte.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ UNE PHOTO DE DOUALA, ET UN VOILE À 75 %, CALCULÉ.
///
/// Le texte blanc est posé SUR la photo, cette fois. Pour qu'il tienne 4,5:1
/// sur la zone la plus claire — le ciel, une façade blanche —, il faut au
/// moins 70 % d'indigo ; à 75 %, le titre donne 6,84:1 et le texte secondaire
/// (82 % de blanc) 5,24:1. Une rue n'a pas de visages à éteindre : assombrie,
/// elle se lit encore comme une ville, et c'est tout ce qu'on lui demande.
///
/// La connexion a fait le choix inverse — aucun texte sur la photo — parce que
/// sa photo montre des personnes.
/// ─────────────────────────────────────────────────────────────────────────────

const _styleKicker = TextStyle(
  color: Colors.white,
  fontSize: 12.5,
  height: 1.35,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.4,
);

const _styleTitre = TextStyle(
  color: Colors.white,
  fontSize: 24,
  height: 1.22,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.4,
);

final _styleDetail = TextStyle(
  color: Colors.white.withValues(alpha: 0.82),
  fontSize: 14.5,
  height: 1.5,
);

/// La base de texte du bandeau, commune à la MESURE et au RENDU.
///
/// ⚠️ SANS ELLE, LA MESURE MENTAIT. Un `Text` fusionne son style avec celui
/// que lui transmettent ses parents ; dans une barre d'application, ce style
/// par défaut porte un espacement de lettres de 0,25. La mesure, elle, partait
/// d'un style nu, sans espacement. La promesse tenait donc sur deux lignes à la
/// mesure et sur trois au rendu : 22 points de débordement, les rayures jaunes
/// et noires en travers de la photo.
///
/// Le bandeau pose donc SA base, et la mesure part de la même.
TextStyle _base(BuildContext context) => TextStyle(
  fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
  letterSpacing: 0,
  wordSpacing: 0,
);

/// Les marges du bandeau, déclarées une fois : la hauteur se calcule avec.
const _margeHaut = 10.0;
const _ecartKicker = 8.0;
const _ecartTitre = 10.0;
const _margeBasse = 28.0;

/// La hauteur que le bandeau déployé demande VRAIMENT.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ MESURÉE, ET NON RÉSERVÉE AU JUGÉ. La hauteur dépend de la largeur de
/// l'appareil, de la police servie et de l'agrandissement du texte réglé par
/// l'utilisateur : un adhérent en gros caractères fait passer le titre de deux
/// lignes à quatre. On met donc les trois textes en page avec le moteur qui
/// les dessinera.
///
/// ⚠️ ET LA BARRE D'ÉTAT N'EST PAS COMPTÉE : `SliverAppBar` l'ajoute lui-même
/// (`maxExtent = topPadding + expandedHeight`). La compter ici laissait
/// quarante-quatre points d'indigo vide sous le texte — vu sur le téléphone,
/// invisible en test.
/// ─────────────────────────────────────────────────────────────────────────────
double hauteurDuBandeau(BuildContext context) {
  final media = MediaQuery.of(context);
  final largeur = media.size.width - 40;
  final base = _base(context);

  double mesurer(String texte, TextStyle style, int maxLignes) {
    final peintre = TextPainter(
      text: TextSpan(text: texte, style: base.merge(style)),
      textDirection: TextDirection.ltr,
      maxLines: maxLignes,
      textScaler: media.textScaler,
    )..layout(maxWidth: largeur);
    return peintre.height;
  }

  return kToolbarHeight +
      _margeHaut +
      mesurer(Promesse.kicker.toUpperCase(), _styleKicker, 2) +
      _ecartKicker +
      mesurer(Promesse.titre, _styleTitre, 3) +
      _ecartTitre +
      mesurer(Promesse.detail, _styleDetail, 3) +
      _margeBasse;
}

/// Le fond du bandeau : la photo, le voile, le texte.
class FondDuBandeau extends StatelessWidget {
  const FondDuBandeau({super.key, required this.hautDeLEcran});

  /// La hauteur de la barre d'état, mesurée par l'écran.
  final double hautDeLEcran;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        'assets/photos/douala.jpg',
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        // Sans la photo, l'aplat indigo du voile reste, opaque : le texte
        // garde alors plus de contraste qu'avec elle.
        errorBuilder: (_, _, _) => const ColoredBox(color: Marque.indigo900),
      ),
      ColoredBox(color: Marque.indigo900.withValues(alpha: 0.75)),
      Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          // La barre d'état, puis la barre d'outils qui porte le logo : le
          // texte commence dessous, sans se glisser derrière.
          hautDeLEcran + kToolbarHeight + _margeHaut,
          20,
          _margeBasse,
        ),
        child: DefaultTextStyle(
          style: _base(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Promesse.kicker.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _styleKicker,
              ),
              const SizedBox(height: _ecartKicker),
              const Text(
                Promesse.titre,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _styleTitre,
              ),
              const SizedBox(height: _ecartTitre),
              Text(
                Promesse.detail,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _styleDetail,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Le logo, dans la barre épinglée.
class LogoDuBandeau extends StatelessWidget {
  const LogoDuBandeau({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
    Marque.logoBlanc,
    height: 30,
    fit: BoxFit.contain,
    alignment: Alignment.centerLeft,
    semanticLabel: Cabinet.nom,
  );
}

/// L'accès au compte, pour qui en a déjà un.
///
/// ⚠️ Un contour, et non un simple texte : sur l'indigo, « Se connecter » sans
/// cadre se lisait comme un titre et non comme un geste. Le contour à 45 % de
/// blanc donne 4,8:1 sur le fond, au-dessus des 3:1 exigés d'un objet
/// graphique.
class BoutonConnexion extends StatelessWidget {
  const BoutonConnexion({super.key, required this.surAppui});
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: const Key('bouton-se-connecter'),
    onPressed: surAppui,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      // ⚠️ 40 de haut et non 48 : la barre d'outils en fait 56, et un bouton
      // de 48 la remplit au point de toucher le logo.
      minimumSize: const Size(0, 40),
      // Un bouton, pas une pastille : l'arrondi des boutons de la console.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Marque.rayonCarte)),
      ),
      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
    ),
    child: const Text('Se connecter'),
  );
}
