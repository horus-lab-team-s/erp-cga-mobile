import 'dart:io';

import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';

import 'adaptateurs/appareil_photo_systeme.dart';
import 'adaptateurs/magasin_fichier.dart';
import 'api/client_api.dart';
import 'api/remise.dart';
import 'domaine/file_d_attente.dart';
import 'domaine/prise_de_vue.dart';
import 'marque.dart';
import 'ecrans/coquille.dart';
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
  late final ClientApi _client = ClientApi(
    base: Uri.parse(ClientApi.adresseParDefaut),
  );
  FileDAttente? _file;
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
      _priseDeVue = PriseDeVue(
        appareil: AppareilPhotoDuSysteme(),
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
      title: 'CGA Broad Range',
      debugShowCheckedModeBanner: false,
      // ⚠️ LES COULEURS VIENNENT DU LOGO DU CABINET, pas d'une graine choisie
      // au jugé. L'application était verte : le vert ne figure nulle part dans
      // la marque. Voir `marque.dart`, qui traduit les jetons du web.
      theme: themeClair(),
      darkTheme: themeSombre(),
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
        ),
        (_, false) => EcranDeConnexion(
          session: _client,
          quandConnecte: () => setState(() => _connecte = true),
        ),
      },
    );
  }
}
