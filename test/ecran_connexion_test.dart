import 'dart:async';

import 'package:cga_mobile/ecrans/connexion.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/service_de_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// Tout ce que l'adhérent TOUCHE sur le premier écran. Rien de cela n'était
/// vérifié : les trente-cinq cas précédents portaient sur la file, la remise et
/// le magasin, c'est-à-dire sur ce qu'il ne voit jamais.
///
/// ⚠️ Un écran non vérifié ne casse pas bruyamment. Il affiche « identifiants
/// incorrects » quand le réseau manque, laisse un bouton actif pendant un appel,
/// ou perd un message d'erreur derrière le clavier. Personne ne s'en aperçoit
/// avant un adhérent qui abandonne.
/// ─────────────────────────────────────────────────────────────────────────────

/// Une doublure du serveur : elle répond ce qu'on lui dit de répondre.
class SessionFeinte implements ServiceDeSession {
  SessionFeinte({this.reconnait = true, this.panne = false});

  final bool reconnait;
  final bool panne;
  final List<(String, String)> tentatives = [];
  bool fermee = false;

  @override
  Future<bool> ouvrirUneSession(String courriel, String motDePasse) async {
    tentatives.add((courriel, motDePasse));
    if (panne) throw const SocketExceptionFeinte();
    return reconnait;
  }

  @override
  Future<void> fermerLaSession() async => fermee = true;

  @override
  Future<List<String>> mesDossiers() async => const ['M081234567890P'];
}

class SocketExceptionFeinte implements Exception {
  const SocketExceptionFeinte();
}

void main() {
  Future<void> poser(
    WidgetTester testeur,
    SessionFeinte session, {
    VoidCallback? quandConnecte,
  }) async {
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranDeConnexion(
          session: session,
          quandConnecte: quandConnecte ?? () {},
        ),
      ),
    );
  }

  group("Ce que l'écran montre avant toute saisie", () {
    testWidgets('le logo du cabinet, et non un titre écrit', (testeur) async {
      await poser(testeur, SessionFeinte());

      final logo = testeur.widget<Image>(find.byType(Image));
      expect(
        (logo.image as AssetImage).assetName,
        Marque.logoBlanc,
        reason:
            "un adhérent doit reconnaître SON cabinet avant de taper un "
            'mot de passe, pas lire un nom en toutes lettres',
      );
      expect(logo.semanticLabel, contains('CGA Broad Range'));
    });

    testWidgets("une seule action principale, et c'est « Entrer »", (
      testeur,
    ) async {
      await poser(testeur, SessionFeinte());

      // ⚠️ Le § 10.7 veut UNE action principale par vue. Deux boutons pleins,
      // et plus aucun ne se détache.
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Entrer'), findsOneWidget);
    });

    testWidgets('aucun message de refus tant que rien n\'a été tenté', (
      testeur,
    ) async {
      await poser(testeur, SessionFeinte());

      expect(find.byKey(const Key('message-erreur')), findsNothing);
    });
  });

  group('Le mot de passe', () {
    testWidgets('est masqué par défaut, et se relit sur demande', (
      testeur,
    ) async {
      await poser(testeur, SessionFeinte());

      TextField champ() => testeur.widget<TextField>(
        find.byKey(const Key('champ-mot-de-passe')),
      );
      expect(champ().obscureText, isTrue);

      await testeur.tap(find.byKey(const Key('bascule-mot-de-passe')));
      await testeur.pump();

      expect(
        champ().obscureText,
        isFalse,
        reason:
            'un mot de passe de vingt-quatre caractères se tape sur un '
            'clavier de téléphone : sans moyen de le relire, on se trompe et '
            "on ne sait pas où",
      );
    });
  });

  group('Entrer', () {
    testWidgets('envoie ce qui a été saisi, sans les espaces du courriel', (
      testeur,
    ) async {
      final session = SessionFeinte();
      await poser(testeur, session);

      await testeur.enterText(
        find.byKey(const Key('champ-courriel')),
        '  jp.nkoa@batimentplus.cm ',
      );
      await testeur.enterText(
        find.byKey(const Key('champ-mot-de-passe')),
        'cabinet brcg douala 2026',
      );
      await testeur.tap(find.byKey(const Key('bouton-entrer')));
      await testeur.pump();

      expect(session.tentatives, [
        ('jp.nkoa@batimentplus.cm', 'cabinet brcg douala 2026'),
      ]);
    });

    testWidgets('prévient une fois reconnu', (testeur) async {
      var entre = false;
      await poser(testeur, SessionFeinte(), quandConnecte: () => entre = true);

      await testeur.tap(find.byKey(const Key('bouton-entrer')));
      await testeur.pumpAndSettle();

      expect(entre, isTrue);
    });

    testWidgets('dit le refus, et le dit en toutes lettres', (testeur) async {
      await poser(testeur, SessionFeinte(reconnait: false));

      await testeur.tap(find.byKey(const Key('bouton-entrer')));
      await testeur.pumpAndSettle();

      expect(find.text('Courriel ou mot de passe incorrect.'), findsOneWidget);
    });

    testWidgets("distingue l'absence de réseau d'un refus", (testeur) async {
      await poser(testeur, SessionFeinte(panne: true));

      await testeur.tap(find.byKey(const Key('bouton-entrer')));
      await testeur.pumpAndSettle();

      // ⚠️ Confondre les deux fait recommencer dix fois un adhérent qui ne
      // s'est pas trompé, et finir par demander une réinitialisation inutile.
      expect(find.textContaining("Le serveur n'a pas répondu"), findsOneWidget);
      expect(find.text('Courriel ou mot de passe incorrect.'), findsNothing);
    });

    testWidgets('se désactive pendant la tentative', (testeur) async {
      final attente = Completer<bool>();
      await testeur.pumpWidget(
        MaterialApp(
          theme: themeClair(),
          home: EcranDeConnexion(
            session: _SessionQuiAttend(attente),
            quandConnecte: () {},
          ),
        ),
      );

      await testeur.tap(find.byKey(const Key('bouton-entrer')));
      await testeur.pump();

      final bouton = testeur.widget<FilledButton>(
        find.byKey(const Key('bouton-entrer')),
      );
      expect(
        bouton.onPressed,
        isNull,
        reason:
            'deux appuis sur un réseau lent ouvrent deux sessions, et le '
            'limiteur du serveur refuse alors la seconde',
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      attente.complete(true);
      await testeur.pumpAndSettle();
    });
  });
}

class _SessionQuiAttend implements ServiceDeSession {
  _SessionQuiAttend(this.attente);

  final Completer<bool> attente;

  @override
  Future<bool> ouvrirUneSession(String c, String m) => attente.future;

  @override
  Future<void> fermerLaSession() async {}

  @override
  Future<List<String>> mesDossiers() async => const [];
}
