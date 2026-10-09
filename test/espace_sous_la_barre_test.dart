import 'dart:io';

import 'package:cga_mobile/marque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// Le coussin laissé en bas des pages défilantes, sous la barre flottante.
///
/// ⚠️ CE DÉFAUT NE S'EST VU QUE SUR UN APPAREIL, ET NE S'EST EXPLIQUÉ QU'EN
/// MESURANT DESSUS.
///
/// Le 27 septembre, sur un TECNO KM5 à navigation gestuelle, la dernière
/// section de l'accueil — les raccourcis — restait coupée par la barre du bas.
/// La constante réservait 104 : la barre (86) plus sa marge (12), plus deux.
///
/// Première explication, fausse : « il manque l'encart du système, ajoutons
/// `viewPadding.bottom` ». Le correctif n'a rien changé à l'écran, et la mesure
/// posée dans l'écran a dit pourquoi :
///
///     hauteur=800  padding.bottom=114  viewPadding.bottom=0  reserve=104
///
/// `viewPadding` vaut **zéro** : la coquille pose la barre dans une `SafeArea`,
/// qui retranche de `viewPadding` ce qu'elle consomme. Et le cadre annonçait
/// déjà la bonne valeur ailleurs : `padding.bottom = 114`, soit la barre, sa
/// marge et l'encart réunis. La constante écrite à la main en réservait dix de
/// moins — d'où les dix pixels coupés.
///
/// D'où les deux familles de cas ci-dessous :
///
///   · la première POSE le `padding` que le cadre annonce, et vérifie que le
///     coussin le suit — y compris quand la barre grandit avec la taille de
///     texte du système, ce qu'une constante ne peut pas faire ;
///   · la seconde relit le code des écrans, pour qu'un écran neuf ne puisse pas
///     réintroduire la constante nue sans que la recette le dise.
/// ─────────────────────────────────────────────────────────────────────────────

/// Mesure le coussin tel que l'écran le calculerait, sous le `padding` que le
/// `Scaffold` de la coquille annoncerait.
Future<double> coussinSous(WidgetTester testeur, double annonce) async {
  late double mesure;
  await testeur.pumpWidget(
    MediaQuery(
      data: MediaQueryData(padding: EdgeInsets.only(bottom: annonce)),
      child: Builder(
        builder: (context) {
          mesure = Marque.espaceSousLaBarreDe(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return mesure;
}

void main() {
  group('Le coussin suit ce que le cadre annonce', () {
    testWidgets('il couvre la hauteur annoncée, et laisse de l\'air', (
      testeur,
    ) async {
      // 114 : la valeur relevée sur l'appareil.
      expect(await coussinSous(testeur, 114), 114 + Marque.espace3);
    });

    testWidgets('il suit la barre quand elle grandit avec le texte', (
      testeur,
    ) async {
      // ⚠️ LE CAS QU'UNE CONSTANTE NE PEUT PAS TENIR. À 200 % de taille de
      // texte, la barre monte de 22 : le cadre l'annonce, le coussin suit.
      expect(await coussinSous(testeur, 136), 136 + Marque.espace3);
    });

    testWidgets('il ne descend jamais sous ce que la barre occupe', (
      testeur,
    ) async {
      for (final annonce in [104.0, 114.0, 136.0, 160.0]) {
        expect(
          await coussinSous(testeur, annonce),
          greaterThan(annonce),
          reason:
              'Réserver exactement la hauteur annoncée collerait la dernière '
              'ligne contre la barre.',
        );
      }
    });

    testWidgets('hors de la coquille, la constante sert de plancher', (
      testeur,
    ) async {
      // Un écran monté seul : le cadre n'a pas de barre à annoncer, et rien ne
      // doit passer sous zéro.
      expect(
        await coussinSous(testeur, 0),
        Marque.espaceSousLaBarre + Marque.espace3,
      );
    });
  });

  group('Aucun écran ne réserve la constante nue', () {
    test('les écrans défilants passent tous par …De(context)', () {
      final fautifs = <String>[];
      for (final fichier in Directory('lib/ecrans').listSync()) {
        if (fichier is! File || !fichier.path.endsWith('.dart')) continue;
        final lignes = fichier.readAsLinesSync();
        for (var i = 0; i < lignes.length; i++) {
          final ligne = lignes[i];
          // On cherche la constante employée SEULE, c'est-à-dire pas suivie de
          // `De(context)`. Les commentaires qui la citent sont écartés.
          if (!ligne.contains('Marque.espaceSousLaBarre')) continue;
          if (ligne.contains('Marque.espaceSousLaBarreDe')) continue;
          if (ligne.trimLeft().startsWith('//')) continue;
          fautifs.add('${fichier.path}:${i + 1} → ${ligne.trim()}');
        }
      }
      expect(
        fautifs,
        isEmpty,
        reason:
            'Ces lignes réservent la constante nue : elle ne suit ni l\'encart '
            'du système, ni la barre quand le texte grossit, et leur dernière '
            'ligne finira cachée. Employer Marque.espaceSousLaBarreDe(context).',
      );
    });
  });
}
