import 'dart:io';

import 'package:flutter/material.dart';

import '../domaine/depot.dart';
import '../ports/service_de_session.dart';
import '../domaine/file_d_attente.dart';
import '../domaine/prise_de_vue.dart';
import 'historique.dart';

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
          // ⚠️ L'HISTORIQUE EST À CÔTÉ DE L'ENVOI, ET NON DANS UN MENU.
          //
          // « Est-ce que je l'ai envoyée ? » est la deuxième question de
          // l'adhérent, juste après « est-ce que ça part ? ». L'enterrer sous
          // trois points la rendrait introuvable : sur un écran qui ne compte
          // que quatre gestes, un menu ne range rien, il cache.
          IconButton(
            key: const Key('bouton-historique'),
            onPressed: prete
                ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EcranHistorique(
                        session: widget.session,
                        dossiers: _dossiers,
                        // ⚠️ La déconnexion passe par le MÊME chemin que partout
                        // ailleurs. Une session expirée découverte depuis
                        // l'historique doit ramener à la connexion comme une
                        // session expirée découverte pendant un envoi : deux
                        // sorties différentes pour la même cause laisseraient
                        // l'application dans deux états qu'aucun écran ne sait
                        // montrer.
                        quandSessionExpire: widget.quandDeconnecte,
                      ),
                    ),
                  )
                : null,
            icon: const Icon(Icons.history),
            tooltip: 'Pièces déjà remises',
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            _Verdict(
              enAttente: _enAttente.length,
              aReprendre: _refuses.length,
              dossier: prete
                  ? (_dossiers.length == 1 ? _dossiers.single : null)
                  : null,
              sansDossier: !prete,
            ),
            if (_enAttente.isNotEmpty) ...[
              const SizedBox(height: 26),
              const _TitreDeSection(
                texte: 'En attente de remise',
                icone: Icons.schedule_outlined,
              ),
              const SizedBox(height: 10),
              for (final depot in _enAttente)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _Vignette(depot: depot),
                ),
            ],
            if (_refuses.isNotEmpty) ...[
              const SizedBox(height: 26),
              const _TitreDeSection(
                texte: 'À reprendre',
                icone: Icons.replay_outlined,
                alerte: true,
              ),
              const SizedBox(height: 10),
              for (final depot in _refuses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _Vignette(depot: depot, alerte: true),
                ),
            ],
          ],
        ),
      ),
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

/// La réponse à la seule question que l'adhérent se pose en ouvrant.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ DEUX COMPTEURS ÉGAUX NE RÉPONDAIENT À RIEN.
///
/// L'écran montrait « En attente : 0 » et « À reprendre : 0 », côte à côte, de
/// même taille. L'adhérent qui ouvre l'application en tenant une facture ne
/// vient pas lire un tableau de bord : il vient savoir **si ses pièces sont
/// parties**. Deux cartes de même poids l'obligent à lire les deux, puis à
/// conclure lui-même.
///
/// Une seule phrase, grande, qui conclut à sa place. Et l'état le plus grave
/// l'emporte : une pièce à reprendre passe avant dix pièces qui attendent le
/// réseau, parce qu'elle demande un geste alors que les autres n'en demandent
/// aucun.
/// ─────────────────────────────────────────────────────────────────────────────
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.enAttente,
    required this.aReprendre,
    required this.dossier,
    required this.sansDossier,
  });

  final int enAttente;
  final int aReprendre;
  final String? dossier;
  final bool sansDossier;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;

    final (String phrase, String detail, IconData icone, bool grave) = switch ((
      sansDossier,
      aReprendre,
      enAttente,
    )) {
      (true, _, _) => (
        'Aucun dossier à votre nom',
        "Le cabinet n'a pas encore ouvert votre espace. Appelez votre chargé de clientèle.",
        Icons.cloud_off_outlined,
        true,
      ),
      (_, final r, _) when r > 0 => (
        r == 1 ? 'Une pièce à reprendre' : '$r pièces à reprendre',
        "Le cabinet ne les a pas prises. Photographiez-les à nouveau.",
        Icons.replay_outlined,
        true,
      ),
      (_, _, 0) => (
        'Tout est parti',
        'Le cabinet a tout reçu. Rien ne vous attend.',
        Icons.check_circle_outline,
        false,
      ),
      (_, _, final n) => (
        n == 1 ? 'Une pièce attend' : '$n pièces attendent',
        'Elles partiront dès que le réseau le permet. Vous pouvez fermer.',
        Icons.schedule_outlined,
        false,
      ),
    };

    final fond = grave ? couleurs.errorContainer : couleurs.secondaryContainer;
    final encre = grave
        ? couleurs.onErrorContainer
        : couleurs.onSecondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 30, color: encre),
          const SizedBox(height: 12),
          Text(
            phrase,
            key: const Key('verdict'),
            style: TextStyle(
              fontSize: 23,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: encre,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: TextStyle(fontSize: 13.5, height: 1.4, color: encre),
          ),
          if (dossier != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.business_outlined, size: 15, color: encre),
                const SizedBox(width: 6),
                Text(
                  dossier!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: encre,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TitreDeSection extends StatelessWidget {
  const _TitreDeSection({
    required this.texte,
    required this.icone,
    this.alerte = false,
  });

  final String texte;
  final IconData icone;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final teinte = alerte ? couleurs.error : couleurs.onSurfaceVariant;
    return Row(
      children: [
        Icon(icone, size: 17, color: teinte),
        const SizedBox(width: 8),
        Text(
          texte,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: teinte,
          ),
        ),
      ],
    );
  }
}

/// Une pièce de la file, avec sa photographie.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ UN NOMBRE NE DIT PAS DE QUELLE FACTURE IL S'AGIT.
///
/// L'écran affichait « 3 » et rien d'autre. L'adhérent qui a photographié trois
/// pièces dans la journée ne pouvait pas savoir lesquelles étaient parties, ni
/// si celle du fournisseur qu'il attend en faisait partie. Il lui restait à
/// rouvrir sa galerie et à comparer les heures.
///
/// La photographie est sur l'appareil, à portée immédiate : la montrer ne coûte
/// rien et répond à la question. C'est la seule chose que cette application
/// possède et que la console n'a pas — la pièce avant qu'elle ne parte.
///
/// ⚠️ `errorBuilder` n'est pas une précaution de principe : le fichier peut
/// avoir disparu, ou n'être pas décodable. Sans lui, l'écran entier tombe sur
/// une image illisible, et l'adhérent perd l'accès à toute sa file pour une
/// vignette.
/// ─────────────────────────────────────────────────────────────────────────────
class _Vignette extends StatelessWidget {
  const _Vignette({required this.depot, this.alerte = false});

  final Depot depot;
  final bool alerte;

  String get _heure {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(depot.prisLe.day)}/${d(depot.prisLe.month)} à '
        '${d(depot.prisLe.hour)}h${d(depot.prisLe.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: couleurs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alerte
              ? couleurs.error.withValues(alpha: 0.45)
              : couleurs.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 58,
              height: 58,
              child: Image.file(
                File(depot.cheminDuFichier),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: couleurs.surfaceContainer,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 22,
                    color: couleurs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Photographiée le $_heure',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: couleurs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  alerte
                      ? (depot.motifDuRefus ?? "Le cabinet ne l'a pas prise.")
                      : 'Dossier ${depot.dossier}',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: alerte ? couleurs.error : couleurs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
