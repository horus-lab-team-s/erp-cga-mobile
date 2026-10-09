import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ce que le PAQUET LIVRÉ doit contenir, et qu'aucun autre cas ne peut voir.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// POURQUOI DES CAS QUI LISENT DES FICHIERS DE CONFIGURATION
///
/// Le 22 septembre, l'APK de production construit sur cette machine ne portait
/// AUCUNE permission réseau. L'application démarrait, affichait sa page de
/// connexion, et chaque appel échouait. Rien dans les 218 autres cas ne pouvait
/// le dire : ils s'exécutent sur le poste, où il n'y a ni manifeste fusionné ni
/// bac à sable Android. Le défaut ne vit pas dans le code Dart, il vit dans un
/// fichier que le gabarit de Flutter livre incomplet.
///
/// ⚠️ CES CAS NE REMPLACENT PAS UN ESSAI SUR APPAREIL. Ils garantissent
/// seulement que les trois déclarations dont l'absence est INVISIBLE en
/// développement sont toujours là. C'est peu, et c'est exactement ce qui
/// manquait.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  group('Le paquet Android', () {
    final manifeste = File('android/app/src/main/AndroidManifest.xml');

    test('déclare la permission réseau dans le profil LIVRÉ', () {
      // ⚠️ `main`, et pas `debug` : un paquet de production ne fusionne que
      // celui-là. Le gabarit de Flutter pose la permission dans `debug` et
      // `profile` uniquement, ce qui donne une version de développement qui
      // marche et une version livrée muette.
      expect(
        manifeste.readAsStringSync(),
        contains('android.permission.INTERNET'),
        reason: 'Sans elle, aucun appel ne sort du téléphone en production.',
      );
    });

    test('restreint le trafic en clair au poste de développement', () {
      expect(manifeste.readAsStringSync(), contains('@xml/reseau'));
      final politique = File(
        'android/app/src/main/res/xml/reseau.xml',
      ).readAsStringSync();
      // La racine refuse le clair ; seules les adresses locales l'autorisent.
      expect(
        politique,
        contains('<base-config cleartextTrafficPermitted="false"'),
      );
      expect(
        politique,
        contains('<domain includeSubdomains="false">localhost</domain>'),
      );
      // ⚠️ Le garde-fou qui compte : si quelqu'un ouvre le clair à la racine
      // pour « faire marcher la démonstration », le mot de passe d'un adhérent
      // traverse le wifi en lisible. Ce cas tombe avant.
      expect(
        politique,
        isNot(contains('<base-config cleartextTrafficPermitted="true"')),
      );
    });

    test('porte le nom que l\'adhérent cherche dans son tiroir', () {
      expect(
        manifeste.readAsStringSync(),
        contains('android:label="CGA Broad Range"'),
      );
    });

    test(
      'ne signe pas la version livrée avec la clé de débogage sans le dire',
      () {
        final gradle = File('android/app/build.gradle.kts').readAsStringSync();
        expect(gradle, contains('key.properties'));
        expect(gradle, contains('logger.warn'));
      },
    );
  });

  group('Le paquet iOS', () {
    final plist = File('ios/Runner/Info.plist');

    test('explique pourquoi il demande l\'appareil photo', () {
      // ⚠️ Sans cette clé, iOS ARRÊTE l'application au premier appui sur
      // « Déposer ». Ce n'est pas un refus d'autorisation, c'est un arrêt.
      expect(plist.readAsStringSync(), contains('NSCameraUsageDescription'));
    });

    test('explique pourquoi il demande les photos enregistrées', () {
      expect(
        plist.readAsStringSync(),
        contains('NSPhotoLibraryUsageDescription'),
      );
    });
  });
}
