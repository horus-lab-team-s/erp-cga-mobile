import 'dart:io';

import 'package:cga_mobile/api/client_api.dart';
import 'package:cga_mobile/ports/coffre_de_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rester connecté (19 octobre 2026) : la session survit à la fermeture, au coffre
/// du système, et le serveur reste juge.
class _Coffre implements CoffreDeSession {
  String? valeur;

  @override
  Future<String?> lire() async => valeur;

  @override
  Future<void> ecrire(String session) async => valeur = session;

  @override
  Future<void> effacer() async => valeur = null;
}

void main() {
  late HttpServer serveur;
  late int statutDeMoi;

  setUp(() async {
    statutDeMoi = 200;
    serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serveur.listen((requete) {
      final reponse = requete.response;
      if (requete.uri.path == '/transverse/session' &&
          requete.method == 'POST') {
        reponse.cookies.add(Cookie('cga_session', 'S-abc'));
      } else if (requete.uri.path == '/transverse/moi') {
        reponse.statusCode = statutDeMoi;
        reponse.write('{"dossiers": ["M081234567890P"]}');
      }
      reponse.close();
    });
  });

  tearDown(() => serveur.close(force: true));

  ClientApi client(_Coffre coffre) => ClientApi(
    base: Uri.parse('http://127.0.0.1:${serveur.port}'),
    coffre: coffre,
  );

  test(
    'la connexion range la session au coffre, la reprise la retrouve',
    () async {
      final coffre = _Coffre();
      expect(await client(coffre).ouvrirUneSession('a@b.cm', 'secret'), isTrue);
      expect(coffre.valeur, 'cga_session=S-abc');

      final demain = client(coffre);
      expect(await demain.reprendreLaSession(), isTrue);
      expect(demain.connecte, isTrue);
    },
  );

  test('une session que le serveur refuse sort du coffre', () async {
    final coffre = _Coffre()..valeur = 'cga_session=S-perimee';
    statutDeMoi = 401;

    expect(await client(coffre).reprendreLaSession(), isFalse);
    expect(coffre.valeur, isNull);
  });

  test('la déconnexion vide le coffre', () async {
    final coffre = _Coffre();
    final c = client(coffre);
    await c.ouvrirUneSession('a@b.cm', 'secret');
    await c.fermerLaSession();
    expect(coffre.valeur, isNull);
  });

  test(
    'sans réseau, on entre quand même : le dépôt marche hors ligne',
    () async {
      final coffre = _Coffre()..valeur = 'cga_session=S-abc';
      final horsLigne = client(coffre);
      await serveur.close(force: true);

      expect(await horsLigne.reprendreLaSession(), isTrue);
      expect(coffre.valeur, 'cga_session=S-abc');
    },
  );
}
