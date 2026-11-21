import 'dart:async';

import 'package:cga_mobile/composants/actions.dart';
import 'package:cga_mobile/domaine/document_recu.dart';
import 'package:cga_mobile/domaine/echeance.dart';
import 'package:cga_mobile/domaine/mon_entreprise.dart';
import 'package:cga_mobile/domaine/piece_remise.dart';
import 'package:cga_mobile/domaine/preuve.dart';
import 'package:cga_mobile/ecrans/mon_entreprise.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/service_de_session.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CES CAS TIENNENT
///
/// ⚠️ Le cas le plus important de ce fichier n'est pas l'affichage de la fiche :
/// c'est que l'écran ne laisse JAMAIS croire qu'un signalement modifie le
/// dossier. Le serveur est formel : c'est une parole datée au journal, et le
/// cabinet instruit.
///
/// Un adhérent qui déménage, signale sa nouvelle adresse et croit son dossier à
/// jour continuerait de recevoir ses avis à l'ancienne, et manquerait ses
/// échéances.
/// ─────────────────────────────────────────────────────────────────────────────

class SessionFeinte implements ServiceDeSession {
  SessionFeinte({this.fiche = const Fiche()});

  Fiche fiche;
  SortDuSignalement sort = SortDuSignalement.transmis;
  final List<({String nature, String message})> signalements = [];

  /// Posée : l'envoi reste en route tant que le test ne la complète pas.
  Completer<SortDuSignalement>? attente;

  @override
  Future<bool> ouvrirUneSession(String c, String m) async => true;
  @override
  Future<void> fermerLaSession() async {}
  @override
  Future<List<String>> mesDossiers() async => const ['M081234567890P'];
  @override
  Future<Historique> mesPieces(String d) async => const Historique();
  @override
  Future<Echeancier> mesEcheances(String d) async => const Echeancier();
  @override
  Future<Preuve> envoyerLaPreuve({
    required String dossier,
    required Echeance echeance,
    required String cheminDeLaPhoto,
  }) async => Preuve.recue;

  @override
  Future<Fiche> monEntreprise(String dossier) async => fiche;

  @override
  Future<SortDuSignalement> signalerUnChangement({
    required String dossier,
    required String nature,
    required String message,
  }) async {
    signalements.add((nature: nature, message: message));
    final a = attente;
    return a == null ? sort : a.future;
  }

  @override
  Future<Documents> mesDocuments(String dossier) async => const Documents();
}

MonEntreprise entreprise({List<Signalement> signalements = const []}) =>
    MonEntreprise.depuisJson({
      'niu': 'M081234567890P',
      'denomination': 'SARL BATIMENT PLUS',
      'forme': 'Société à responsabilité limitée',
      'activite': 'Construction de bâtiments',
      'rccm': 'RC/DLA/2021/B/0977',
      'siege': 'Bonabéri, Douala IV',
      'centre': 'Centre divisionnaire des impôts',
      'regime': {
        'code': 'REEL',
        'titre': 'Régime du réel',
        'explication': 'Vous facturez la TVA à vos clients et la reversez.',
        'depuis': '2022-06-01',
      },
      'assujettie_tva': true,
      'adhesion_numero': 'ADH-2022-014',
      'adherente_depuis': '2022-06-01',
      'dirigeants': [
        {'nom': 'NKOA Jean-Pierre', 'qualite': 'Gérant'},
      ],
      'interlocuteur': {
        'nom': 'Patricia MOUKOURI',
        'role': 'CHARGE_CLIENTELE',
        'courriel': 'p.moukouri@cga-brcg.cm',
        'telephone': null,
      },
      'natures': [
        {
          'nature': 'ADRESSE',
          'libelle': 'Adresse',
          'aide': 'Une nouvelle adresse peut changer votre centre des impôts.',
        },
        {
          'nature': 'AUTRE',
          'libelle': 'Autre changement',
          'aide': 'Décrivez le changement : le cabinet vous contacte.',
        },
      ],
      'signalements': [
        for (final s in signalements)
          {
            'nature': 'ADRESSE',
            'libelle': s.libelle,
            'message': s.message,
            'le': s.le,
          },
      ],
    });

