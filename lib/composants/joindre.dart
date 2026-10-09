import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouvre WhatsApp, le téléphone ou la messagerie — et ne laisse jamais un appui
/// sans suite.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ SI L'OUVERTURE ÉCHOUE, LE NUMÉRO EST COPIÉ ET ON LE DIT.
///
/// Un téléphone sans WhatsApp, une tablette sans ligne, un lien refusé par le
/// système : dans tous ces cas `launchUrl` rend faux. Ne rien faire laisserait
/// l'adhérent devant un bouton mort, sur l'écran même qui lui promet qu'on peut
/// le joindre. On copie donc la coordonnée dans le presse-papier, et un message
/// dit où elle est.
/// ─────────────────────────────────────────────────────────────────────────────
Future<void> joindre(
  BuildContext context,
  Uri lien, {
  required String aCopier,
}) async {
  var ouvert = false;
  try {
    ouvert = await launchUrl(lien, mode: LaunchMode.externalApplication);
  } on Object {
    ouvert = false;
  }
  if (ouvert || !context.mounted) return;
  await Clipboard.setData(ClipboardData(text: aCopier));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        "Ce téléphone n'a pas pu l'ouvrir. $aCopier est copié : "
        'collez-le où vous voulez.',
      ),
    ),
  );
}
