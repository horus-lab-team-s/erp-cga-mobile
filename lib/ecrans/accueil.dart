import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../api/remise.dart';
import '../domaine/depot.dart';
import '../domaine/file_d_attente.dart';
import '../domaine/prise_de_vue.dart';

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
    required this.priseDeVue,
    required this.quandDeconnecte,
  });

  final ClientApi client;
  final FileDAttente file;
  final PriseDeVue priseDeVue;
  final VoidCallback quandDeconnecte;

  @override
  State<EcranAccueil> createState() => _EtatDeLAccueil();
}

class _EtatDeLAccueil extends State<EcranAccueil> {
  List<Depot> _enAttente = const [];
  List<Depot> _refuses = const [];
  bool _envoiEnCours = false;
  List<String> _dossiers = const [];

  @override
  void initState() {
    super.initState();
    _relire();
    _lireLesDossiers();
  }

  Future<void> _lireLesDossiers() async {
    List<String> dossiers;
    try {
      dossiers = await widget.client.mesDossiers();
    } on Object {
      // Sans réseau au lancement, on ne connaît pas encore les dossiers. Le
      // bouton reste inactif, et un message le dit plutôt que de laisser
      // l'adhérent appuyer sur un déclencheur qui ne répond pas.
      dossiers = const [];
    }
    if (!mounted) return;
    setState(() => _dossiers = dossiers);
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

  Future<void> _photographier() async {
    final dossier = await _quelDossier();
    if (dossier == null || !mounted) return;
    final depot = await widget.priseDeVue.pour(dossier);
    if (!mounted) return;
    if (depot == null) {
      // ⚠️ Renoncer n'est pas une erreur, et n'appelle aucun message. On ferme
      // l'appareil photo par réflexe bien plus souvent qu'on ne le croit.
      return;
    }
    await _relire();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enregistrée. Elle partira toute seule.')),
    );
  }

  /// Le dossier auquel rattacher la pièce.
  ///
  /// ⚠️ On ne demande RIEN quand il n'y en a qu'un, et c'est le cas de presque
  /// tous les adhérents. Une question dont la réponse est forcée est une étape
  /// de plus entre la facture en main et la photo prise.
  Future<String?> _quelDossier() async {
    if (_dossiers.length == 1) {
      return _dossiers.single;
    }
    if (_dossiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Aucun dossier ouvert à votre nom. Voyez avec le cabinet.",
          ),
        ),
      );
      return null;
    }
    return showDialog<String>(
      context: context,
      builder: (contexte) => SimpleDialog(
        title: const Text('Pour quelle entreprise ?'),
        children: [
          for (final d in _dossiers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(contexte, d),
              child: Text(d),
            ),
        ],
      ),
    );
  }

  /// Tente de vider la file, et rend compte de ce qui s'est passé.
  ///
  /// ⚠️ **LE CAS DE LA SESSION EXPIRÉE EST LE SEUL QUI CHANGE D'ÉCRAN.** Sans
  /// lui, l'adhérent voyait « 0 pièce envoyée » sans savoir pourquoi, et
  /// réappuyait indéfiniment sur un bouton qui ne pouvait pas marcher.
  Future<void> _envoyer() async {
    setState(() => _envoiEnCours = true);
    final vidage = await widget.file.vider(Remise(widget.client).remettre);
    if (!mounted) return;
    setState(() => _envoiEnCours = false);
    // ⚠️ APRÈS le vidage. Une copie effacée avant l'accusé de réception perd la
    // pièce si la réponse se perd en route ; une copie qui reste après remplit
    // le téléphone en quelques semaines.
    await widget.priseDeVue.effacerLesCopiesDevenuesInutiles();
    await _relire();
    if (!mounted) return;
    if (vidage.sessionAExpire) {
      // Rien n'est perdu : la file garde ses pièces, sans tentative comptée.
      widget.quandDeconnecte();
      return;
    }
    final reste = _enAttente.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch ((vidage.remis, reste)) {
          (0, 0) => 'Rien à envoyer.',
          (0, _) => "Pas de réseau. Vos pièces partiront dès qu'il revient.",
          (final n, 0) =>
            '$n pièce${n > 1 ? "s" : ""} envoyée${n > 1 ? "s" : ""}.',
          (final n, final r) => '$n envoyée${n > 1 ? "s" : ""}, $r en attente.',
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes justificatifs'),
        actions: [
          IconButton(
            onPressed: _envoiEnCours || _enAttente.isEmpty ? null : _envoyer,
            icon: _envoiEnCours
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Envoyer maintenant',
          ),
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
        onPressed: _photographier,
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
