import 'dart:io';

import 'package:cga_mobile/adaptateurs/magasin_fichier.dart';
import 'package:cga_mobile/api/client_api.dart';
import 'package:cga_mobile/api/remise.dart';
import 'package:cga_mobile/domaine/depot.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';

/// Joue une remise complète contre un serveur qui tourne vraiment.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// POURQUOI CET OUTIL EXISTE
///
/// Les cas d'essai éprouvent la règle de renvoi, et ils la tiennent. Ils ne
/// touchent jamais au réseau : ils ne peuvent donc pas dire si l'enveloppe
/// multipart écrite à la main dans `client_api.dart` est correcte.
///
/// ⚠️ Et c'est précisément là que ça se joue. Un `\r\n` manquant avant la ligne
/// de séparation finale fait lire au serveur deux octets de trop dans le
/// fichier. L'empreinte change alors À CHAQUE ENVOI, l'idempotence disparaît
/// sans le moindre message, et la même facture entre deux fois dans la
/// comptabilité de l'adhérent. Aucun test hors ligne ne verra cela, et aucun
/// écran non plus : les deux dépôts ont l'air normaux.
///
/// Cet outil envoie donc le même fichier deux fois et vérifie que le serveur
/// répond « rejeu » la seconde. C'est la seule preuve qui vaille.
///
///     outils/pile-de-demonstration.sh neuve     # dans erp-cga-backend
///     dart run outils/remise_reelle.dart
/// ─────────────────────────────────────────────────────────────────────────────

const String adresse = String.fromEnvironment(
  'CGA_API',
  defaultValue: 'http://127.0.0.1:8010',
);
const String courriel = String.fromEnvironment(
  'CGA_COURRIEL',
  defaultValue: 'jp.nkoa@batimentplus.cm',
);
const String motDePasse = String.fromEnvironment(
  'CGA_MOT_DE_PASSE',
  defaultValue: 'cabinet brcg douala 2026',
);
const String dossier = String.fromEnvironment(
  'CGA_DOSSIER',
  defaultValue: 'M081234567890P',
);

void dire(String texte) => stdout.writeln(texte);

Future<File> _photoDeFacture(Directory ou) async {
  // Une vraie image JPEG : le serveur décide du type en lisant les octets, il
  // ne croit pas l'extension. Les octets sont tirés au hasard pour que chaque
  // exécution produise une empreinte neuve et n'atterrisse pas sur un rejeu de
  // la précédente.
  final fichier = File('${ou.path}/facture.jpg');
  final alea = File('/dev/urandom').openSync();
  final corps = alea.readSync(600);
  alea.closeSync();
  await fichier.writeAsBytes([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, // en-tête JFIF
    ...'JFIF'.codeUnits, 0x00, 0x01, 0x01, 0x00,
    0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
    ...corps,
    0xFF, 0xD9, // fin d'image
  ]);
  return fichier;
}

Future<int> main() async {
  final travail = await Directory.systemTemp.createTemp('cga-remise-');
  final client = ClientApi(base: Uri.parse(adresse));
  var fautes = 0;

  void verifier(String quoi, bool vrai, [String detail = '']) {
    dire('${vrai ? "  ✓" : "  ✗"} $quoi${detail.isEmpty ? "" : " · $detail"}');
    if (!vrai) fautes++;
  }

  try {
    dire('Serveur : $adresse');
    final ouverte = await client.ouvrirUneSession(courriel, motDePasse);
    verifier('session ouverte', ouverte, courriel);
    if (!ouverte) return 1;

    final photo = await _photoDeFacture(travail);
    final file = FileDAttente(MagasinDeFichier(travail));
    final remise = Remise(client);
    final depot = Depot(
      identifiant: 'D-${DateTime.now().microsecondsSinceEpoch}',
      dossier: dossier,
      cheminDuFichier: photo.path,
      prisLe: DateTime.now(),
    );
    await file.ajouter(depot);

    dire('\nPremier envoi');
    final premier = await file.vider(remise.remettre);
    verifier(
      'la pièce est partie',
      premier.remis == 1,
      '${premier.remis} remis',
    );
    verifier('la file est vide', (await file.enAttente()).isEmpty);
    verifier('aucune pièce à reprendre', (await file.refuses()).isEmpty);

    dire('\nRejeu : la même pièce, comme après une réponse perdue en route');
    await file.ajouter(depot);
    final second = await file.vider(remise.remettre);
    verifier(
      'le serveur accepte le rejeu',
      second.remis == 1,
      'sans quoi une réponse perdue perdrait la pièce',
    );
    verifier('rien à reprendre', (await file.refuses()).isEmpty);

    dire('\nSession fermée : ce qui doit arriver à la file');
    await client.fermerLaSession();
    final orphelin = Depot(
      identifiant: 'D-orphelin',
      dossier: dossier,
      cheminDuFichier: photo.path,
      prisLe: DateTime.now(),
    );
    await file.ajouter(orphelin);
    final apres = await file.vider(remise.remettre);
    verifier('la file s\'arrête', apres.remis == 0);
    verifier('et dit qu\'il faut se reconnecter', apres.sessionAExpire);
    final reste = await file.enAttente();
    verifier('la pièce reste en attente', reste.length == 1);
    verifier(
      'sans tentative comptée',
      reste.isNotEmpty && reste.single.tentatives == 0,
      'sinon six ouvertures suffisaient à la condamner',
    );
    verifier(
      'et elle n\'est pas déclarée refusée',
      (await file.refuses()).isEmpty,
    );
  } finally {
    client.fermer();
    await travail.delete(recursive: true);
  }

  dire('');
  dire(
    fautes == 0
        ? 'REMISE RÉELLE : tout tient.'
        : 'REMISE RÉELLE : $fautes écart(s).',
  );
  return fautes == 0 ? 0 : 1;
}
