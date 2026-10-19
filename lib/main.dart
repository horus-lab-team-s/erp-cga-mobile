import 'dart:io';

import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';

import 'adaptateurs/appareil_photo_systeme.dart';
import 'adaptateurs/magasin_fichier.dart';
import 'adaptateurs/memoire_des_dossiers_fichier.dart';
import 'api/client_api.dart';
import 'api/remise.dart';
import 'domaine/file_d_attente.dart';
import 'domaine/prise_de_vue.dart';
import 'ports/memoire_des_dossiers.dart';
import 'marque.dart';
import 'ecrans/coquille.dart';
import 'ecrans/offre.dart';
import 'ecrans/souscrire.dart';
import 'ecrans/connexion.dart';
import 'ecrans/ouverture.dart';

/// L'application de terrain de l'adhérent.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CETTE APPLICATION EST, ET CE QU'ELLE N'EST PAS
///
/// Elle n'est pas la console en petit. Le collaborateur du cabinet travaille sur
/// un écran large, avec un clavier et du réseau ; l'adhérent est dans sa boutique
/// avec une facture en main. Les deux n'ont pas le même métier, et un produit qui
/// réduit l'un à l'autre rend les deux mauvais.
///
/// Ce qu'elle fait, et qui ne peut se faire ailleurs : photographier une pièce,
/// l'enregistrer sur l'appareil, et la faire partir quand le réseau revient.
///
/// ⚠️ LE MAGASIN EST DURABLE, ET IL EST CHOISI ICI, UNE SEULE FOIS.
///
/// C'est le seul endroit du programme qui sache où l'appareil range ses
/// documents. Tout le reste — la file, sa règle de renvoi, les écrans — parle à
/// un port et ignore qu'il y a un disque derrière. C'est ce qui permet
/// d'éprouver la règle sur un poste, dans un dossier temporaire, sans émulateur.
/// ─────────────────────────────────────────────────────────────────────────────
void main() {
  runApp(const ApplicationCga());
}

class ApplicationCga extends StatefulWidget {
  const ApplicationCga({super.key});

  @override
  State<ApplicationCga> createState() => _EtatDeLApplication();
}

class _EtatDeLApplication extends State<ApplicationCga> {
  /// Vrai quand le visiteur a demandé la connexion. ⚠️ Distinct de
  /// `_connecte` : on peut vouloir entrer sans y être encore.
  bool _veutSeConnecter = false;

  final _navigateur = GlobalKey<NavigatorState>();

  late final ClientApi _client = ClientApi(
    base: Uri.parse(ClientApi.adresseParDefaut),
  );
  FileDAttente? _file;
  MemoireDesDossiers? _memoire;
  PriseDeVue? _priseDeVue;
  bool _connecte = false;

  @override
  void initState() {
    super.initState();
    _ouvrirLaFile();
  }

  Future<void> _ouvrirLaFile() async {
    // ⚠️ `getApplicationDocumentsDirectory` et non un dossier de cache. Le
    // système vide les caches quand la place manque, et il le fait sans
    // prévenir : la file y aurait disparu précisément le jour où l'appareil
    // était plein, c'est-à-dire le jour où l'adhérent avait le plus de pièces
    // en attente.
    final dossier = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    final file = FileDAttente(MagasinDeFichier(dossier));
    setState(() {
      _file = file;
      _memoire = MemoireDesDossiersFichier(dossier);
      _priseDeVue = PriseDeVue(
        appareil: AppareilPhotoDuSysteme(),
        galerie: GalerieDuSysteme(),
        file: file,
        // ⚠️ Les copies de photos vivent À CÔTÉ de la file, dans le dossier des
        // documents, et non dans un cache. Le système vide les caches quand la
        // place manque : la file garderait alors le chemin de fichiers disparus,
        // et la remise les prendrait pour des pièces refusées.
        photos: Directory('${dossier.path}/photos'),
      );
    });
  }

  @override
  void dispose() {
    _client.fermer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ⚠️ Une clé de navigateur : l'écran de l'offre pousse la souscription
      // depuis un rappel qui n'a pas de contexte sous la main.
      navigatorKey: _navigateur,
      title: 'CGA Broad Range',
      debugShowCheckedModeBanner: false,
      // ⚠️ LES COULEURS VIENNENT DU LOGO DU CABINET, pas d'une graine choisie
      // au jugé. L'application était verte : le vert ne figure nulle part dans
      // la marque. Voir `marque.dart`, qui traduit les jetons du web.
      theme: themeClair(),
      // ⚠️ 18 octobre 2026 : LE THÈME CLAIR, MÊME QUAND LE TÉLÉPHONE EST EN MODE NUIT.
      // L'application suivait le système : sur un téléphone réglé en nuit, l'adhérent
      // la voyait toute sombre, cartes violettes sur fond noir, et le cabinet l'a
      // jugée « vraiment moche ». L'espace adhérent web est clair et doux ; le mobile
      // lui ressemble désormais. Le thème sombre reste dans `marque.dart`, inemployé.
      themeMode: ThemeMode.light,
      home: switch ((_file, _connecte)) {
        // Le temps d'ouvrir la file. C'est immédiat en pratique, mais rendre
        // l'accueil avant qu'elle existe afficherait « rien en attente » à
        // quelqu'un qui a vingt pièces en attente.
        // ⚠️ Pas une roue grise sur fond nu : voir `EcranDOuverture`. Entre le
        // démarrage indigo d'Android et le bandeau indigo de la connexion, une
        // page blanche faisait un éclair à chaque ouverture.
        (null, _) => const EcranDOuverture(),
        // ⚠️ La coquille, et non l'accueil seul : c'est elle qui porte la
        // barre de navigation et lit les dossiers une fois pour les trois
        // écrans.
        (final FileDAttente file, true) => Coquille(
          session: _client,
          file: file,
          priseDeVue: _priseDeVue!,
          remettre: Remise(_client).remettre,
          quandDeconnecte: () => setState(() => _connecte = false),
          tableau: _client,
          fichiers: _client,
          espace: _client,
          memoire: _memoire,
        ),
        // ⚠️ L'APPLICATION NE S'OUVRE PLUS SUR UN MUR DE CONNEXION.
        //
        // Elle commençait par demander des identifiants. Or le compte NAÎT de
        // la souscription réglée : le cabinet envoie le lien d'accès une fois
        // le paiement validé. Exiger un compte pour voir l'offre demandait
        // d'avoir acheté pour savoir ce qu'on achète.
        //
        // Un visiteur voit donc d'abord ce que le cabinet propose, et peut
        // souscrire sans compte — le serveur l'a toujours permis, ces routes
        // sont publiques. La connexion reste à un geste, dans la barre.
        (_, false) when _veutSeConnecter => EcranDeConnexion(
          session: _client,
          quandConnecte: () => setState(() => _connecte = true),
          // ⚠️ Le chemin du retour. Sans lui, « Se connecter » était une porte
          // qui se referme : l'écran est SUBSTITUÉ à l'offre, pas empilé
          // dessus, donc ni flèche ni bouton système ne ramenaient en arrière.
          quandRetour: () => setState(() => _veutSeConnecter = false),
          demanderUnLien: _client.demanderUnLienDeReinitialisation,
        ),
        (_, false) => EcranOffre(
          servicePublic: _client,
          quandSeConnecter: () => setState(() => _veutSeConnecter = true),
          quandSouscrire: (service) => _navigateur.currentState?.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  EcranSouscrire(servicePublic: _client, service: service),
            ),
          ),
        ),
      },
    );
  }
}
