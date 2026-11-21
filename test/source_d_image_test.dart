import 'dart:io';

import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/composants/source_d_image.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:cga_mobile/ports/appareil_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// D'où vient l'image d'une quittance ou d'une pièce de DSF (18 octobre 2026).
class _Source implements AppareilPhoto {
  _Source(this.cache);

  final Directory cache;
  int prises = 0;

  @override
  Future<String?> photographier() async {
    prises++;
    final f = File('${cache.path}/s$prises.jpg');
    await f.writeAsBytes([0xFF, 0xD8, prises, 0xFF, 0xD9]);
    return f.path;
  }
}

void main() {
  late Directory racine;
  late _Source appareil;
  late _Source galerie;

  setUp(() async {
    racine = await Directory.systemTemp.createTemp('cga-source-');
    appareil = _Source(racine);
    galerie = _Source(racine);
  });

  tearDown(() async {
    if (await racine.exists()) await racine.delete(recursive: true);
  });

  Future<String?> obtenir(WidgetTester testeur, PriseDeVue prise) async {
    String? chemin;
    await testeur.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                chemin = await obtenirUneImage(context, prise),
            child: const Text('Envoyer'),
          ),
        ),
      ),
    );
    await testeur.tap(find.text('Envoyer'));
    await testeur.pumpAndSettle();
    return chemin;
  }

  PriseDeVue prise({bool avecGalerie = true}) => PriseDeVue(
    appareil: appareil,
    galerie: avecGalerie ? galerie : null,
    file: FileDAttente(MagasinEnMemoire()),
    photos: Directory('${racine.path}/photos'),
  );

  testWidgets('sans galerie, l\'appareil photo s\'ouvre sans question', (
    testeur,
  ) async {
    await obtenir(testeur, prise(avecGalerie: false));
    // La copie durable passe par le disque : hors de l'horloge feinte.
    await testeur.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await testeur.pumpAndSettle();

    expect(find.byKey(const Key('source-galerie')), findsNothing);
    expect(appareil.prises, 1);
  });

  testWidgets('avec la galerie, l\'adhérent choisit d\'où vient l\'image', (
    testeur,
  ) async {
    await obtenir(testeur, prise());

    expect(find.byKey(const Key('source-appareil')), findsOneWidget);
    await testeur.runAsync(() async {
      await testeur.tap(find.byKey(const Key('source-galerie')));
      await testeur.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await testeur.pumpAndSettle();

    expect(galerie.prises, 1);
    expect(appareil.prises, 0);
  });
}
