import 'dart:convert';
import 'dart:io';

import 'package:cga_mobile/adaptateurs/magasin_fichier.dart';
import 'package:cga_mobile/domaine/depot.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// La durabilité de la file. Chacun décrit une manière réelle de perdre les
/// pièces d'un adhérent, et aucune ne se reproduit sur un poste de travail : il
/// faudrait arrêter l'application au milieu d'une écriture, ou abîmer un
/// fichier. C'est précisément pourquoi ils sont écrits.
/// ─────────────────────────────────────────────────────────────────────────────

Depot _depot(String id, {int jour = 1}) => Depot(
  identifiant: id,
  dossier: 'M081234567890P',
  cheminDuFichier: '/tmp/$id.jpg',
  prisLe: DateTime(2026, 9, jour),
);

void main() {
  late Directory dossier;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('cga-file-');
  });

  tearDown(() async {
    if (await dossier.exists()) {
      await dossier.delete(recursive: true);
    }
  });

  group('La file survit à la fermeture', () {
    test('un dépôt rangé se relit par un magasin neuf', () async {
      await MagasinDeFichier(dossier).ranger(_depot('A'));

      // Un second magasin, sur le même dossier : c'est ce que fait le prochain
      // démarrage de l'application.
      final relus = await MagasinDeFichier(dossier).tous();

      expect(relus.single.identifiant, 'A');
      expect(relus.single.dossier, 'M081234567890P');
      expect(relus.single.prisLe, DateTime(2026, 9, 1));
    });

    test("l'ordre de prise de vue survit lui aussi", () async {
      final magasin = MagasinDeFichier(dossier);
      await magasin.ranger(_depot('B', jour: 17));
      await magasin.ranger(_depot('A', jour: 3));

      final relus = await MagasinDeFichier(dossier).tous();

      expect(relus.map((d) => d.identifiant), ['A', 'B']);
    });

    test('un dépôt oublié ne revient pas', () async {
      final magasin = MagasinDeFichier(dossier);
      await magasin.ranger(_depot('A'));
      await magasin.oublier('A');

      expect(await MagasinDeFichier(dossier).tous(), isEmpty);
    });

    test("ranger deux fois le même identifiant ne crée qu'une ligne", () async {
      final magasin = MagasinDeFichier(dossier);
      await magasin.ranger(_depot('A'));
      await magasin.ranger(_depot('A').avec(tentatives: 3));

      final relus = await MagasinDeFichier(dossier).tous();

      expect(relus.length, 1);
      expect(relus.single.tentatives, 3);
    });
  });

  group("L'écriture atomique", () {
    test('ne laisse jamais le fichier de la file à moitié écrit', () async {
      final magasin = MagasinDeFichier(dossier);
      await magasin.ranger(_depot('A'));

      // ⚠️ Ce que ce cas vérifie vraiment : qu'il RESTE un fichier provisoire
      // nulle part. S'il en traînait un, c'est que le renommage n'a pas eu
      // lieu, donc que l'écriture passe encore par-dessus la file en place.
      final restes = dossier
          .listSync()
          .map((e) => e.path.split('/').last)
          .toList();

      expect(restes, ['file-des-depots.json']);
    });

    test(
      'la file en place reste entière si la nouvelle écriture échoue',
      () async {
        final magasin = MagasinDeFichier(dossier);
        await magasin.ranger(_depot('A'));
        final avant = await File(
          '${dossier.path}/file-des-depots.json',
        ).readAsString();

        // On rend le dossier inaccessible en écriture : la prochaine écriture
        // échouera, et c'est le cas que le système provoque quand la place manque.
        await Process.run('chmod', ['500', dossier.path]);
        await expectLater(magasin.ranger(_depot('B')), throwsA(anything));
        await Process.run('chmod', ['700', dossier.path]);

        final apres = await File(
          '${dossier.path}/file-des-depots.json',
        ).readAsString();
        expect(
          apres,
          avant,
          reason:
              "l'ancienne file doit être intacte : c'est tout l'objet du "
              'renommage. Une écriture directe aurait déjà tronqué le fichier',
        );
      },
    );
  });

  group('Un fichier illisible', () {
    test('est mis de côté, et non écrasé', () async {
      final fichier = File('${dossier.path}/file-des-depots.json');
      await fichier.writeAsString('[{"identifiant": "A", tronqu');

      final relus = await MagasinDeFichier(dossier).tous();

      expect(relus, isEmpty, reason: "on redémarre sur une file vide");
      final mis = dossier
          .listSync()
          .map((e) => e.path.split('/').last)
          .where((n) => n.contains('illisible'))
          .toList();
      expect(
        mis,
        hasLength(1),
        reason:
            'la matière doit rester sur l\'appareil : écraser '
            'transformerait un incident en perte définitive',
      );
    });

    test('ne bloque pas les dépôts suivants', () async {
      await File(
        '${dossier.path}/file-des-depots.json',
      ).writeAsString('pas du JSON');
      final magasin = MagasinDeFichier(dossier);
      await magasin.tous();

      await magasin.ranger(_depot('A'));

      expect((await MagasinDeFichier(dossier).tous()).single.identifiant, 'A');
    });
  });

  group('Le format écrit', () {
    test('est une liste JSON, relisible sans cette classe', () async {
      // ⚠️ Un format qu'on ne peut relire qu'avec le code qui l'a écrit est un
      // format qu'on ne peut pas dépanner. Une file bloquée sur le téléphone
      // d'un adhérent doit pouvoir se lire à l'œil.
      await MagasinDeFichier(dossier).ranger(_depot('A'));

      final brut = jsonDecode(
        await File('${dossier.path}/file-des-depots.json').readAsString(),
      );

      expect(brut, isA<List<dynamic>>());
      expect((brut as List).single['identifiant'], 'A');
      expect(brut.single['etat'], 'enAttente');
    });
  });
}
