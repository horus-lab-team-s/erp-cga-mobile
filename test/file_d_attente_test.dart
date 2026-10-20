import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/domaine/depot.dart';
import 'package:cga_mobile/api/client_api.dart';
import 'package:cga_mobile/api/remise.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// La règle de renvoi est ce qu'on ne peut pas vérifier à la main : il faudrait
/// couper le réseau au bon moment, vingt fois de suite. Chacun des cas ci-dessous
/// décrit une panne réelle du terrain, et ce que l'application doit en faire.
/// ─────────────────────────────────────────────────────────────────────────────

Depot _depot(String id, {int jour = 1, int tentatives = 0}) => Depot(
  identifiant: id,
  dossier: 'D-001',
  cheminDuFichier: '/tmp/$id.jpg',
  prisLe: DateTime(2026, 9, jour),
  tentatives: tentatives,
);

void main() {
  group("L'ordre de la file", () {
    test('est celui de la prise de vue, pas celui de l\'ajout', () async {
      final file = FileDAttente(MagasinEnMemoire());
      await file.ajouter(_depot('B', jour: 17));
      await file.ajouter(_depot('A', jour: 3));

      final attente = await file.enAttente();

      expect(
        attente.map((d) => d.identifiant),
        ['A', 'B'],
        reason:
            "la facture du 3 doit arriver avant celle du 17, sinon le "
            "collaborateur qui suit le dossier voit une chronologie fausse",
      );
    });
  });

  group('Le sort de chaque dépôt', () {
    test('un dépôt accepté sort de la file', () async {
      final file = FileDAttente(MagasinEnMemoire());
      await file.ajouter(_depot('A'));

      final vidage = await file.vider((_) async => Reponse.accepte);

      expect(vidage.remis, 1);
      expect(await file.enAttente(), isEmpty);
      expect(await file.refuses(), isEmpty);
    });

    test('un dépôt refusé quitte l\'attente et passe à reprendre', () async {
      final file = FileDAttente(MagasinEnMemoire());
      await file.ajouter(_depot('A'));

      await file.vider((_) async => Reponse.refuse);

      expect(await file.enAttente(), isEmpty);
      expect((await file.refuses()).single.identifiant, 'A');
    });

    test('une indisponibilité laisse le dépôt en attente', () async {
      final file = FileDAttente(MagasinEnMemoire());
      await file.ajouter(_depot('A'));

      final vidage = await file.vider((_) async => Reponse.indisponible);

      expect(vidage.remis, 0);
      expect(
        (await file.enAttente()).single.tentatives,
        1,
        reason:
            'la tentative doit être comptée, sinon le garde-fou des six '
            'essais ne se déclenche jamais',
      );
    });
  });

  group("L'arrêt à la première indisponibilité", () {
    test('ne tente pas les suivants', () async {
      final file = FileDAttente(MagasinEnMemoire());
      await file.ajouter(_depot('A', jour: 1));
      await file.ajouter(_depot('B', jour: 2));
      final tentes = <String>[];

      await file.vider((d) async {
        tentes.add(d.identifiant);
        return Reponse.indisponible;
      });

      expect(
        tentes,
        ['A'],
        reason:
            'si le réseau manque pour le premier, il manque pour les '
            "suivants : insister perdrait l'ordre de remise",
      );
    });

    test('un refus, lui, n\'arrête pas la file', () async {
      final file = FileDAttente(MagasinEnMemoire());
      await file.ajouter(_depot('A', jour: 1));
      await file.ajouter(_depot('B', jour: 2));
      final tentes = <String>[];

      final vidage = await file.vider((d) async {
        tentes.add(d.identifiant);
        return d.identifiant == 'A' ? Reponse.refuse : Reponse.accepte;
      });

      expect(tentes, ['A', 'B']);
      expect(vidage.remis, 1);
    });
  });

  group('L\'espacement des essais (19 octobre 2026)', () {
    test(
      'ne renonce jamais : au-delà de six essais, la pièce repart encore',
      () async {
        final file = FileDAttente(MagasinEnMemoire());
        await file.ajouter(_depot('A', tentatives: 9));

        final vidage = await file.vider((_) async => Reponse.accepte);

        expect(
          vidage.remis,
          1,
          reason:
              "l'arrêt définitif tombait en trois minutes sans réseau, et la pièce "
              "ne partait plus jamais alors que l'écran promettait le contraire",
        );
      },
    );

    test(
      'espace les essais, sauf quand l\'adhérent demande l\'envoi',
      () async {
        final file = FileDAttente(MagasinEnMemoire());
        final midi = DateTime(2026, 10, 19, 12);
        await file.ajouter(_depot('A'));
        await file.vider((_) async => Reponse.indisponible, maintenant: midi);

        var tente = false;
        Future<Reponse> remettre(Depot _) async {
          tente = true;
          return Reponse.accepte;
        }

        await file.vider(
          remettre,
          maintenant: midi.add(const Duration(seconds: 10)),
        );
        expect(
          tente,
          isFalse,
          reason: 'la batterie et le forfait de l\'adhérent',
        );

        await file.vider(
          remettre,
          maintenant: midi.add(const Duration(seconds: 10)),
          forcer: true,
        );
        expect(tente, isTrue);
      },
    );

    test("l'attente croît, puis plafonne à une heure", () {
      expect(FileDAttente.attenteApres(1), const Duration(seconds: 30));
      expect(FileDAttente.attenteApres(4), const Duration(minutes: 30));
      expect(FileDAttente.attenteApres(40), const Duration(hours: 1));
    });
  });

  group("L'identifiant posé sur l'appareil", () {
    test('survit à l\'aller-retour en JSON', () {
      final avant = _depot('A', jour: 12);

      final apres = Depot.depuisJson(avant.versJson());

      expect(apres.identifiant, avant.identifiant);
      expect(apres.prisLe, avant.prisLe);
      expect(
        apres.etat,
        avant.etat,
        reason:
            "c'est ce qui rendra la remise idempotente quand le magasin "
            'durable écrira la file sur le disque',
      );
    });
  });
  group('La session expirée', () {
    test("laisse le dépôt en attente, et ne compte pas de tentative", () async {
      final file = FileDAttente(MagasinEnMemoire());
      await file.ajouter(_depot('A'));

      final vidage = await file.vider((_) async => Reponse.sessionExpiree);

      expect(vidage.remis, 0);
      expect(vidage.sessionAExpire, isTrue);
      final reste = (await file.enAttente()).single;
      expect(
        reste.tentatives,
        0,
        reason:
            "six ouvertures avec une session périmée franchiraient sinon le "
            "garde-fou, et les pièces cesseraient de partir sans que rien ne le "
            "dise à un adhérent qui n'a rien fait de mal",
      );
      expect(await file.refuses(), isEmpty);
    });

    test('arrête la file, comme une indisponibilité', () async {
      final file = FileDAttente(MagasinEnMemoire());
      await file.ajouter(_depot('A', jour: 1));
      await file.ajouter(_depot('B', jour: 2));
      final tentes = <String>[];

      await file.vider((d) async {
        tentes.add(d.identifiant);
        return Reponse.sessionExpiree;
      });

      expect(tentes, ['A']);
    });
  });

  group('La traduction des codes du serveur', () {
    test('201 et 200 partent : le second est un rejeu, pas une erreur', () {
      expect(sortDuCode(201), Reponse.accepte);
      expect(sortDuCode(200), Reponse.accepte);
    });

    test('401 demande de se reconnecter, il ne refuse pas la pièce', () {
      expect(sortDuCode(401), Reponse.sessionExpiree);
    });

    test('ce que le serveur ne prendra jamais sort de la file', () {
      for (final code in [403, 404, 409, 413, 415, 422]) {
        expect(sortDuCode(code), Reponse.refuse, reason: 'code $code');
      }
    });

    test('un code imprévu penche vers la reprise', () {
      // ⚠️ Se tromper de ce côté coûte une tentative ; se tromper de l'autre
      // jette la pièce d'un adhérent pour un code qu'on n'avait pas anticipé.
      for (final code in [429, 500, 502, 503, 504, 418]) {
        expect(sortDuCode(code), Reponse.indisponible, reason: 'code $code');
      }
    });
  });
  group('Le nom donné à la photo', () {
    test('porte la date et l\'heure de la prise de vue', () {
      final nom = ClientApi.nomDeLaPhotoPourEssai(
        DateTime(2026, 9, 19, 21, 10),
      );

      expect(nom, 'photo-2026-09-19-2110.jpg');
    });

    test('complète les mois, jours et heures à un chiffre', () {
      // ⚠️ Sans le remplissage, « photo-2026-1-5-90.jpg » ne se trie pas et ne
      // se lit pas : le cabinet voit des noms de longueurs différentes dans une
      // liste où ils devraient s'aligner.
      final nom = ClientApi.nomDeLaPhotoPourEssai(DateTime(2026, 1, 5, 9, 7));

      expect(nom, 'photo-2026-01-05-0907.jpg');
    });

    test('un scan garde son extension, et se dit scan', () {
      final nom = ClientApi.nomDeLaPhotoPourEssai(
        DateTime(2026, 10, 19, 14, 5),
        extensionDeLaPiece('/cache/Facture SONEL.PDF'),
      );

      expect(nom, 'scan-2026-10-19-1405.pdf');
      expect(extensionDeLaPiece('/x/IMG_0001.jpeg'), 'jpg');
      expect(extensionDeLaPiece('/x/sans-extension'), 'jpg');
    });
  });
}
