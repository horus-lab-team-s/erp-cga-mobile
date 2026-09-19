import 'dart:io';

import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/domaine/depot.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:cga_mobile/ports/appareil_photo.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// Ce qui se passe entre le déclencheur et la file. On ne peut l'éprouver ni sur
/// un poste ni dans la chaîne d'intégration : il n'y a pas d'appareil photo. Le
/// port en tient lieu, et ce sont les deux règles qui comptent qui sont
/// vérifiées — la recopie, et l'ordre de l'effacement.
/// ─────────────────────────────────────────────────────────────────────────────

/// Un appareil photo feint : il pose un fichier dans un dossier de cache, comme
/// le vrai, et ce cache est **vidé** par certains cas pour reproduire ce que le
/// système fait quand la place manque.
class AppareilFeint implements AppareilPhoto {
  AppareilFeint(this.cache, {this.renonce = false});

  final Directory cache;
  final bool renonce;
  int prises = 0;

  @override
  Future<String?> photographier() async {
    if (renonce) return null;
    prises++;
    final fichier = File('${cache.path}/photo-$prises.jpg');
    await fichier.writeAsBytes([0xFF, 0xD8, prises, 0xFF, 0xD9]);
    return fichier.path;
  }
}

void main() {
  late Directory racine;
  late Directory cache;
  late Directory photos;
  late FileDAttente file;

  setUp(() async {
    racine = await Directory.systemTemp.createTemp('cga-prise-');
    cache = await Directory('${racine.path}/cache').create();
    photos = Directory('${racine.path}/photos');
    file = FileDAttente(MagasinEnMemoire());
  });

  tearDown(() async {
    if (await racine.exists()) await racine.delete(recursive: true);
  });

  PriseDeVue avec(AppareilPhoto appareil) =>
      PriseDeVue(appareil: appareil, file: file, photos: photos);

  group('La photo est recopiée hors du cache', () {
    test('le dépôt ne désigne jamais le fichier du cache', () async {
      final appareil = AppareilFeint(cache);

      final depot = await avec(appareil).pour('M081234567890P');

      expect(depot, isNotNull);
      expect(
        depot!.cheminDuFichier.startsWith(photos.path),
        isTrue,
        reason:
            'le cache est repris par le système sans prévenir : un dépôt '
            'qui le désigne devient un fichier introuvable, et la remise le '
            'prendrait pour une pièce refusée par le cabinet',
      );
      expect(await File(depot.cheminDuFichier).exists(), isTrue);
    });

    test('la copie survit au vidage du cache', () async {
      final appareil = AppareilFeint(cache);
      final depot = await avec(appareil).pour('M081234567890P');

      // Ce que le système fait quand la place manque.
      await cache.delete(recursive: true);

      expect(await File(depot!.cheminDuFichier).exists(), isTrue);
      expect(await File(depot.cheminDuFichier).readAsBytes(), [
        0xFF,
        0xD8,
        1,
        0xFF,
        0xD9,
      ]);
    });

    test('deux photos ne se recouvrent pas', () async {
      final prise = avec(AppareilFeint(cache));

      final a = await prise.pour('M081234567890P');
      final b = await prise.pour('M081234567890P');

      expect(a!.cheminDuFichier, isNot(b!.cheminDuFichier));
      expect((await file.enAttente()).length, 2);
    });

    test('le dépôt entre dans la file, en attente', () async {
      final depot = await avec(AppareilFeint(cache)).pour('M081234567890P');

      final attente = await file.enAttente();
      expect(attente.single.identifiant, depot!.identifiant);
      expect(attente.single.dossier, 'M081234567890P');
      expect(attente.single.etat, EtatDuDepot.enAttente);
    });
  });

  group('Renoncer', () {
    test("ne crée rien, et n'est pas une erreur", () async {
      final depot = await avec(
        AppareilFeint(cache, renonce: true),
      ).pour('M081234567890P');

      expect(depot, isNull);
      expect(await file.enAttente(), isEmpty);
      expect(
        await photos.exists(),
        isFalse,
        reason:
            "on ferme l'appareil photo par réflexe : cela ne doit rien "
            'laisser derrière',
      );
    });
  });

  group("L'effacement des copies", () {
    test('ne touche pas à une pièce encore en attente', () async {
      final prise = avec(AppareilFeint(cache));
      final depot = await prise.pour('M081234567890P');

      final effacees = await prise.effacerLesCopiesDevenuesInutiles();

      expect(effacees, 0);
      expect(await File(depot!.cheminDuFichier).exists(), isTrue);
    });

    test('efface la copie une fois la pièce remise', () async {
      final prise = avec(AppareilFeint(cache));
      final depot = await prise.pour('M081234567890P');
      await file.vider((_) async => Reponse.accepte);

      final effacees = await prise.effacerLesCopiesDevenuesInutiles();

      expect(effacees, 1);
      expect(
        await File(depot!.cheminDuFichier).exists(),
        isFalse,
        reason:
            'une copie qui reste après remise remplit le téléphone en '
            'quelques semaines',
      );
    });

    test('garde la copie d\'une pièce refusée', () async {
      final prise = avec(AppareilFeint(cache));
      final depot = await prise.pour('M081234567890P');
      await file.vider((_) async => Reponse.refuse);

      final effacees = await prise.effacerLesCopiesDevenuesInutiles();

      expect(effacees, 0);
      expect(
        await File(depot!.cheminDuFichier).exists(),
        isTrue,
        reason:
            "l'adhérent doit pouvoir regarder ce que le cabinet n'a pas "
            'pris : effacer traiterait un refus comme une pièce réglée',
      );
    });

    test('ne fait rien quand aucune photo n\'a été prise', () async {
      expect(
        await avec(AppareilFeint(cache)).effacerLesCopiesDevenuesInutiles(),
        0,
      );
    });
  });

  group("L'instant retenu", () {
    test('est celui de la prise de vue, pas celui de la remise', () async {
      final avantLaPhoto = DateTime.now();

      final depot = await avec(AppareilFeint(cache)).pour('M081234567890P');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        depot!.prisLe.isBefore(DateTime.now()),
        isTrue,
        reason:
            "prendre l'instant de la remise ferait glisser au mois suivant "
            'toute pièce photographiée le 31 au soir sans réseau',
      );
      expect(depot.prisLe.isBefore(avantLaPhoto), isFalse);
    });
  });
}
