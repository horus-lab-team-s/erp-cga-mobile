import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../domaine/depot.dart';
import '../domaine/file_d_attente.dart';

/// L'écran d'après la connexion : l'état de la file, et rien d'autre pour
/// l'instant.
///
/// ⚠️ **Ce que l'adhérent doit voir en premier, c'est ce qui n'est pas encore
/// parti.** C'est la seule information que l'application détient et que le
/// serveur ignore ; tout le reste, il peut l'ouvrir sur le site. Un accueil qui
/// montrerait d'abord un solde ou un tableau de bord copierait la console sur un
/// écran quatre fois plus petit, sans rien apporter.
class EcranAccueil extends StatefulWidget {
  const EcranAccueil({
    super.key,
    required this.client,
    required this.file,
    required this.quandDeconnecte,
  });

  final ClientApi client;
  final FileDAttente file;
  final VoidCallback quandDeconnecte;

  @override
  State<EcranAccueil> createState() => _EtatDeLAccueil();
}

class _EtatDeLAccueil extends State<EcranAccueil> {
  List<Depot> _enAttente = const [];
  List<Depot> _refuses = const [];

  @override
  void initState() {
    super.initState();
    _relire();
  }

  Future<void> _relire() async {
    final enAttente = await widget.file.enAttente();
    final refuses = await widget.file.refuses();
    if (!mounted) return;
    setState(() {
      _enAttente = enAttente;
      _refuses = refuses;
    });
  }

  Future<void> _sortir() async {
    await widget.client.fermerLaSession();
    widget.quandDeconnecte();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes justificatifs'),
        actions: [
          IconButton(
            onPressed: _sortir,
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _relire,
        child: ListView(
          children: [
            _Compteur(
              titre: 'En attente de remise',
              nombre: _enAttente.length,
              // ⚠️ Zéro en attente n'est pas un vide à cacher : c'est la bonne
              // nouvelle que l'adhérent est venu chercher.
              vide: 'Tout est parti.',
            ),
            _Compteur(
              titre: 'À reprendre',
              nombre: _refuses.length,
              vide: 'Rien à reprendre.',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // La prise de vue arrive avec l'appareil photo, point 2 de la feuille de
        // route. Le bouton existe déjà pour que la place qu'il prend soit
        // décidée avant, et non gagnée sur un écran déjà plein.
        onPressed: null,
        icon: const Icon(Icons.photo_camera),
        label: const Text('Photographier'),
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.titre,
    required this.nombre,
    required this.vide,
  });

  final String titre;
  final int nombre;
  final String vide;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(titre),
      subtitle: Text(nombre == 0 ? vide : '$nombre'),
      trailing: Text(
        '$nombre',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
