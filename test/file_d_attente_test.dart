import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/domaine/depot.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
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
        reason: "la facture du 3 doit arriver avant celle du 17, sinon le "
            "collaborateur qui suit le dossier voit une chronologie fausse",
      );
    });
  });

  group('Le sort de chaque dépôt', () {
    test('un dépôt accepté sort de la file', () async {
      final file = FileDAttente(MagasinEnMemoire());
      await file.ajouter(_depot('A'));

      final remis = await file.vider((_) async => Reponse.accepte);

      expect(remis, 1);
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

      final remis = await file.vider((_) async => Reponse.indisponible);

      expect(remis, 0);
      expect(
        (await file.enAttente()).single.tentatives,
        1,
        reason: 'la tentative doit être comptée, sinon le garde-fou des six '
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
        reason: 'si le réseau manque pour le premier, il manque pour les '
            "suivants : insister perdrait l'ordre de remise",
      );
    });

    test('un refus, lui, n\'arrête pas la file', () async {
      final file = FileDAttente(MagasinEnMemoire());
      await file.ajouter(_depot('A', jour: 1));
      await file.ajouter(_depot('B', jour: 2));
      final tentes = <String>[];

      final remis = await file.vider((d) async {
        tentes.add(d.identifiant);
        return d.identifiant == 'A' ? Reponse.refuse : Reponse.accepte;
      });

      expect(tentes, ['A', 'B']);
      expect(remis, 1);
    });
  });

  group('Le garde-fou des tentatives', () {
    test('cesse d\'essayer au-delà de six', () async {
      final file = FileDAttente(MagasinEnMemoire());
      await file.ajouter(_depot('A', tentatives: FileDAttente.tentativesMaximales));
      var tente = false;

      await file.vider((_) async {
        tente = true;
        return Reponse.accepte;
      });

      expect(
        tente,
        isFalse,
        reason: "une file qui réessaie sans fin hors réseau vide la batterie en "
            "une nuit, sans que l'adhérent comprenne pourquoi",
      );
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
        reason: "c'est ce qui rendra la remise idempotente quand le magasin "
            'durable écrira la file sur le disque',
      );
    });
  });
}
