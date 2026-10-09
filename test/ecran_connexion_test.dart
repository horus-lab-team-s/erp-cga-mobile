import 'dart:async';

import 'package:cga_mobile/ecrans/connexion.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/domaine/document_recu.dart';
import 'package:cga_mobile/domaine/echeance.dart';
import 'package:cga_mobile/domaine/mon_entreprise.dart';
import 'package:cga_mobile/domaine/preuve.dart';
import 'package:cga_mobile/domaine/piece_remise.dart';
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

  @override
  Future<Historique> mesPieces(String dossier) async => const Historique();

  /// ⚠️ La doublure rend un échéancier VIDE : ces cas-ci ne portent pas sur les
  /// échéances, qui ont leur propre fichier.
  @override
  Future<Echeancier> mesEcheances(String dossier) async => const Echeancier();

  @override
  Future<Preuve> envoyerLaPreuve({
    required String dossier,
    required Echeance echeance,
    required String cheminDeLaPhoto,
  }) async => Preuve.recue;

  @override
  Future<Fiche> monEntreprise(String dossier) async => const Fiche();

  @override
  Future<SortDuSignalement> signalerUnChangement({
    required String dossier,
    required String nature,
    required String message,
  }) async => SortDuSignalement.transmis;

  @override
  Future<Documents> mesDocuments(String dossier) async => const Documents();
}

class SocketExceptionFeinte implements Exception {
  const SocketExceptionFeinte();
}

