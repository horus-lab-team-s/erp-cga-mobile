import 'dart:convert';
import 'dart:io';

import '../ports/memoire_des_dossiers.dart';

/// Un fichier JSON à côté de la file, dans le dossier des documents de l'application.
class MemoireDesDossiersFichier implements MemoireDesDossiers {
  MemoireDesDossiersFichier(Directory dossier)
    : _fichier = File('${dossier.path}/dossiers-connus.json');

  final File _fichier;

  @override
  Future<List<String>?> lire() async {
    try {
      if (!await _fichier.exists()) return null;
      final json = jsonDecode(await _fichier.readAsString());
      return json is List ? [for (final d in json) d as String] : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> retenir(List<String> dossiers) async {
    try {
      await _fichier.writeAsString(jsonEncode(dossiers));
    } on Object {
      // Une mémoire qui n'écrit pas ne doit rien empêcher : elle ne sert qu'hors ligne.
    }
  }
}
