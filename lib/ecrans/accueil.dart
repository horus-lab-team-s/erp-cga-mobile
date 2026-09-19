import 'package:flutter/material.dart';

import '../domaine/depot.dart';
import '../ports/service_de_session.dart';
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
    required this.session,
    required this.file,
    required this.priseDeVue,
    required this.remettre,
    required this.quandDeconnecte,
  });

  final ServiceDeSession session;
  final FileDAttente file;
  final PriseDeVue priseDeVue;

  /// ⚠️ Une fonction, et non un objet `Remise`. L'écran n'a pas à savoir
  /// comment une pièce part : cela le rend vérifiable sans réseau, et c'est
  /// exactement ce qui manquait.
  final Future<Reponse> Function(Depot) remettre;

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
      dossiers = await widget.session.mesDossiers();
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
    await widget.session.fermerLaSession();
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
    final vidage = await widget.file.vider(widget.remettre);
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
    final couleurs = Theme.of(context).colorScheme;
    final prete = _dossiers.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes justificatifs'),
        actions: [
          IconButton(
            key: const Key('bouton-envoyer'),
            onPressed: _envoiEnCours || _enAttente.isEmpty ? null : _envoyer,
            icon: _envoiEnCours
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Envoyer maintenant',
          ),
          IconButton(
            key: const Key('bouton-sortir'),
            onPressed: _sortir,
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _relire,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            if (prete)
              _Bandeau(
                // ⚠️ Le dossier est écrit en toutes lettres. Un adhérent qui a
                // deux entreprises doit savoir sur laquelle il dépose AVANT de
                // photographier, pas après.
                texte: _dossiers.length == 1
                    ? 'Dossier ${_dossiers.single}'
                    : '${_dossiers.length} dossiers à votre nom',
                icone: Icons.business_outlined,
              )
            else
              _Bandeau(
                texte: "Aucun dossier connu pour l'instant.",
                icone: Icons.cloud_off_outlined,
                avertissement: true,
              ),
            const SizedBox(height: 20),
            _Compteur(
              cle: 'compteur-attente',
              titre: 'En attente de remise',
              nombre: _enAttente.length,
              // ⚠️ Zéro en attente n'est pas un vide à cacher : c'est la bonne
              // nouvelle que l'adhérent est venu chercher.
              vide: 'Tout est parti.',
              plein: 'Partiront dès que le réseau le permet.',
              icone: Icons.schedule_outlined,
              teinte: couleurs.secondaryContainer,
              surTeinte: couleurs.onSecondaryContainer,
            ),
            const SizedBox(height: 12),
            _Compteur(
              cle: 'compteur-reprendre',
              titre: 'À reprendre',
              nombre: _refuses.length,
              vide: 'Rien à reprendre.',
              plein: 'Le cabinet ne les a pas prises. À rephotographier.',
              icone: Icons.replay_outlined,
              teinte: _refuses.isEmpty
                  ? couleurs.surfaceContainer
                  : couleurs.errorContainer,
              surTeinte: _refuses.isEmpty
                  ? couleurs.onSurfaceVariant
                  : couleurs.onErrorContainer,
            ),
          ],
        ),
      ),
      // ⚠️ UN BOUTON ROND, SANS ÉTIQUETTE. Le geste est le seul de l'écran, et
      // une caméra se reconnaît sans qu'on l'écrive. Le mot « Photographier »
      // allongeait le bouton jusqu'au tiers de la largeur pour ne rien
      // apprendre, et couvrait la deuxième carte dès qu'une pièce attendait.
      //
      // ⚠️ L'infobulle et l'étiquette de lecture d'écran RESTENT : ce qui est
      // évident à l'œil ne l'est pas à l'oreille.
      // ⚠️ La taille ORDINAIRE, 56 points, et non la grande de 96.
      //
      // La grande était choisie pour appuyer l'importance du geste. À l'écran
      // elle faisait l'inverse : un disque d'un quart de la largeur, qui tirait
      // l'œil avant les compteurs et couvrait la seconde carte dès qu'une pièce
      // attendait. 56 points restent bien au-dessus de la cible minimale de 48,
      // donc tenables d'une main occupée, sans écraser la page.
      floatingActionButton: FloatingActionButton(
        key: const Key('bouton-photographier'),
        onPressed: prete ? _photographier : null,
        backgroundColor: prete ? couleurs.primary : couleurs.surfaceContainer,
        foregroundColor: prete ? couleurs.onPrimary : couleurs.onSurfaceVariant,
        tooltip: 'Photographier une pièce',
        shape: const CircleBorder(),
        child: const Icon(Icons.photo_camera_rounded, size: 26),
      ),
    );
  }
}

/// Une ligne d'information, sobre, en tête d'écran.
class _Bandeau extends StatelessWidget {
  const _Bandeau({
    required this.texte,
    required this.icone,
    this.avertissement = false,
  });

  final String texte;
  final IconData icone;
  final bool avertissement;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final fond = avertissement
        ? couleurs.errorContainer
        : couleurs.secondaryContainer;
    final encre = avertissement
        ? couleurs.onErrorContainer
        : couleurs.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icone, size: 19, color: encre),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texte,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: encre,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un compte, et ce qu'il veut dire.
///
/// ⚠️ Le nombre ne se suffit pas. « 3 » sous « À reprendre » ne dit pas quoi
/// faire ; « Le cabinet ne les a pas prises. À rephotographier. » le dit. Et
/// l'écart entre zéro et le reste se lit aussi à la teinte du cadre, jamais à
/// elle seule.
class _Compteur extends StatelessWidget {
  const _Compteur({
    required this.cle,
    required this.titre,
    required this.nombre,
    required this.vide,
    required this.plein,
    required this.icone,
    required this.teinte,
    required this.surTeinte,
  });

  final String cle;
  final String titre;
  final int nombre;
  final String vide;
  final String plein;
  final IconData icone;
  final Color teinte;
  final Color surTeinte;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Card(
      key: Key(cle),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: teinte,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, size: 22, color: surTeinte),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: couleurs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    nombre == 0 ? vide : plein,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: couleurs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$nombre',
              key: Key('$cle-nombre'),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: nombre == 0 ? couleurs.onSurfaceVariant : surTeinte,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
