import 'package:flutter/material.dart';

import '../domaine/prise_de_vue.dart';
import 'actions.dart';

/// D'où vient l'image d'une pièce : l'appareil photo, ou la galerie (18 octobre 2026).
///
/// ⚠️ SANS GALERIE BRANCHÉE, AUCUNE QUESTION. Une question dont la réponse est
/// forcée est une étape de plus entre la pièce en main et la photo prise :
/// l'appareil photo s'ouvre directement, comme avant.
///
/// Rend le chemin de la copie durable, ou `null` si l'adhérent a renoncé.
Future<String?> obtenirUneImage(
  BuildContext context,
  PriseDeVue priseDeVue,
) async {
  if (priseDeVue.galerie == null) {
    return priseDeVue.copieDurable();
  }
  final depuisLaGalerie = await ouvrirUneFeuille<bool>(
    context,
    construire: (contexte) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Envoyer une image',
          style: Theme.of(contexte).textTheme.titleMedium,
        ),
        const SizedBox(height: 14),
        BoutonDAction(
          key: const Key('source-appareil'),
          libelle: 'Photographier',
          icone: Icons.photo_camera_outlined,
          surAppui: () => Navigator.of(contexte).pop(false),
        ),
        const SizedBox(height: 10),
        BoutonDAction(
          key: const Key('source-galerie'),
          libelle: 'Choisir dans la galerie',
          icone: Icons.photo_library_outlined,
          secondaire: true,
          surAppui: () => Navigator.of(contexte).pop(true),
        ),
      ],
    ),
  );
  if (depuisLaGalerie == null) return null;
  return priseDeVue.copieDurable(depuisLaGalerie: depuisLaGalerie);
}
