import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../marque.dart';

import '../composants/actions.dart';
import '../composants/carte.dart';
import '../composants/porte_de_l_historique.dart';
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
    required this.dossiers,
    this.ouvrirLHistorique,
    this.compteurEnAttente,
  });

  final ServiceDeSession session;
  final FileDAttente file;
  final PriseDeVue priseDeVue;

  /// ⚠️ Une fonction, et non un objet `Remise`. L'écran n'a pas à savoir
  /// comment une pièce part : cela le rend vérifiable sans réseau, et c'est
  /// exactement ce qui manquait.
  final Future<Reponse> Function(Depot) remettre;

  final VoidCallback quandDeconnecte;

  /// Ouvre l'historique de tout ce qui a déjà été remis au cabinet.
  ///
  /// ⚠️ AJOUTÉ LE 27 SEPTEMBRE, ET LA RAISON EST GÊNANTE : cet historique
  /// existait depuis des semaines, complet, avec la pièce jointe consultable —
  /// et son SEUL point d'entrée était une tuile tout en bas de l'accueil.
  /// C'est-à-dire précisément la section que la barre du bas recouvrait. Le
  /// défaut de mise en page ne cachait pas trois tuiles décoratives : il
  /// cachait la porte d'un écran entier, et personne ne pouvait le savoir.
  ///
  /// L'écran des justificatifs est le bon endroit : c'est l'onglet de ce que
  /// j'envoie, et « ce que j'ai déjà envoyé » y répond à un pas.
  ///
  /// `null` : la carte ne s'affiche pas — les dossiers ne sont pas encore lus.
  final VoidCallback? ouvrirLHistorique;

  /// Combien de pièces attendent encore, pour qui veut l'afficher ailleurs.
  ///
  /// ⚠️ La barre du bas porte un compteur sur le bouton de dépôt. Sans ce
  /// relais, elle devrait relire la file pour son compte, et l'on aurait deux
  /// lectures du même état pouvant se contredire à l'écran.
  final ValueNotifier<int>? compteurEnAttente;

  /// Les dossiers du compte, lus UNE FOIS par la coquille.
  ///
  /// ⚠️ Cet écran les relisait pour son compte, et les deux autres aussi : trois
  /// appels à `/transverse/moi` à chaque ouverture, sur un réseau qu'on sait
  /// mauvais, et trois réponses possiblement différentes si l'une échoue.
  final List<String> dossiers;

  @override
  State<EcranAccueil> createState() => EtatDeLAccueil();
}

/// ⚠️ L'ÉTAT EST PUBLIC, ET C'EST VOULU : la barre du bas déclenche la prise de
/// vue quand l'onglet est déjà ouvert (voir `_BoutonDeDepot`). Sans cela, l'écran
/// portait son propre bouton flottant, et l'adhérent voyait DEUX appareils photo
/// à trois centimètres l'un de l'autre, sans savoir lequel faisait quoi.
class EtatDeLAccueil extends State<EcranAccueil> with WidgetsBindingObserver {
  List<Depot> _enAttente = const [];
  List<Depot> _refuses = const [];
  bool _envoiEnCours = false;
  Timer? _reprise;

