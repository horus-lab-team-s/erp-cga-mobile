import 'package:cga_mobile/domaine/piece_remise.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// La lecture de ce que le serveur rend. C'est le point où une application
/// mobile casse le plus souvent et le plus silencieusement : un champ nul là où
/// on attendait un texte, un entier là où on attendait un décimal, un état
/// inconnu parce que le serveur a été déployé avant le téléphone. Aucun de ces
/// trois cas ne se voit en développement, et chacun vide l'écran d'historique
/// chez un adhérent qui, lui, a bien déposé ses pièces.
/// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Une pièce qui vient d\'arriver n\'a ni émetteur ni montant', () {
    test('elle se lit quand même, et se dit « reçue »', () {
      final piece = PieceRemise.depuisJson({
        'identifiant': 'PJ-M08123-68a12425a4d20502',
        'depose_le': '2026-09-20',
        'etat': 'RECUE',
        'canal': 'MOBILE',
        'nom_fichier': 'photo-2026-09-20-0129.jpg',
        'emetteur': null,
        'montant_ttc': null,
        'reference_document': null,
      });

      expect(piece.identifiant, 'PJ-M08123-68a12425a4d20502');
      expect(piece.etat, EtatChezLeCabinet.recue);
      expect(piece.identifiee, isFalse);
      expect(piece.etat.priseEnCompte, isFalse);
    });

    test('et le jour où le cabinet la lit, elle porte ce qu\'il y a vu', () {
      final piece = PieceRemise.depuisJson({
        'identifiant': 'PJ-M08123-aaa',
        'depose_le': '2026-09-12',
        'etat': 'LUE',
        'canal': 'MOBILE',
        'emetteur': 'ENEO',
        'montant_ttc': 45000,
        'reference_document': 'F-2026-0439',
      });

      expect(piece.identifiee, isTrue);
      expect(piece.emetteur, 'ENEO');
      expect(piece.montantTtc, 45000.0);
      expect(piece.etat.priseEnCompte, isTrue);
    });
  });

  test(
    'Un montant rond arrive en entier, et ne doit pas faire tomber la liste',
    () {
      // ⚠️ LE PIÈGE QUI A MOTIVÉ CE CAS. Le serveur sérialise 45 000 F en
      // `45000`, que Dart décode en `int`. Un `as double` aurait levé une
      // exception sur la moitié des factures du Cameroun — celles dont le
      // montant est rond — et l'historique ENTIER serait tombé sur une seule
      // ligne mal formée. Le défaut n'apparaît pas sur un jeu d'essai dont les
      // montants portent des centimes.
      final rond = PieceRemise.depuisJson({
        'identifiant': 'PJ-1',
        'depose_le': '2026-09-01',
        'etat': 'LUE',
        'montant_ttc': 45000,
      });
      final centimes = PieceRemise.depuisJson({
        'identifiant': 'PJ-2',
        'depose_le': '2026-09-01',
        'etat': 'LUE',
        'montant_ttc': 45000.75,
      });

      expect(rond.montantTtc, 45000.0);
      expect(centimes.montantTtc, 45000.75);
    },
  );

  test(
    'Un état que ce téléphone ne connaît pas ne fait pas disparaître la pièce',
    () {
      // ⚠️ Le serveur se déploie en une fois, les téléphones se mettent à jour
      // quand leurs propriétaires le veulent. Un septième état ajouté côté
      // serveur trouvera des applications installées qui l'ignorent. Elles
      // doivent montrer la pièce en la disant « reçue », et non cesser
      // d'afficher l'historique : un écran dégradé vaut mieux qu'un écran blanc.
      final piece = PieceRemise.depuisJson({
        'identifiant': 'PJ-3',
        'depose_le': '2026-09-01',
        'etat': 'CONTESTEE',
      });

      expect(piece.etat, EtatChezLeCabinet.recue);
    },
  );

  test('Le canal manquant ne vaut pas « mobile » par défaut', () {
    // Supposer le mobile ferait passer pour photographiée une pièce arrivée
    // autrement. « INDETERMINE » ne renseigne pas, mais il ne ment pas.
    final piece = PieceRemise.depuisJson({
      'identifiant': 'PJ-4',
      'depose_le': '2026-09-01',
      'etat': 'RECUE',
    });

    expect(piece.canal, 'INDETERMINE');
  });

  group('Les cinq états disent à l\'adhérent où en est sa pièce', () {
    test('« reçue » est le seul qui ne soit pas une prise en compte', () {
      expect(EtatChezLeCabinet.recue.priseEnCompte, isFalse);
      for (final etat in EtatChezLeCabinet.values) {
        if (etat != EtatChezLeCabinet.recue) {
          expect(
            etat.priseEnCompte,
            isTrue,
            reason: '${etat.name} devrait compter comme traitée',
          );
        }
      }
    });

    test('et chacun porte une phrase, jamais le nom de la base', () {
      for (final etat in EtatChezLeCabinet.values) {
        expect(etat.libelle, isNotEmpty);
        expect(
          etat.libelle,
          isNot(equals(etat.name.toUpperCase())),
          reason: 'le libellé ne doit pas être le nom technique',
        );
      }
    });

    test('la progression va de 0 à 4, dans l\'ordre du traitement', () {
      expect(EtatChezLeCabinet.recue.rang, 0);
      expect(EtatChezLeCabinet.archivee.rang, 4);
      expect(
        EtatChezLeCabinet.lue.rang < EtatChezLeCabinet.comptabilisee.rang,
        isTrue,
      );
    });
  });

  group('Un historique vide ne veut pas dire la même chose selon la cause', () {
    test('rien déposé : la liste est vide, le serveur a répondu', () {
      const h = Historique();
      expect(h.pieces, isEmpty);
      expect(h.serveurJoignable, isTrue);
      expect(h.sessionAExpire, isFalse);
    });

    test('pas de réseau : la liste est vide, le serveur n\'a rien dit', () {
      const h = Historique(serveurJoignable: false);
      expect(h.pieces, isEmpty);
      expect(h.serveurJoignable, isFalse);
    });

    test('session expirée : il faut un geste, et pas le même', () {
      const h = Historique(sessionAExpire: true);
      expect(h.sessionAExpire, isTrue);
    });
  });

  test('Le bilan compte ce que le cabinet a réellement traité', () {
    final h = Historique(
      pieces: [
        _piece('RECUE'),
        _piece('RECUE'),
        _piece('LUE'),
        _piece('COMPTABILISEE'),
      ],
    );

    expect(h.pieces.length, 4);
    expect(h.prisesEnCompte, 2);
  });
}

PieceRemise _piece(String etat) => PieceRemise.depuisJson({
  'identifiant': 'PJ-$etat-${DateTime.now().microsecondsSinceEpoch}',
  'depose_le': '2026-09-01',
  'etat': etat,
});