void main() {
  Future<void> poser(
    WidgetTester testeur,
    SessionFeinte session, {
    VoidCallback? quandConnecte,
    VoidCallback? quandRetour,
  }) async {
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranDeConnexion(
          session: session,
          quandConnecte: quandConnecte ?? () {},
          quandRetour: quandRetour,
        ),
      ),
    );
  }

  group("Revenir à l'offre", () {
    // ─────────────────────────────────────────────────────────────────────────
    // ⚠️ « SE CONNECTER » ÉTAIT UNE PORTE QUI SE REFERME.
    //
    // L'application s'ouvre sur le catalogue depuis qu'elle a un côté public.
    // Un visiteur qui touchait « Se connecter » par curiosité arrivait devant
    // le mur de connexion SANS AUCUN MOYEN DE REVENIR : l'écran est substitué
    // à l'offre et non empilé dessus, donc ni flèche ni bouton système ne le
    // ramenaient. Il fallait tuer l'application.
    //
    // C'est exactement le mur que le côté public venait de supprimer.
    // ─────────────────────────────────────────────────────────────────────────

    testWidgets('la flèche ramène au catalogue', (testeur) async {
      var revenu = false;
      await poser(testeur, SessionFeinte(), quandRetour: () => revenu = true);

      await testeur.tap(find.byKey(const Key('retour-a-l-offre')));
      await testeur.pumpAndSettle();

      expect(revenu, isTrue);
    });

    testWidgets('le bouton « retour » du téléphone fait la même chose', (
      testeur,
    ) async {
      // ⚠️ Sur Android, c'est le geste que tout le monde essaie en premier.
      // S'il ferme l'application au lieu de revenir, le visiteur croit s'être
      // trompé d'application.
      var revenu = false;
      await poser(testeur, SessionFeinte(), quandRetour: () => revenu = true);

      await testeur.binding.handlePopRoute();
      await testeur.pumpAndSettle();

      expect(revenu, isTrue);
    });

    testWidgets('pas de flèche quand il n\'y a rien derrière', (testeur) async {
      // Le cas d'une session expirée alors que l'adhérent était déjà entré :
      // une flèche y promettrait un écran qui n'existe plus.
      await poser(testeur, SessionFeinte());
      expect(find.byKey(const Key('retour-a-l-offre')), findsNothing);
    });
  });

  group("Ce que l'écran montre avant toute saisie", () {
    testWidgets('le logo du cabinet, et non un titre écrit', (testeur) async {
      await poser(testeur, SessionFeinte());

      // ⚠️ Par son étiquette, et non « la seule image de l'écran » : l'écran
      // porte aussi une photographie, décorative, qu'un lecteur d'écran ne
      // lit pas.
      final logo = testeur.widget<Image>(
        find.byWidgetPredicate(
          (w) => w is Image && (w.semanticLabel ?? '').contains('CGA'),
        ),
      );
      expect(
        (logo.image as AssetImage).assetName,
        Marque.logoBlanc,
        reason:
            "un adhérent doit reconnaître SON cabinet avant de taper un "
            'mot de passe, pas lire un nom en toutes lettres',
      );
      expect(logo.semanticLabel, contains('CGA Broad Range'));
    });

    testWidgets("une seule action principale, et c'est « Se connecter »", (
      testeur,
    ) async {
      await poser(testeur, SessionFeinte(), quandRetour: () {});

      // ⚠️ Le § 10.7 veut UNE action principale par vue. Deux boutons pleins,
      // et plus aucun ne se détache. « Découvrir l'offre » est à contour.
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);
    });

    testWidgets('la phrase qui protège du faux conseiller', (testeur) async {
      // ⚠️ Recopiée de la vitrine. Elle doit être SUR l'écran où l'on tape le
      // mot de passe, pas dans une page d'aide que personne n'ouvre.
      await poser(testeur, SessionFeinte());
      expect(
        find.textContaining('ne vous demandera jamais votre mot de passe'),
        findsOneWidget,
      );
    });

    testWidgets('la photographie est muette pour un lecteur d\'écran', (
      testeur,
    ) async {
      await poser(testeur, SessionFeinte());
      final photo = testeur.widget<Image>(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName.contains('photos/'),
        ),
      );
      expect(photo.excludeFromSemantics, isTrue);
    });
  });

  group('Mot de passe oublié', () {
    Future<List<String>> ouvrir(
      WidgetTester testeur, {
      bool accepte = true,
    }) async {
      final demandes = <String>[];
      await testeur.pumpWidget(
        MaterialApp(
          theme: themeClair(),
          home: EcranDeConnexion(
            session: SessionFeinte(),
            quandConnecte: () {},
            demanderUnLien: (c) async {
              demandes.add(c);
              return accepte;
            },
          ),
        ),
      );
      await testeur.enterText(
        find.byKey(const Key('champ-courriel')),
        'jp.nkoa@batimentplus.cm',
      );
      await testeur.tap(find.byKey(const Key('mot-de-passe-oublie')));
      await testeur.pumpAndSettle();
      return demandes;
    }

    testWidgets("reprend l'adresse déjà tapée, et demande le lien", (
      testeur,
    ) async {
      final demandes = await ouvrir(testeur);
      // ⚠️ Inutile de la redemander : l'adhérent vient de la taper.
      expect(
        testeur
            .widget<TextField>(find.byKey(const Key('champ-oubli')))
            .controller!
            .text,
        'jp.nkoa@batimentplus.cm',
      );
      await testeur.tap(find.byKey(const Key('oubli-envoyer')));
      await testeur.pumpAndSettle();
      expect(demandes, ['jp.nkoa@batimentplus.cm']);
    });

    testWidgets('ne prétend JAMAIS qu\'un lien est parti', (testeur) async {
      // ⚠️ Le serveur répond « pris » même pour une adresse inconnue, pour ne
      // pas révéler qui est client. « Un lien vous a été envoyé » serait faux
      // une fois sur deux.
      await ouvrir(testeur);
      await testeur.tap(find.byKey(const Key('oubli-envoyer')));
      await testeur.pumpAndSettle();
      expect(find.byKey(const Key('oubli-pris')), findsOneWidget);
      expect(find.textContaining('Si un compte est ouvert'), findsOneWidget);
      expect(find.textContaining('vous a été envoyé'), findsNothing);
    });

    testWidgets('sans réseau, le dit, et laisse réessayer', (testeur) async {
      await ouvrir(testeur, accepte: false);
      await testeur.tap(find.byKey(const Key('oubli-envoyer')));
      await testeur.pumpAndSettle();
      expect(find.byKey(const Key('oubli-echec')), findsOneWidget);
      expect(find.byKey(const Key('oubli-pris')), findsNothing);
      expect(find.byKey(const Key('oubli-envoyer')), findsOneWidget);
    });

    testWidgets('mène aussi à une personne, si rien n\'arrive', (
      testeur,
    ) async {
      // Sans demande de lien branchée, la feuille ne montre que les moyens
      // de joindre le chargé de clientèle : aucun champ qui ne mènerait à
      // rien.
      await poser(testeur, SessionFeinte());
      await testeur.tap(find.byKey(const Key('mot-de-passe-oublie')));
      await testeur.pumpAndSettle();

      expect(find.byKey(const Key('aide-oubli')), findsOneWidget);
      expect(find.byKey(const Key('oubli-whatsapp')), findsOneWidget);
      expect(find.byKey(const Key('oubli-appeler')), findsOneWidget);
      // Aucun champ de saisie dans la feuille : seulement les deux du
      // formulaire de connexion, derrière.
      expect(find.byType(TextField), findsNWidgets(2));
    });
  });

  group('Pas encore adhérent', () {
    testWidgets("mène à l'offre quand il y en a une derrière", (testeur) async {
      var revenu = false;
      await poser(testeur, SessionFeinte(), quandRetour: () => revenu = true);
      // `ensureVisible` et non `scrollUntilVisible` : chaque champ de saisie
      // porte son propre défileur, et ce dernier ne sait plus lequel choisir.
      await testeur.ensureVisible(find.byKey(const Key('voir-l-offre')));
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('voir-l-offre')));
      expect(revenu, isTrue);
    });

    testWidgets("se tait quand il n'y a pas d'offre derrière", (testeur) async {
      await poser(testeur, SessionFeinte());
      expect(find.byKey(const Key('voir-l-offre')), findsNothing);
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

  @override
  Future<Historique> mesPieces(String dossier) async => const Historique();

  /// ⚠️ La doublure rend un échéancier VIDE : ces cas-ci ne portent pas sur les
  /// échéances, qui ont leur propre fichier.
  @override
  Future<Echeancier> mesEcheances(String dossier) async => const Echeancier();

  @override
  Future<Preuve> envoyerLaPreuve({
    required String dossier,
    required Echeance echeance,
    required String cheminDeLaPhoto,
  }) async => Preuve.recue;

  @override
  Future<Fiche> monEntreprise(String dossier) async => const Fiche();

  @override
  Future<SortDuSignalement> signalerUnChangement({
    required String dossier,
    required String nature,
    required String message,
  }) async => SortDuSignalement.transmis;

  @override
  Future<Documents> mesDocuments(String dossier) async => const Documents();
}
