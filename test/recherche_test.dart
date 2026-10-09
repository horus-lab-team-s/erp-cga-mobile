import 'package:cga_mobile/domaine/recherche.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// La comparaison sur laquelle reposent les deux recherches de l'application.
///
/// ⚠️ Le cas central est celui des accents : on tape « fevrier » sur un clavier
/// de téléphone, et si la liste ne rend rien, on en conclut que le document
/// n'existe pas. Une recherche qui répond « rien » à tort est pire que pas de
/// recherche du tout.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('Le texte ramené à ce qui se tape', () {
    test('perd ses accents et ses majuscules', () {
      expect(aplati('Février'), 'fevrier');
      expect(aplati('DÉPÔT'), 'depot');
      expect(aplati('Société Générale'), 'societe generale');
    });

    test('garde les chiffres et la ponctuation des références', () {
      expect(aplati('DGI-2024-02-121877'), 'dgi-2024-02-121877');
    });

    test('déplie les ligatures', () {
      expect(aplati('Cœur'), 'coeur');
    });
  });

  group('La correspondance', () {
    const ligne = ['TVA du mois', 'février 2024', 'Impôts (DGI)'];

    test('trouve sans accent ce qui en porte', () {
      expect(correspond(ligne, 'fevrier'), isTrue);
      expect(correspond(ligne, 'impots'), isTrue);
    });

    test('trouve avec accent ce qui n\'en porte pas', () {
      expect(correspond(['Fevrier 2024'], 'février'), isTrue);
    });

    test('cherche les mots séparément, et dans n\'importe quel ordre', () {
      // Les deux mots sont dans DEUX champs différents, et dans l'autre ordre.
      expect(correspond(ligne, 'fevrier tva'), isTrue);
    });

    test('exige TOUS les mots, pas un seul', () {
      expect(correspond(ligne, 'tva janvier'), isFalse);
    });

    test('laisse tout passer quand rien n\'est cherché', () {
      // ⚠️ Le cas le plus fréquent : le champ n'a pas encore servi. Rendre
      // faux viderait l'écran à l'ouverture.
      expect(correspond(ligne, ''), isTrue);
      expect(correspond(ligne, '   '), isTrue);
    });

    test('ignore les champs absents sans se plaindre', () {
      expect(correspond(['ENEO', null, null], 'eneo'), isTrue);
      expect(correspond([null, null], 'eneo'), isFalse);
    });
  });
}
