import 'dart:convert';
import 'dart:typed_data';

import 'package:cga_mobile/ecrans/visionneuse.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/service_des_fichiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// LA VISIONNEUSE : ce que le cabinet a reçu, tel qu'il l'a reçu.
///
/// Le cas qui compte le plus n'est pas l'affichage : c'est qu'aucun échec ne
/// se présente en écran blanc. Réseau coupé, pièce retirée, format inconnu,
/// session expirée : chacun a sa phrase.
/// ─────────────────────────────────────────────────────────────────────────────

/// Un PNG d'un point, valide : de quoi faire passer une vraie image.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _Fichiers implements ServiceDesFichiers {
  _Fichiers(this.reponse);
  FichierLu reponse;
  final demandes = <String>[];

  @override
  Future<FichierLu> lireLeFichier(String piece) async {
    demandes.add(piece);
    return reponse;
  }
}

Future<({_Fichiers fichiers, List<int> expirations})> _ouvrir(
  WidgetTester testeur,
  FichierLu reponse,
) async {
  final f = _Fichiers(reponse);
  final expirations = <int>[];
  await testeur.pumpWidget(
    MaterialApp(
      theme: themeClair(),
      home: Builder(
        builder: (contexte) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(contexte).push(
              MaterialPageRoute<void>(
                builder: (_) => EcranVisionneuse(
                  fichiers: f,
                  piece: 'PJ-2026-0013',
                  titre: 'f-2026-0424.pdf',
                  quandSessionExpire: () => expirations.add(1),
                ),
              ),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
  await testeur.tap(find.text('ouvrir'));
  await testeur.pumpAndSettle();
  return (fichiers: f, expirations: expirations);
}

void main() {
  testWidgets('demande le fichier de LA pièce touchée', (testeur) async {
    final r = await _ouvrir(
      testeur,
      FichierLu(octets: Uint8List.fromList(_png), type: 'image/png'),
    );
    expect(r.fichiers.demandes, ['PJ-2026-0013']);
    expect(find.text('f-2026-0424.pdf'), findsOneWidget);
  });

  testWidgets("une image s'affiche, et s'agrandit", (testeur) async {
    await _ouvrir(
      testeur,
      FichierLu(octets: Uint8List.fromList(_png), type: 'image/jpeg'),
    );
    final zoom = testeur.widget<InteractiveViewer>(
      find.byKey(const Key('visionneuse-image')),
    );
    // ⚠️ Un montant sur une facture photographiée de loin ne se lit qu'en
    // agrandissant beaucoup.
    expect(zoom.maxScale, greaterThanOrEqualTo(4));
  });

  testWidgets("un PDF que le système ne sait pas ouvrir ne plante pas", (
    testeur,
  ) async {
    // ⚠️ Le lecteur de PDF s'appuie sur le moteur du système. La machine
    // d'essai n'en a pas, comme certains téléphones : l'ouverture lève une
    // exception sur-le-champ. L'écran doit le DIRE, et rappeler que le
    // cabinet a bien le fichier. Le rendu réel d'un PDF se vérifie, lui, sur
    // un téléphone Android.
    await _ouvrir(
      testeur,
      FichierLu(
        octets: Uint8List.fromList(utf8.encode('%PDF-1.4')),
        type: 'application/pdf',
      ),
    );
    expect(testeur.takeException(), isNull);
    expect(find.byKey(const Key('visionneuse-pdf-illisible')), findsOneWidget);
    // Et surtout pas le message « format inconnu » : un PDF n'en est pas un.
    expect(find.byKey(const Key('visionneuse-format')), findsNothing);
  });

  testWidgets('pas de réseau : le dit, et laisse réessayer', (testeur) async {
    final r = await _ouvrir(testeur, const FichierLu(serveurJoignable: false));
    expect(find.byKey(const Key('visionneuse-hors-ligne')), findsOneWidget);
    r.fichiers.reponse = FichierLu(
      octets: Uint8List.fromList(_png),
      type: 'image/png',
    );
    await testeur.tap(find.text('Réessayer'));
    await testeur.pumpAndSettle();
    expect(find.byKey(const Key('visionneuse-image')), findsOneWidget);
  });

  testWidgets('une pièce retirée ne passe pas pour une panne', (testeur) async {
    await _ouvrir(testeur, const FichierLu(introuvable: true));
    expect(find.byKey(const Key('visionneuse-introuvable')), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('un format inconnu dit que le cabinet l\'a bien reçu', (
    testeur,
  ) async {
    await _ouvrir(
      testeur,
      FichierLu(octets: Uint8List.fromList([1, 2, 3]), type: 'application/zip'),
    );
    expect(find.byKey(const Key('visionneuse-format')), findsOneWidget);
    expect(find.textContaining('bien reçu'), findsOneWidget);
  });

  testWidgets('une session expirée ferme la visionneuse et le signale', (
    testeur,
  ) async {
    final r = await _ouvrir(testeur, const FichierLu(sessionAExpire: true));
    expect(r.expirations, [1]);
    expect(find.byType(EcranVisionneuse), findsNothing);
  });
}