  /// ⚠️ TOUTES LES 30 SECONDES, ET PAS PLUS SOUVENT.
  ///
  /// La file ne part pas toute seule sans cela, et l'écran promettait pourtant
  /// qu'elle partirait. Trente secondes : assez court pour qu'un adhérent qui
  /// retrouve le réseau le voie partir sous ses yeux, assez long pour ne pas
  /// réveiller la radio du téléphone en boucle sur un forfait compté.
  static const cadenceDeReprise = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _relire().then((_) => _envoyerDiscretement());
    _reprise = Timer.periodic(cadenceDeReprise, (_) => _envoyerDiscretement());
  }

  @override
  void dispose() {
    _reprise?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// ⚠️ LE RETOUR DE L'APPLICATION EST LE MOMENT LE PLUS UTILE.
  ///
  /// On photographie une facture dans une boutique sans réseau, on range le
  /// téléphone, et l'on ressort dans la rue où la 3G revient. C'est à cet
  /// instant-là qu'il faut réessayer, pas trente secondes plus tard.
  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    // Au retour au premier plan, le réseau a souvent changé : on essaie tout de suite.
    if (etat == AppLifecycleState.resumed) _envoyerDiscretement(forcer: true);
  }

  Future<void> _relire() async {
    final enAttente = await widget.file.enAttente();
    final refuses = await widget.file.refuses();
    if (!mounted) return;
    setState(() {
      _enAttente = enAttente;
      _refuses = refuses;
    });
    widget.compteurEnAttente?.value = enAttente.length;
  }

  Future<void> _sortir() async {
    await widget.session.fermerLaSession();
    widget.quandDeconnecte();
  }

  /// Ouvre l'appareil photo (ou la galerie), range la pièce, et rafraîchit la
  /// liste.
  Future<void> photographier({bool depuisLaGalerie = false}) async {
    final dossier = await _quelDossier();
    if (dossier == null || !mounted) return;
    final depot = await widget.priseDeVue.pour(
      dossier,
      depuisLaGalerie: depuisLaGalerie,
    );
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
    // ⚠️ « Elle partira toute seule » : c'est ici que cela devient vrai.
    await _envoyerDiscretement();
  }

  /// Tente de vider la file SANS RIEN DIRE.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// ⚠️ POURQUOI EN SILENCE, ET POURQUOI CETTE MÉTHODE EXISTE.
  ///
  /// Constaté le 27 septembre sur un téléphone réel : une pièce photographiée
  /// restait sur l'appareil indéfiniment. L'écran annonçait « elles partiront
  /// dès que le réseau le permet, vous pouvez fermer », mais RIEN n'envoyait :
  /// le seul déclencheur était le nuage de la barre du haut, que personne n'a
  /// de raison d'aller chercher puisqu'on vient de lui dire de ne rien faire.
  /// Un adhérent fermait l'application en croyant sa facture remise.
  ///
  /// L'envoi n'échoue pas : il attend. Pas de réseau est l'état NORMAL de ce
  /// produit, pas une anomalie — d'où le silence. Le bouton, lui, parle encore,
  /// parce qu'on y a appuyé exprès et qu'une absence de réponse inquiéterait.
  ///
  /// Le seul cas qui rompt le silence est la session expirée : la file garde
  /// ses pièces, mais plus rien ne partira tant que l'adhérent n'est pas
  /// revenu, et il faut donc le lui dire.
  /// ─────────────────────────────────────────────────────────────────────────
  Future<void> _envoyerDiscretement({bool forcer = false}) async {
    if (_envoiEnCours || _enAttente.isEmpty || !mounted) return;
    setState(() => _envoiEnCours = true);
    final vidage = await widget.file.vider(widget.remettre, forcer: forcer);
    if (!mounted) return;
    setState(() => _envoiEnCours = false);
    await widget.priseDeVue.effacerLesCopiesDevenuesInutiles();
    await _relire();
    if (!mounted) return;
    if (vidage.sessionAExpire) widget.quandDeconnecte();
  }

  /// Le dossier auquel rattacher la pièce.
  ///
  /// ⚠️ On ne demande RIEN quand il n'y en a qu'un, et c'est le cas de presque
  /// tous les adhérents. Une question dont la réponse est forcée est une étape
  /// de plus entre la facture en main et la photo prise.
  Future<String?> _quelDossier() async {
    if (widget.dossiers.length == 1) {
      return widget.dossiers.single;
    }
    if (widget.dossiers.isEmpty) {
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
          for (final d in widget.dossiers)
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
    // L'adhérent a demandé l'envoi : on n'attend pas la fin de l'espacement.
    final vidage = await widget.file.vider(widget.remettre, forcer: true);
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
    final prete = widget.dossiers.isNotEmpty;
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
          padding: EdgeInsets.fromLTRB(
            Marque.espace4,
            Marque.espace4,
            Marque.espace4,
            // ⚠️ `…De(context)` et non la constante : la barre flotte AU-DESSUS de
            // l'encart système, que la constante seule ne couvre pas.
            Marque.espaceSousLaBarreDe(context),
          ),
          children: [
            _Verdict(
              enAttente: _enAttente.length,
              aReprendre: _refuses.length,
              dossier: prete
                  ? (widget.dossiers.length == 1
                        ? widget.dossiers.single
                        : null)
                  : null,
              sansDossier: !prete,
            ),
            // 18 octobre 2026 : l'écran ne disait que « Tout est parti ». Les deux
            // façons de remettre une pièce sont désormais sous les yeux : la
            // photographier, ou la prendre dans la galerie quand elle est déjà
            // arrivée en image.
            if (prete) ...[
              const SizedBox(height: 14),
              BoutonDAction(
                key: const Key('bouton-photographier'),
                libelle: 'Photographier une pièce',
                icone: Icons.photo_camera_outlined,
                surAppui: photographier,
              ),
              if (widget.priseDeVue.galerie != null) ...[
                const SizedBox(height: 10),
                BoutonDAction(
                  key: const Key('bouton-galerie'),
                  libelle: 'Choisir dans la galerie',
                  icone: Icons.photo_library_outlined,
                  secondaire: true,
                  surAppui: () => photographier(depuisLaGalerie: true),
                ),
              ],
            ],
            if (widget.ouvrirLHistorique != null) ...[
              const SizedBox(height: 14),
              PorteDeLHistorique(surAppui: widget.ouvrirLHistorique!),
            ],
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
      // ⚠️ CETTE PHRASE PARLE DE LA FILE DU TÉLÉPHONE, ET D'ELLE SEULE.
      //
      // Elle disait « Le cabinet a tout reçu. Rien ne vous attend. » Sur le
      // téléphone, en parcours réel, l'onglet d'à côté — l'accueil — annonçait
      // au même instant « Il manque 3 justificatifs ». Les deux étaient vrais
      // chacun de son côté : la file était vide, et le cabinet attendait trois
      // pièces jamais photographiées. Mais « rien ne vous attend » affirmait
      // ce que cet écran ne peut pas savoir. Il dit maintenant ce qu'il sait :
      // tout ce qui a été photographié ICI est parti.
      (_, _, 0) => (
        'Tout est parti',
        'Toutes les pièces photographiées sur ce téléphone ont été remises '
            'au cabinet. Ce qu\'il attend encore est sur l\'accueil.',
        Icons.check_circle_outline,
        false,
      ),
      (_, _, final n) => (
        n == 1 ? 'Une pièce attend' : '$n pièces attendent',
        'Elles repartent toutes seules dès que le réseau revient, tant que '
            'cette application est ouverte.',
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
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
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

  /// Beaucoup d'essais manqués : on le dit, au lieu d'un « en attente » muet.
  bool get _peine => depot.tentatives >= FileDAttente.tentativesMaximales;

  String get _heure {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(depot.prisLe.day)}/${d(depot.prisLe.month)} à '
        '${d(depot.prisLe.hour)}h${d(depot.prisLe.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Carte(
      padding: const EdgeInsets.all(Marque.espace3),
      ton: alerte ? TonDeCarte.alerte : TonDeCarte.neutre,
      relief: ReliefDeCarte.liste,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Marque.rayonBloc),
            child: SizedBox(
              width: 58,
              height: 58,
              child: Image.file(
                File(depot.cheminDuFichier),
                fit: BoxFit.cover,
                // Une photo de 2000 px décodée pour un carré de 58 : la mémoire d'un
                // téléphone d'entrée de gamme ne suit pas une file de vingt pièces.
                cacheWidth: 180,
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
                  'Prise le $_heure',
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
                      : _peine
                      ? "N'arrive pas à partir. Elle réessaie seule ; vous pouvez aussi "
                            'appuyer sur l\'envoi, en haut.'
                      : 'Dossier ${depot.dossier}',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: alerte || _peine
                        ? couleurs.error
                        : couleurs.onSurfaceVariant,
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
