import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../marque.dart';
import 'actions.dart';

/// Ce que les écrans de l'espace disent quand la lecture n'a pas abouti, ou quand
/// elle date (20 octobre 2026).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ UN SEUL COMPOSANT, ET NON SEPT `_RienDuTout`.
///
/// Chaque écran avait le sien : une icône, deux phrases, et, selon l'écran, un
/// bouton « Réessayer » ou rien du tout. Sur l'historique, l'adhérent sans réseau
/// devait deviner qu'il fallait tirer vers le bas. Le même cas se dit maintenant
/// de la même façon partout, avec le même bouton.
///
/// ⚠️ ET DEUX PANNES, PAS UNE. « Pas de réseau » se règle chez l'adhérent ; « le
/// cabinet ne répond pas » non. Les confondre faisait vérifier sa 4G à quelqu'un
/// dont le téléphone marchait très bien.
/// ─────────────────────────────────────────────────────────────────────────────

/// « il y a 2 h » : l'âge d'une lecture, dit comme on le dirait.
///
/// ⚠️ Jamais d'heure exacte (« lu à 14 h 32 ») : l'adhérent doit faire le calcul,
/// et la seule question qu'il se pose est « est-ce que c'est récent ? ».
String ilYA(DateTime instant, {DateTime? maintenant}) {
  final ecart = (maintenant ?? clock.now()).difference(instant);
  if (ecart.inMinutes < 1) return 'à l\'instant';
  if (ecart.inMinutes < 60) return 'il y a ${ecart.inMinutes} min';
  if (ecart.inHours < 24) return 'il y a ${ecart.inHours} h';
  if (ecart.inDays == 1) return 'hier';
  return 'il y a ${ecart.inDays} jours';
}

/// Le bandeau d'une page qui montre la dernière lecture gardée, faute de réseau.
///
/// ⚠️ UNE COPIE NE S'AFFICHE JAMAIS SANS SA DATE. Des échéances d'hier présentées
/// comme celles du jour diraient « rien en retard » le lendemain d'une date limite.
class BandeauHorsLigne extends StatelessWidget {
  const BandeauHorsLigne({
    super.key = const Key('bandeau-hors-ligne'),
    required this.copieDu,
    this.serveurEnPanne = false,
  });

  final DateTime copieDu;
  final bool serveurEnPanne;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final quoi = serveurEnPanne ? 'Le cabinet ne répond pas' : 'Hors ligne';
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Marque.espace3,
          vertical: Marque.espace2 + 2,
        ),
        decoration: BoxDecoration(
          color: couleurs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Marque.rayonBloc + 4),
        ),
        child: Row(
          children: [
            Icon(
              serveurEnPanne
                  ? Icons.cloud_off_outlined
                  : Icons.wifi_off_rounded,
              size: 20,
              color: couleurs.onSurfaceVariant,
            ),
            const SizedBox(width: Marque.espace2 + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$quoi · mis à jour ${ilYA(copieDu)}',
                    style: texte.labelLarge?.copyWith(
                      color: couleurs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Ce que vous voyez est la dernière lecture. Tirez vers le bas '
                    'pour actualiser.',
                    style: texte.bodySmall?.copyWith(
                      color: couleurs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La page d'une lecture qui n'a pas abouti, avec « Réessayer ».
class EtatDePanne extends StatelessWidget {
  const EtatDePanne({
    super.key,
    required this.serveurEnPanne,
    required this.reessayer,
    this.horsLigne,
  });

  /// Le serveur n'a pas répondu comme il faut, alors que le réseau marche.
  final bool serveurEnPanne;

  final Future<void> Function() reessayer;

  /// Ce que l'écran dit quand le RÉSEAU manque : « Vos échéances se lisent sur le
  /// serveur… ». `null` : la phrase commune.
  final String? horsLigne;

  @override
  Widget build(BuildContext context) {
    return EtatVide(
      key: Key(
        serveurEnPanne ? 'etat-serveur-indisponible' : 'etat-sans-reseau',
      ),
      titre: serveurEnPanne ? 'Le cabinet ne répond pas' : 'Pas de réseau',
      detail: serveurEnPanne
          ? 'Votre connexion fonctionne, mais le serveur du cabinet est '
                'momentanément indisponible. Réessayez dans quelques minutes.'
          : horsLigne ??
                'Vérifiez vos données mobiles ou votre Wi-Fi, puis réessayez.',
      icone: serveurEnPanne
          ? Icons.cloud_off_outlined
          : Icons.wifi_off_outlined,
      action: FilledButton.tonalIcon(
        key: const Key('reessayer'),
        onPressed: reessayer,
        icon: const Icon(Icons.refresh),
        label: const Text('Réessayer'),
      ),
    );
  }
}

/// Des formes grises qui pulsent, à la place d'une roue, le temps de la première
/// lecture.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI PAS LA ROUE : ELLE NE DIT RIEN DE CE QUI VIENT.
///
/// En 3G, la roue tournait trois secondes au milieu d'une page blanche, puis la
/// page entière sautait en place. Le squelette dessine la page qui vient — un
/// chapeau, des cartes —, et la lecture qui arrive se pose dessus sans que l'œil
/// perde sa place.
///
/// ⚠️ Une pulsation lente, et rien quand le système demande moins d'animations.
/// ─────────────────────────────────────────────────────────────────────────────
class Squelette extends StatefulWidget {
  const Squelette({
    super.key,
    this.chapeau = true,
    this.cartes = 3,
    this.hauteurDeCarte = 96,
    this.marge,
    this.defile = true,
  });

  /// Faux : une simple colonne, pour une page qui défile déjà (l'accueil).
  final bool defile;

  /// Le premier bloc, plus haut : le chapeau ou le bandeau du mois.
  final bool chapeau;
  final int cartes;
  final double hauteurDeCarte;
  final EdgeInsetsGeometry? marge;

  @override
  State<Squelette> createState() => _EtatDuSquelette();
}

class _EtatDuSquelette extends State<Squelette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulsation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulsation.value = 0.5;
      _pulsation.stop();
    } else if (!_pulsation.isAnimating) {
      _pulsation.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulsation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    Widget forme(double hauteur, {double largeur = double.infinity}) =>
        Container(
          width: largeur,
          height: hauteur,
          decoration: BoxDecoration(
            color: couleurs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Marque.rayonDeContenant),
          ),
        );
    return Semantics(
      label: 'Chargement',
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1).animate(_pulsation),
          child: _disposer(
            marge: widget.marge ?? const EdgeInsets.all(Marque.espace4),
            children: [
              if (widget.chapeau) ...[
                forme(104),
                const SizedBox(height: Marque.espace6),
              ],
              forme(14, largeur: 140),
              const SizedBox(height: Marque.espace3),
              for (var i = 0; i < widget.cartes; i++) ...[
                forme(widget.hauteurDeCarte),
                const SizedBox(height: Marque.espace3),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _disposer({
    required EdgeInsetsGeometry marge,
    required List<Widget> children,
  }) => widget.defile
      ? ListView(
          key: const Key('squelette'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: marge,
          children: children,
        )
      : Padding(
          key: const Key('squelette'),
          padding: marge,
          child: Column(children: children),
        );
}
