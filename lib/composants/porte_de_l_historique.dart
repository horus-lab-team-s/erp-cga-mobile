import 'package:flutter/material.dart';

import '../marque.dart';
import 'carte.dart';

/// La porte de l'historique : tout ce qui est déjà parti.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ UNE CARTE DANS LA PAGE, ET NON UNE TROISIÈME ICÔNE DANS LA BARRE DU HAUT.
///
/// C'est la règle posée à l'ouverture de la coquille : six icônes dans une
/// barre de titre de téléphone ne se distinguent plus, et l'adhérent apprend à
/// ne plus les regarder. Cet écran en porte déjà deux — envoyer, se
/// déconnecter. La troisième aurait été la moins vue des trois, alors qu'elle
/// mène à l'écran le plus consulté après l'accueil.
///
/// ⚠️ ELLE EST DISCRÈTE, ET C'EST VOULU. Le verdict au-dessus répond à la
/// question du jour — mes pièces sont-elles parties. L'historique répond à une
/// question d'après. Lui donner le même poids ferait hésiter entre les deux.
/// ─────────────────────────────────────────────────────────────────────────────
class PorteDeLHistorique extends StatelessWidget {
  const PorteDeLHistorique({super.key, required this.surAppui});

  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return Carte(
      key: const Key('vers-historique'),
      relief: ReliefDeCarte.liste,
      surAppui: surAppui,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: couleurs.primaryContainer,
              borderRadius: BorderRadius.circular(Marque.rayonPastille),
            ),
            child: Icon(
              Icons.history,
              size: 20,
              color: couleurs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: Marque.espace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tout ce que j'ai envoyé",
                  style: texte.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: couleurs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // ⚠️ On annonce la PIÈCE JOINTE, parce que c'est ce que
                  // l'adhérent cherche : non pas une ligne de journal, mais le
                  // document lui-même, celui qu'il retrouvera au contrôle.
                  'Vos pièces remises, leur avancement, et le document de '
                  'chacune.',
                  style: texte.bodySmall?.copyWith(
                    color: couleurs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Marque.espace2),
          Icon(Icons.chevron_right, color: couleurs.onSurfaceVariant),
        ],
      ),
    );
  }
}
