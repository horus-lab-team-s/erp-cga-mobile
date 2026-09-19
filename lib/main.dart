import 'package:flutter/material.dart';

import 'adaptateurs/magasin_memoire.dart';
import 'api/client_api.dart';
import 'domaine/file_d_attente.dart';
import 'ecrans/accueil.dart';
import 'ecrans/connexion.dart';

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
/// ⚠️ Le magasin est ici EN MÉMOIRE. La file ne survit donc pas encore à la
/// fermeture de l'application, ce qui est exactement ce qu'il faut corriger en
/// premier. Voir la feuille de route du README.
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
  late final FileDAttente _file = FileDAttente(MagasinEnMemoire());
  bool _connecte = false;

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
      theme: ThemeData(
        // Le vert du produit, celui du document de conception et de la vitrine.
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E9463)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF34D399),
          brightness: Brightness.dark,
        ),
      ),
      home: _connecte
          ? EcranAccueil(
              client: _client,
              file: _file,
              quandDeconnecte: () => setState(() => _connecte = false),
            )
          : EcranDeConnexion(
              client: _client,
              quandConnecte: () => setState(() => _connecte = true),
            ),
    );
  }
}
