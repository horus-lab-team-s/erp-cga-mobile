import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../ports/coffre_de_session.dart';

/// Le Keystore d'Android (le trousseau sur iOS), par `flutter_secure_storage`.
class CoffreDuSysteme implements CoffreDeSession {
  CoffreDuSysteme({FlutterSecureStorage? coffre})
    : _coffre = coffre ?? const FlutterSecureStorage();

  static const _cle = 'cga.session';
  final FlutterSecureStorage _coffre;

  @override
  Future<String?> lire() async {
    try {
      return await _coffre.read(key: _cle);
    } on Object {
      // Un coffre illisible (appareil restauré, clé perdue) : on se reconnecte.
      return null;
    }
  }

  @override
  Future<void> ecrire(String session) async {
    try {
      await _coffre.write(key: _cle, value: session);
    } on Object {
      // Sans coffre, la session reste en mémoire : on se reconnectera demain.
    }
  }

  @override
  Future<void> effacer() async {
    try {
      await _coffre.delete(key: _cle);
    } on Object {
      // Rien à faire : le serveur l'expirera de lui-même.
    }
  }
}
