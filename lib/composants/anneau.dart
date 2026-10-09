import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../marque.dart';

/// Un anneau de progression : où en est le mois, d'un seul regard.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// POURQUOI UN DESSIN PLUTÔT QU'UNE PHRASE
///
/// « Il manque 3 justificatifs » dit ce qui manque, jamais où l'on en est. Deux
/// pièces reçues sur cinq attendues et huit sur dix donnent la même phrase, et
/// ce ne sont pas les mêmes mois. L'anneau montre la part faite ; la phrase
/// reste à côté et dit quoi faire.
///
/// ⚠️ LE CHIFFRE EST ÉCRIT DEDANS, ET LES DEUX NOMBRES À CÔTÉ.
///
/// Un anneau seul se lit « à peu près à moitié ». Un adhérent qui prépare son
/// mois a besoin du compte exact : « 2 sur 5 ». Le dessin donne l'allure, les
/// mots donnent la mesure — et un lecteur d'écran, qui ne voit pas l'anneau,
/// reçoit la même information par l'étiquette de sémantique.
///
/// ⚠️ ET IL NE SE PEINT PAS EN ROUGE. La couleur dit l'ÉTAT du mois, décidé par
/// l'appelant : le retard est déjà écrit en toutes lettres au-dessus. Un anneau
/// rouge sur un mois simplement commencé ferait paniquer pour rien.
/// ─────────────────────────────────────────────────────────────────────────────
class AnneauDeProgression extends StatelessWidget {
  const AnneauDeProgression({
    super.key,
    required this.fait,
    required this.total,
    required this.teinte,
    this.diametre = 76,
    this.libelle,
  });

  /// Ce qui est fait — les pièces reçues par le cabinet.
  final int fait;

  /// Ce qui est attendu en tout. ⚠️ Zéro est un cas réel : un mois sans rien à
  /// fournir. L'anneau se peint alors plein, et non vide.
  final int total;

  final Color teinte;
  final double diametre;

  /// Ce qu'on annonce à un lecteur d'écran. À défaut, « 2 sur 5 ».
  final String? libelle;

  double get _part => total <= 0 ? 1 : (fait / total).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Semantics(
      label: libelle ?? '$fait sur $total',
      excludeSemantics: true,
      child: SizedBox(
        width: diametre,
        height: diametre,
        child: CustomPaint(
          painter: _PeintreDAnneau(
            part: _part,
            teinte: teinte,
            piste: couleurs.outlineVariant,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$fait',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: teinte, height: 1),
                ),
                Text(
                  'sur $total',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: couleurs.onSurfaceVariant,
                    height: 1.2,
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

class _PeintreDAnneau extends CustomPainter {
  _PeintreDAnneau({
    required this.part,
    required this.teinte,
    required this.piste,
  });

  final double part;
  final Color teinte;
  final Color piste;

  @override
  void paint(Canvas toile, Size taille) {
    // ⚠️ Un trait épais aux extrémités ARRONDIES : coupé net, l'anneau donne une
    // impression de cadran de machine. Arrondi, il se lit comme une jauge.
    const epaisseur = 7.0;
    final centre = Offset(taille.width / 2, taille.height / 2);
    final rayon = (math.min(taille.width, taille.height) - epaisseur) / 2;
    final fond = Paint()
      ..color = piste
      ..strokeWidth = epaisseur
      ..style = PaintingStyle.stroke;
    toile.drawCircle(centre, rayon, fond);
    if (part <= 0) return;
    final trait = Paint()
      ..color = teinte
      ..strokeWidth = epaisseur
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    toile.drawArc(
      Rect.fromCircle(center: centre, radius: rayon),
      // Le zéro est EN HAUT, comme une horloge : commencer à trois heures, le
      // défaut du moteur, fait lire la progression de travers.
      -math.pi / 2,
      2 * math.pi * part,
      false,
      trait,
    );
  }

  @override
  bool shouldRepaint(_PeintreDAnneau ancien) =>
      ancien.part != part || ancien.teinte != teinte || ancien.piste != piste;
}

/// Une barre segmentée : ce qui est en retard, ce qui reste à venir.
///
/// ⚠️ DEUX SEGMENTS, PAS UN CAMEMBERT. Sur un téléphone, une barre pleine
/// largeur se lit au passage ; un disque demande qu'on s'arrête dessus. Et les
/// deux nombres sont écrits dessous : la couleur ne porte jamais seule
/// l'information.
class BarreDeuxParts extends StatelessWidget {
  const BarreDeuxParts({
    super.key,
    required this.premier,
    required this.second,
    required this.teintePremier,
    required this.teinteSecond,
  });

  final int premier;
  final int second;
  final Color teintePremier;
  final Color teinteSecond;

  @override
  Widget build(BuildContext context) {
    final total = premier + second;
    if (total == 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(Marque.rayonPastille),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (premier > 0)
              Expanded(
                flex: premier,
                child: ColoredBox(color: teintePremier),
              ),
            if (second > 0)
              Expanded(
                flex: second,
                child: ColoredBox(color: teinteSecond),
              ),
          ],
        ),
      ),
    );
  }
}