void main() {
  // ⚠️ Une surface HAUTE, et c'est nécessaire. Le cadre d'essai fait 800 × 600
  // par défaut : la fiche est plus longue, et tout ce qui passe sous la ligne
  // de flottaison n'est pas construit par la liste. Les cas échouaient alors
  // sur « aucun widget trouvé » pour du texte qui existe bel et bien.
  setUp(() {
    final vue =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    vue.physicalSize = const Size(1000, 3000);
    vue.devicePixelRatio = 1.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
  });

  Future<SessionFeinte> poser(
    WidgetTester testeur, {
    Fiche fiche = const Fiche(),
    VoidCallback? quandSessionExpire,
  }) async {
    final s = SessionFeinte(fiche: fiche);
    await testeur.pumpWidget(
      MaterialApp(
        theme: themeClair(),
        home: EcranMonEntreprise(
          session: s,
          dossier: 'M081234567890P',
          quandSessionExpire: quandSessionExpire ?? () {},
        ),
      ),
    );
    return s;
  }

  group('La fiche', () {
    testWidgets('montre le régime, qui est la formule d\'adhésion', (
      testeur,
    ) async {
      await poser(testeur, fiche: Fiche(entreprise: entreprise()));
      await testeur.pumpAndSettle();

      expect(find.text('SARL BATIMENT PLUS'), findsOneWidget);
      expect(find.text('Régime du réel'), findsOneWidget);
      // ⚠️ CONSTATÉ SUR LE TECNO : la fiche affichait « Depuis 2022-06-01 »,
      // une date de base de données montrée telle quelle à un commerçant, alors
      // que l'écran des accusés disait « déposé le 15 mars 2024 ». Le même
      // produit parlait deux langues selon l'écran.
      // Deux occurrences : le régime et l'adhésion datent du même jour dans ce
      // jeu d'essai, et l'écran doit mettre les deux en français.
      expect(find.text('1er juin 2022'), findsNWidgets(2));
      expect(find.text('2022-06-01'), findsNothing);
      expect(find.textContaining('Vous facturez la TVA'), findsOneWidget);
      expect(find.text('Vous la facturez et la reversez'), findsOneWidget);
    });

    testWidgets('nomme l\'interlocuteur, avec son rôle en français', (
      testeur,
    ) async {
      // ⚠️ « CHARGE_CLIENTELE » ne veut rien dire à un commerçant. Et sur un
      // téléphone, savoir QUI appeler vaut mieux que tout le reste de la fiche.
      await poser(testeur, fiche: Fiche(entreprise: entreprise()));
      await testeur.pumpAndSettle();

      expect(find.text('Patricia MOUKOURI'), findsOneWidget);
      expect(find.text('Chargé de clientèle'), findsOneWidget);
      expect(find.text('CHARGE_CLIENTELE'), findsNothing);
    });

    testWidgets("se joint en un appui : appeler et écrire (19 octobre 2026)", (
      testeur,
    ) async {
      // Sans téléphone connu, pas de bouton d'appel ; le courriel reste joignable.
      await poser(testeur, fiche: Fiche(entreprise: entreprise()));
      await testeur.pumpAndSettle();

      expect(find.byKey(const Key('interlocuteur-courriel')), findsOneWidget);
      expect(find.byKey(const Key('interlocuteur-appeler')), findsNothing);
      expect(find.byKey(const Key('interlocuteur-whatsapp')), findsNothing);
    });
  });

  group('Signaler un changement', () {
    testWidgets('annonce que le dossier NE CHANGE PAS', (testeur) async {
      // ⚠️ LE CAS QUI COMPTE. Un signalement est une parole datée au journal.
      await poser(testeur, fiche: Fiche(entreprise: entreprise()));
      await testeur.pumpAndSettle();

      expect(
        find.textContaining('Votre dossier ne change pas'),
        findsOneWidget,
      );
    });

    testWidgets('choisit une nature, saisit, et envoie', (testeur) async {
      final session = await poser(
        testeur,
        fiche: Fiche(entreprise: entreprise()),
      );
      await testeur.pumpAndSettle();

      await testeur.tap(find.byKey(const Key('signaler-un-changement')));
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('nature-ADRESSE')));
      await testeur.pumpAndSettle();
      await testeur.enterText(
        find.byKey(const Key('message-du-signalement')),
        'Nous avons déménagé à Akwa.',
      );
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('envoyer-le-signalement')));
      await testeur.pumpAndSettle();

      expect(session.signalements.length, 1);
      expect(session.signalements.first.nature, 'ADRESSE');
      expect(
        find.textContaining('transmis à Patricia MOUKOURI'),
        findsOneWidget,
      );
      expect(
        find.textContaining('ne change pas tant que le cabinet'),
        findsOneWidget,
      );
    });

    testWidgets('un message trop court ne part pas', (testeur) async {
      // ⚠️ Cinq caractères au moins : c'est la borne du serveur, appliquée ici
      // pour qu'un envoi ne parte pas se faire refuser.
      final session = await poser(
        testeur,
        fiche: Fiche(entreprise: entreprise()),
      );
      await testeur.pumpAndSettle();

      await testeur.tap(find.byKey(const Key('signaler-un-changement')));
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('nature-ADRESSE')));
      await testeur.pumpAndSettle();
      await testeur.enterText(
        find.byKey(const Key('message-du-signalement')),
        'abc',
      );
      await testeur.pumpAndSettle();

      final bouton = testeur.widget<BoutonDAction>(
        find.byKey(const Key('envoyer-le-signalement')),
      );
      expect(bouton.surAppui, isNull);
      expect(session.signalements, isEmpty);
    });

    testWidgets(
      'l\'envoi se voit, et une panne garde le texte dans la boîte ouverte',
      (testeur) async {
        // ⚠️ 20 octobre 2026 : la boîte se fermait AVANT l'envoi. Rien ne disait
        // qu'il était en cours, et une panne perdait un message tapé lettre à
        // lettre.
        final session = await poser(
          testeur,
          fiche: Fiche(entreprise: entreprise()),
        );
        await testeur.pumpAndSettle();
        await testeur.tap(find.byKey(const Key('signaler-un-changement')));
        await testeur.pumpAndSettle();
        await testeur.tap(find.byKey(const Key('nature-ADRESSE')));
        await testeur.pumpAndSettle();
        await testeur.enterText(
          find.byKey(const Key('message-du-signalement')),
          'Nouvelle adresse : Bonapriso',
        );
        await testeur.pump();

        session.attente = Completer();
        await testeur.tap(find.byKey(const Key('envoyer-le-signalement')));
        await testeur.pump();
        expect(find.text('Envoi…'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        session.attente!.complete(SortDuSignalement.indisponible);
        await testeur.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byKey(const Key('echec-du-signalement')), findsOneWidget);
        expect(find.text('Nouvelle adresse : Bonapriso'), findsOneWidget);

        // Le réseau revient : « Réessayer » repart avec le même texte.
        session.attente = null;
        await testeur.tap(find.text('Réessayer'));
        await testeur.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          session.signalements.last.message,
          'Nouvelle adresse : Bonapriso',
        );
      },
    );

    testWidgets('un « Annuler » de travers ne jette pas le texte', (
      testeur,
    ) async {
      await poser(testeur, fiche: Fiche(entreprise: entreprise()));
      await testeur.pumpAndSettle();
      Future<void> ouvrir() async {
        await testeur.tap(find.byKey(const Key('signaler-un-changement')));
        await testeur.pumpAndSettle();
        await testeur.tap(find.byKey(const Key('nature-ADRESSE')));
        await testeur.pumpAndSettle();
      }

      await ouvrir();
      await testeur.enterText(
        find.byKey(const Key('message-du-signalement')),
        'Nous avons déménagé',
      );
      await testeur.tap(find.text('Annuler'));
      await testeur.pumpAndSettle();
      await ouvrir();

      expect(find.text('Nous avons déménagé'), findsOneWidget);
    });

    testWidgets('un double appui n\'est pas présenté comme un échec', (
      testeur,
    ) async {
      // ⚠️ Le serveur refuse le même signalement le même jour. Le présenter
      // comme une panne ferait recommencer, ou appeler pour rien, quelqu'un
      // dont le cabinet est DÉJÀ prévenu.
      final session = await poser(
        testeur,
        fiche: Fiche(entreprise: entreprise()),
      );
      session.sort = SortDuSignalement.dejaSignale;
      await testeur.pumpAndSettle();

      await testeur.tap(find.byKey(const Key('signaler-un-changement')));
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('nature-AUTRE')));
      await testeur.pumpAndSettle();
      await testeur.enterText(
        find.byKey(const Key('message-du-signalement')),
        'Changement de numéro',
      );
      await testeur.pumpAndSettle();
      await testeur.tap(find.byKey(const Key('envoyer-le-signalement')));
      await testeur.pumpAndSettle();

      expect(find.textContaining('Le cabinet est prévenu'), findsOneWidget);
      expect(find.textContaining('inutile de recommencer'), findsOneWidget);
    });
  });

  testWidgets('Pas de réseau ne se dit pas « aucune fiche »', (testeur) async {
    await poser(testeur, fiche: const Fiche(serveurJoignable: false));
    await testeur.pumpAndSettle();

    expect(find.text('Pas de réseau'), findsOneWidget);
    expect(find.text('Aucune fiche'), findsNothing);
  });
}
