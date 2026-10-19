// Le banc du guide d'utilisation : les écrans que le téléphone ne peut pas montrer
// sans ouvrir l'appareil photo (19 octobre 2026).
//
// Il rend, en PNG et avec les vraies polices, l'écran « Mes justificatifs » avec
// des pièces en attente, et l'aperçu avant envoi (photo et scan PDF). Il ne
// vérifie rien : il montre. Comme le banc d'aperçus, il ne tourne que sur demande :
//
//     APERCUS=/chemin/du/dossier FACTURE=/chemin/facture.jpg \
//       flutter test test/apercus/guide_test.dart
//
// FACTURE est une photo de facture FICTIVE (voir Docs/guides/mobile/README.md).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/domaine/depot.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:cga_mobile/ecrans/accueil.dart';
import 'package:cga_mobile/ecrans/apercu_du_depot.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/appareil_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ecran_accueil_test.dart' as accueil_test;

final _sortie = Platform.environment['APERCUS'];
final _facture = Platform.environment['FACTURE'];

class _SansPhoto implements AppareilPhoto {
  @override
  Future<String?> photographier() async => null;
}

Future<void> _chargerLesPolices() async {
  Future<void> famille(String nom, List<String> fichiers) async {
    final chargeur = FontLoader(nom);
    for (final f in fichiers) {
      chargeur.addFont(rootBundle.load('assets/polices/$f'));
    }
    await chargeur.load();
  }

  await famille('Inter', [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]);
  await famille('Poppins', [
    'Poppins-Regular.ttf',
    'Poppins-Medium.ttf',
    'Poppins-SemiBold.ttf',
    'Poppins-Bold.ttf',
  ]);
  final racine =
      Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/flutter';
  final icones = File(
    '$racine/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icones.existsSync()) {
    final chargeur = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icones.readAsBytesSync())));
    await chargeur.load();
  }
}

/// Le thème de l'application, à un détail près : `chipTheme.labelStyle` n'impose
/// pas de famille. Le téléphone prend alors la police du système ; le banc, lui,
/// retombait sur la police d'essai et dessinait des rectangles noirs. On y met
/// Inter, la police du texte.
ThemeData _theme() {
  final theme = themeClair();
  return theme.copyWith(
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: theme.chipTheme.labelStyle?.copyWith(
        fontFamily: Marque.policeTexte,
      ),
    ),
  );
}

/// Pose l'écran, laisse les images se décoder hors de l'horloge feinte, puis
/// écrit le PNG. [hauteur] en points : plus de 844 pour montrer un formulaire
/// entier.
Future<void> _photographier(
  WidgetTester testeur,
  String nom,
  Widget ecran, {
  double hauteur = 844,
  Future<void> Function(WidgetTester)? avant,
}) async {
  final cle = GlobalKey();
  testeur.view.physicalSize = Size(390 * 2, hauteur * 2);
  testeur.view.devicePixelRatio = 2;
  await testeur.pumpWidget(
    RepaintBoundary(
      key: cle,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ecran,
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await testeur.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await testeur.pump(const Duration(milliseconds: 50));
  }
  final contexte = cle.currentContext!;
  if (_facture != null) {
    await testeur.runAsync(
      () => precacheImage(FileImage(File(_facture!)), contexte),
    );
  }
  await testeur.pumpAndSettle();
  if (avant != null) await avant(testeur);
  for (var i = 0; i < 4; i++) {
    await testeur.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await testeur.pump(const Duration(milliseconds: 50));
  }
  await testeur.runAsync(() async {
    final limite =
        cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await limite.toImage(pixelRatio: 2);
    final octets = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_sortie/$nom.png').writeAsBytesSync(octets!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    final sortie = _sortie;
    if (sortie != null) {
      Directory(sortie).createSync(recursive: true);
      await _chargerLesPolices();
    }
  });

  final passer = _sortie == null || _facture == null
      ? 'APERCUS ou FACTURE non défini : banc du guide non joué'
      : null;

  testWidgets(
    'Mes justificatifs, deux pièces en attente',
    skip: passer != null,
    (t) async {
      final file = FileDAttente(MagasinEnMemoire());
      await t.runAsync(() async {
        await file.ajouter(
          Depot(
            identifiant: 'A',
            dossier: 'M081234567890P',
            cheminDuFichier: _facture!,
            prisLe: DateTime(2026, 10, 19, 9, 42),
          ),
        );
        await file.ajouter(
          Depot(
            identifiant: 'B',
            dossier: 'M081234567890P',
            cheminDuFichier: _facture!,
            prisLe: DateTime(2026, 10, 19, 9, 45),
          ),
        );
      });
      final prise = PriseDeVue(
        appareil: _SansPhoto(),
        galerie: _SansPhoto(),
        fichiers: _SansPhoto(),
        file: file,
        photos: Directory.systemTemp,
      );
      await _photographier(
        t,
        'justificatifs-en-attente',
        EcranAccueil(
          session: accueil_test.SessionFeinte(),
          file: file,
          priseDeVue: prise,
          // Pas de réseau : les pièces restent dans la file.
          remettre: (_) async => Reponse.indisponible,
          quandDeconnecte: () {},
          dossiers: const ['M081234567890P'],
          ouvrirLHistorique: () {},
        ),
      );
    },
  );

  testWidgets('Aperçu avant envoi, formulaire rempli', skip: passer != null, (
    t,
  ) async {
    await _photographier(
      t,
      'apercu-formulaire',
      EcranApercuDuDepot(chemin: _facture!),
      hauteur: 1560,
      avant: (t) async {
        await t.tap(find.byKey(const Key('nature-FACTURE_ACHAT')));
        await t.pump();
        await t.enterText(
          find.byKey(const Key('apercu-emetteur')),
          'QUINCAILLERIE DU WOURI',
        );
        await t.enterText(
          find.byKey(const Key('apercu-reference')),
          'FA-2026-0815',
        );
        await t.enterText(find.byKey(const Key('apercu-montant')), '184838');
        await t.enterText(
          find.byKey(const Key('apercu-note')),
          'Payée en espèces',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
      },
    );
  });

  testWidgets('Aperçu avant envoi, haut de l\'écran', skip: passer != null, (
    t,
  ) async {
    await _photographier(
      t,
      'apercu-photo',
      EcranApercuDuDepot(chemin: _facture!),
    );
  });

  testWidgets('Aperçu d\'un scan PDF', skip: passer != null, (t) async {
    final pdf = File('${Directory.systemTemp.path}/guide-scan.pdf');
    await t.runAsync(() => pdf.writeAsBytes(List<int>.filled(412 * 1024, 32)));
    await _photographier(
      t,
      'apercu-scan',
      EcranApercuDuDepot(chemin: pdf.path, unFichier: true),
    );
  });
}
