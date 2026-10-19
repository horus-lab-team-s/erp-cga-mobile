// Les teintes d'état suivent le thème (19 octobre 2026).
//
// ⚠️ Le vert de « réglée » et l'indigo des icônes, calculés pour un fond clair,
// disparaissaient presque sur une carte sombre. Ce cas garde la bascule.

import 'package:cga_mobile/marque.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BuildContext> _contexte(WidgetTester testeur, ThemeData theme) async {
  late BuildContext lu;
  await testeur.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (contexte) {
          lu = contexte;
          return const SizedBox();
        },
      ),
    ),
  );
  return lu;
}

void main() {
  testWidgets('en clair, les teintes de la marque', (testeur) async {
    final contexte = await _contexte(testeur, themeClair());
    expect(Marque.reussiteDe(contexte), Marque.reussite);
    expect(Marque.alerteDe(contexte), Marque.alerte);
    expect(Marque.indigoDe(contexte), Marque.indigo700);
  });

  testWidgets('en sombre, leurs versions éclaircies', (testeur) async {
    final contexte = await _contexte(testeur, themeSombre());
    expect(Marque.reussiteDe(contexte), Marque.reussiteSombre);
    expect(Marque.alerteDe(contexte), Marque.alerteSombre);
    expect(Marque.indigoDe(contexte), Marque.indigo700Sombre);
    expect(Marque.reussiteDouceDe(contexte), Marque.reussite100Sombre);
  });
}
