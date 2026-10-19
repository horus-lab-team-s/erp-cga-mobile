import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Le dernier numéro mobile money employé, gardé sur ce téléphone (19 octobre 2026).
///
/// ⚠️ Un numéro de téléphone, pas un secret : il ne débite rien sans le code que
/// l'adhérent compose chez son opérateur. Le retaper à chaque paiement, sur un clavier
/// de téléphone, était la seule difficulté du geste.
///
/// Toute panne (pas de dossier, test sans plateforme) se tait : on retape, c'est tout.
class NumeroMemorise {
  static Future<File> _fichier() async => File(
    '${(await getApplicationDocumentsDirectory()).path}/numero-mobile-money',
  );

  static Future<String?> lire() async {
    try {
      final fichier = await _fichier();
      if (!await fichier.exists()) return null;
      final numero = (await fichier.readAsString()).trim();
      return numero.isEmpty ? null : numero;
    } on Object {
      return null;
    }
  }

  static Future<void> retenir(String numero) async {
    try {
      await (await _fichier()).writeAsString(numero);
    } on Object {
      // Rien : la prochaine fois, il se retapera.
    }
  }
}
