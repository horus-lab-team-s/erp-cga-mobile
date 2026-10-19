import 'package:flutter/material.dart';

import '../marque.dart';
import 'actions.dart';

/// Le choix de l'entreprise, pour un adhérent qui en a plusieurs (20 octobre 2026).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ UN SEUL CHOIX, QUI VAUT POUR TOUTE L'APPLICATION.
///
/// Chaque écran avait son sélecteur — une icône de dossier dans sa barre, quand il
/// y pensait — et l'accueil, la DSF et la paie prenaient d'office le PREMIER
/// dossier. Un adhérent à deux entreprises choisissait la seconde sur les
/// échéances, ouvrait sa paie, et lisait celle de la première sans que rien ne le
/// dise. Le choix se fait désormais une fois, dans l'en-tête de l'accueil ou de
/// « Mon espace », par le NOM de l'entreprise, et tous les écrans le suivent.
///
/// ⚠️ LE NOM, ET NON LE NIU, dès qu'on le connaît : « M081234567890P » ne dit rien à
/// celui qui tient deux boutiques. Le serveur ne rend pour l'instant que les NIU
/// des dossiers ; le nom s'apprend à la lecture de chacun, et le NIU le remplace
/// en attendant.
/// ─────────────────────────────────────────────────────────────────────────────
Future<String?> choisirUnDossier(
  BuildContext context, {
  required List<String> dossiers,
  required String choisi,
  Map<String, String> noms = const {},
}) => ouvrirUneFeuille<String>(
  context,
  construire: (contexte) {
    final theme = Theme.of(contexte);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Quelle entreprise ?', style: theme.textTheme.titleLarge),
        const SizedBox(height: Marque.espace1),
        Text(
          'Tous les écrans suivront ce choix : accueil, échéances, documents, '
          'paie et DSF.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Marque.espace3),
        for (final d in dossiers)
          ListTile(
            key: Key('dossier-$d'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              d == choisi ? Icons.radio_button_checked : Icons.radio_button_off,
              color: d == choisi
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(noms[d]?.isNotEmpty == true ? noms[d]! : d),
            subtitle: noms[d]?.isNotEmpty == true ? Text('NIU $d') : null,
            selected: d == choisi,
            onTap: () => Navigator.of(contexte).pop(d),
          ),
      ],
    );
  },
);

/// La ligne qui nomme l'entreprise en cours et ouvre le choix, quand il y en a un.
///
/// ⚠️ Sans choix possible (un seul dossier, presque tous les adhérents), elle se
/// contente de nommer : un bouton qui n'ouvre rien apprend à toucher pour rien.
class EntrepriseEnCours extends StatelessWidget {
  const EntrepriseEnCours({
    super.key,
    required this.dossier,
    required this.dossiers,
    required this.noms,
    required this.choisir,
    this.couleur,
    this.style,
  });

  final String dossier;
  final List<String> dossiers;
  final Map<String, String> noms;
  final ValueChanged<String>? choisir;

  /// L'encre du texte : blanc sur l'en-tête de l'accueil, celle du thème ailleurs.
  final Color? couleur;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final nom = noms[dossier] ?? '';
    final texte = nom.isEmpty ? dossier : '$nom · $dossier';
    final encre = couleur ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final ligne = Text(
      texte,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: (style ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
        color: encre,
      ),
    );
    if (dossiers.length < 2 || choisir == null) return ligne;
    return Semantics(
      button: true,
      label: 'Changer d\'entreprise. Entreprise en cours : $texte',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('choix-dossier'),
        borderRadius: BorderRadius.circular(Marque.rayonBloc),
        onTap: () async {
          final choix = await choisirUnDossier(
            context,
            dossiers: dossiers,
            choisi: dossier,
            noms: noms,
          );
          if (choix != null && choix != dossier) choisir!(choix);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Marque.espace1),
          child: Row(
            children: [
              Flexible(child: ligne),
              const SizedBox(width: Marque.espace1),
              Icon(Icons.expand_more_rounded, size: 20, color: encre),
            ],
          ),
        ),
      ),
    );
  }
}
