import 'dart:io';

import 'package:cga_mobile/adaptateurs/magasin_fichier.dart';
import 'package:cga_mobile/api/client_api.dart';
import 'package:cga_mobile/api/remise.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:cga_mobile/ports/appareil_photo.dart';

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

/// Ce que l'appareil photo du système rend : un fichier dans un CACHE, que le
/// système peut reprendre à tout moment. On le reproduit fidèlement, parce que
/// c'est de là que vient la règle de recopie qu'on veut éprouver ici.
class AppareilFeint implements AppareilPhoto {
  AppareilFeint(this.cache);

  final Directory cache;

  @override
  Future<String?> photographier() async => (await _photoDeFacture(cache)).path;
}

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

    final dossiers = await client.mesDossiers();
    verifier(
      'le serveur dit quels dossiers sont ouverts',
      dossiers.contains(dossier),
      dossiers.join(', '),
    );

    final cache = await Directory('${travail.path}/cache').create();
    final photos = Directory('${travail.path}/photos');
    final file = FileDAttente(MagasinDeFichier(travail));
    final remise = Remise(client);
    final prise = PriseDeVue(
      appareil: AppareilFeint(cache),
      file: file,
      photos: photos,
    );

    dire('\nPrise de vue');
    final depot = await prise.pour(dossier);
    verifier('la pièce entre dans la file', depot != null);
    if (depot == null) return 1;
    verifier(
      'la copie est hors du cache',
      depot.cheminDuFichier.startsWith(photos.path),
      "sinon le système la reprend et la remise croit à un refus",
    );
    // ⚠️ Ce que le système fait quand la place manque, et qui ne se produit
    // jamais sur un poste de développement.
    await cache.delete(recursive: true);
    verifier(
      'et elle survit au vidage du cache',
      await File(depot.cheminDuFichier).exists(),
    );

    dire('\nPremier envoi');
    final premier = await file.vider(remise.remettre);
    verifier(
      'la pièce est partie',
      premier.remis == 1,
      '${premier.remis} remis',
    );
    verifier('la file est vide', (await file.enAttente()).isEmpty);
    verifier('aucune pièce à reprendre', (await file.refuses()).isEmpty);

    dire('\nRejeu : LES MÊMES OCTETS, comme après une réponse perdue en route');
    // ⚠️ Le même dépôt, donc le même fichier, donc la même empreinte. C'est le
    // seul contrôle qui prouve que l'enveloppe multipart écrite à la main est
    // correcte : si elle ajoutait ou retranchait un octet, l'empreinte
    // changerait ici et le serveur créerait une SECONDE pièce.
    await file.ajouter(depot);
    final second = await file.vider(remise.remettre);
    verifier(
      'le serveur accepte le rejeu',
      second.remis == 1,
      "sans quoi une réponse perdue ferait entrer la facture deux fois",
    );
    verifier('rien à reprendre', (await file.refuses()).isEmpty);

    dire('\nLes copies devenues inutiles');
    verifier(
      'la copie est effacée, la pièce étant remise',
      await prise.effacerLesCopiesDevenuesInutiles() == 1,
    );
    verifier(
      'et le fichier a bien disparu',
      !await File(depot.cheminDuFichier).exists(),
    );

    dire('\nSession fermée : ce qui doit arriver à la file');
    await client.fermerLaSession();
    await cache.create(recursive: true);
    final orphelin = await prise.pour(dossier);
    verifier('une pièce attend', orphelin != null);
    final apres = await file.vider(remise.remettre);
    verifier("la file s'arrête", apres.remis == 0);
    verifier("et dit qu'il faut se reconnecter", apres.sessionAExpire);
    final reste = await file.enAttente();
    verifier('la pièce reste en attente', reste.length == 1);
    verifier(
      'sans tentative comptée',
      reste.isNotEmpty && reste.single.tentatives == 0,
      'sinon six ouvertures suffisaient à la condamner',
    );
    verifier(
      "et elle n'est pas déclarée refusée",
      (await file.refuses()).isEmpty,
    );
    verifier(
      'sa copie est gardée',
      orphelin != null && await File(orphelin.cheminDuFichier).exists(),
      'une pièce non remise ne s\'efface pas',
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
