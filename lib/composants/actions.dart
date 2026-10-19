import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../marque.dart';

/// Ce que les écrans de l'espace partagent pour traiter une action (18 octobre 2026).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE LE CABINET A DEMANDÉ : « une belle expérience utilisateur pour le
/// traitement des actions ». Un geste, sur un téléphone d'entrée de gamme et un
/// réseau qu'on sait mauvais, doit toujours dire trois choses :
///
/// * qu'il a été pris (le bouton s'occupe aussitôt, un retour au doigt) ;
/// * qu'il est en cours (une roue DANS le bouton, et le bouton ne se redouble pas) ;
/// * comment il a fini, en clair, et quoi faire ensuite (`annoncer`).
///
/// ⚠️ Jamais « Erreur 409 » : le serveur écrit ses refus pour l'adhérent, et
/// l'écran les montre tels quels quand il en a un.
/// ─────────────────────────────────────────────────────────────────────────────

const _moisEnFrancais = [
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

String nomDuMois(int mois) => _moisEnFrancais[mois - 1];

/// « 12 août 2026 ».
String jourLong(DateTime d) =>
    '${d.day == 1 ? '1er' : d.day} ${nomDuMois(d.month)} ${d.year}';

/// « août 2026 ».
String moisEtAnnee(DateTime d) => '${nomDuMois(d.month)} ${d.year}';

/// « 1 340 000 F » : tranches de trois, séparées par une espace insécable fine.
String montantFcfa(int v) {
  final signe = v < 0 ? '−' : '';
  final entier = v.abs().toString();
  final tranches = <String>[];
  for (var fin = entier.length; fin > 0; fin -= 3) {
    tranches.insert(0, entier.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
  }
  return '$signe${tranches.join(' ')} F';
}

/// Le retour d'une action, en bas de l'écran, au-dessus de la barre.
void annoncer(BuildContext context, String texte, {bool echec = false}) {
  if (echec) {
    HapticFeedback.heavyImpact();
  } else {
    HapticFeedback.lightImpact();
  }
  final couleurs = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          Marque.espaceSousLaBarreDe(context) - 8,
        ),
        backgroundColor: echec
            ? couleurs.errorContainer
            : couleurs.inverseSurface,
        content: Row(
          children: [
            Icon(
              echec ? Icons.error_outline : Icons.check_circle_outline,
              color: echec
                  ? couleurs.onErrorContainer
                  : couleurs.onInverseSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texte,
                style: TextStyle(
                  color: echec
                      ? couleurs.onErrorContainer
                      : couleurs.onInverseSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

/// Un bouton qui s'occupe : la roue prend la place de l'icône, et il ne se
/// redouble pas pendant l'envoi.
class BoutonDAction extends StatelessWidget {
  const BoutonDAction({
    super.key,
    required this.libelle,
    required this.icone,
    required this.surAppui,
    this.enCours = false,
    this.libelleEnCours,
    this.secondaire = false,
    this.tonal = false,
  });

  final String libelle;
  final IconData icone;
  final VoidCallback? surAppui;
  final bool enCours;
  final String? libelleEnCours;

  /// Un geste d'appoint : contour, et non aplat.
  final bool secondaire;

  /// Un geste répété dans une liste : un aplat doux, pour qu'une page de sept
  /// pièces ne soit pas un mur de boutons vifs.
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final icon = enCours
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          )
        : Icon(icone, size: 20);
    final label = Text(enCours ? (libelleEnCours ?? libelle) : libelle);
    final appui = enCours || surAppui == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            surAppui!();
          };
    if (secondaire) {
      return OutlinedButton.icon(onPressed: appui, icon: icon, label: label);
    }
    if (tonal) {
      return FilledButton.tonalIcon(onPressed: appui, icon: icon, label: label);
    }
    return FilledButton.icon(onPressed: appui, icon: icon, label: label);
  }
}

/// Une page sans contenu à montrer : dire pourquoi, et ce qu'on peut faire.
class EtatVide extends StatelessWidget {
  const EtatVide({
    super.key,
    required this.titre,
    required this.detail,
    required this.icone,
    this.action,
  });

  final String titre;
  final String detail;
  final IconData icone;

  /// « Réessayer », le plus souvent.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    // ⚠️ Un `ListView`, et non une colonne : le geste « tirer pour relire »
    // doit marcher aussi sur une page vide, c'est précisément là qu'on l'essaie.
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: couleurs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 34, color: couleurs.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          titre,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: couleurs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 20),
          Center(child: action),
        ],
      ],
    );
  }
}

/// Une pastille d'état : la couleur souligne, le texte porte l'information.
class Pastille extends StatelessWidget {
  const Pastille(this.texte, {super.key, this.ton = TonDePastille.neutre});

  final String texte;
  final TonDePastille ton;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final (fond, encre) = switch (ton) {
      TonDePastille.neutre => (
        couleurs.surfaceContainerHighest,
        couleurs.onSurfaceVariant,
      ),
      TonDePastille.attente => (
        couleurs.primaryContainer,
        couleurs.onPrimaryContainer,
      ),
      TonDePastille.reussite => (Marque.reussite100, Marque.reussite),
      TonDePastille.alerte => (
        couleurs.errorContainer,
        couleurs.onErrorContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(Marque.rayonPastille),
      ),
      child: Text(
        texte,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: encre,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum TonDePastille { neutre, attente, reussite, alerte }

/// Une feuille du bas, avec sa poignée et ses marges : le cadre des confirmations.
Future<T?> ouvrirUneFeuille<T>(
  BuildContext context, {
  required WidgetBuilder construire,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (contexte) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(contexte).bottom,
      ),
      child: construire(contexte),
    ),
  );
}

/// Demande confirmation avant de fermer la session (19 octobre 2026).
///
/// ⚠️ Un seul texte, le même partout : l'accueil et l'onglet de dépôt
/// déconnectaient d'un seul appui, à côté d'icônes qu'on touche souvent. En 3G,
/// se reconnecter coûte, et les pièces en attente inquiètent.
Future<bool> confirmerLaDeconnexion(BuildContext context) async {
  final oui = await showDialog<bool>(
    context: context,
    builder: (contexte) => AlertDialog(
      title: const Text('Se déconnecter ?'),
      content: const Text(
        'Les pièces qui attendent encore de partir restent sur ce téléphone : '
        'elles partiront à votre prochaine connexion.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexte).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('confirmer-deconnexion'),
          onPressed: () => Navigator.of(contexte).pop(true),
          child: const Text('Se déconnecter'),
        ),
      ],
    ),
  );
  return oui == true;
}
