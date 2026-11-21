import 'package:cga_mobile/api/client_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// 19 octobre 2026 (audit de sécurité) : une version publiée ne parle qu'en https.
void main() {
  test('une version publiée refuse un serveur en clair', () {
    expect(
      () => ClientApi.exigerHttps(
        Uri.parse('http://api.cga.cm'),
        enPublication: true,
      ),
      throwsStateError,
    );
    ClientApi.exigerHttps(Uri.parse('https://api.cga.cm'), enPublication: true);
  });

  test(
    'en développement, le clair reste permis pour le poste et l\'émulateur',
    () {
      ClientApi.exigerHttps(
        Uri.parse('http://localhost:8010'),
        enPublication: false,
      );
    },
  );
}
