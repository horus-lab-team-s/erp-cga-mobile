import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/anneau.dart';
import '../composants/carte.dart';
import '../composants/joindre.dart';
import '../contenu/cabinet.dart';
import '../domaine/document_recu.dart';
import '../domaine/echeance.dart';
import '../domaine/mon_mois.dart';
import '../composants/actions.dart';
import '../marque.dart';
import '../ports/service_de_session.dart';
import '../ports/service_du_tableau_de_bord.dart';

/// L'accueil de l'espace adhérent : où en est mon dossier.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ L'ACCUEIL RÉPOND D'ABORD, IL DÉTAILLE ENSUITE.
///
/// L'application s'ouvrait, une fois connecté, sur l'écran de dépôt : un
/// appareil photo et « Tout est parti ». L'adhérent qui voulait savoir s'il
/// devait quelque chose au cabinet devait ouvrir trois onglets et faire
/// l'addition lui-même.
///
/// L'accueil dit maintenant, dans cet ordre :
///
///   1. le MOIS — ce qui manque, ou que tout est complet, dans les mots du
///      serveur ;
///   2. ce que le cabinet DEMANDE, pièce par pièce, avec les deux réponses
///      toutes faites à portée de pouce ;
///   3. les ÉCHÉANCES — ce qui est en retard, ou la prochaine ;
///   4. les derniers DOCUMENTS que le cabinet a déposés pour lui.
///
/// Chaque bloc mène à l'onglet qui le détaille.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranTableauDeBord extends StatefulWidget {
  const EcranTableauDeBord({
    super.key,
    required this.session,
    required this.tableau,
    required this.dossiers,
    required this.quandSessionExpire,
    required this.allerALOnglet,
    required this.ouvrirMesPieces,
    this.deposerAuChoix,
    this.ouvrirPiece,
    this.seDeconnecter,
    this.honorairesDus,
    this.ouvrirHonoraires,
    this.ouvrirMonEntreprise,
  });

  /// Ouvre « Mon entreprise » ; à défaut, l'onglet « Plus » qui la range.
  final VoidCallback? ouvrirMonEntreprise;

  /// 18 octobre 2026 : ce que l'adhérent doit au cabinet, lu par la coquille.
  /// `null` ou zéro : rien à régler, la carte ne paraît pas.
  final int? honorairesDus;

  /// Ouvre l'écran des honoraires, là où l'on règle par mobile money.
  final VoidCallback? ouvrirHonoraires;

  final ServiceDeSession session;
  final ServiceDuTableauDeBord tableau;

  /// ⚠️ Jamais vide : la coquille ne construit cet écran qu'avec un dossier.
  final List<String> dossiers;
  final VoidCallback quandSessionExpire;

  /// Mène à un onglet de la coquille, par son rang.
  final void Function(int) allerALOnglet;
  final VoidCallback ouvrirMesPieces;

  /// Déposer en choisissant la source : photo, galerie ou scan. `null` : on
  /// ouvre l'onglet de dépôt, comme le bouton central.
  final VoidCallback? deposerAuChoix;

  void _deposer() =>
      deposerAuChoix != null ? deposerAuChoix!() : allerALOnglet(ongletDeposer);

  /// Ouvre le document d'une pièce déposée. `null` : pas de visionneuse.
  final void Function(String piece)? ouvrirPiece;

  /// Ferme la session. ⚠️ Elle n'était proposée que sur l'onglet Déposer,
  /// en haut à droite d'un écran d'appareil photo : personne ne l'y cherche.
  /// Constaté en parcours sur le téléphone.
  final VoidCallback? seDeconnecter;

  /// Les rangs des onglets, tels que la coquille les range.
  static const ongletEcheances = 1;
  static const ongletDeposer = 2;
  static const ongletDocuments = 3;

  /// 18 octobre 2026 : « Plus » a pris la place d'« Entreprise ».
  static const ongletPlus = 4;

  @override
  State<EcranTableauDeBord> createState() => EtatDuTableauDeBord();
}

class EtatDuTableauDeBord extends State<EcranTableauDeBord> {
  String? _nom;
  MonMois? _mois;
  Echeancier? _echeancier;
  Documents? _documents;
  bool _enCours = true;

  /// Les demandes auxquelles l'adhérent vient de répondre, et ce qu'il a
  /// répondu : la carte le dit tout de suite, sans attendre une relecture.
  final _repondues = <String, String>{};

  String get _dossier => widget.dossiers.first;

  @override
  void initState() {
    super.initState();
    _relire();
  }

  /// Relu par la coquille au retour sur l'onglet : une échéance réglée ailleurs
  /// doit quitter les retards de l'accueil (18 octobre 2026).
  Future<void> relire() => _relire();

  /// ⚠️ LES QUATRE LECTURES PARTENT ENSEMBLE : en 3G, les enchaîner
  /// quadruplerait l'attente devant un écran vide.
  Future<void> _relire() async {
    setState(() => _enCours = true);
    final nom = widget.tableau.monNom();
    final mois = widget.tableau.monMois(_dossier);
    final echeancier = widget.session.mesEcheances(_dossier);
    final documents = widget.session.mesDocuments(_dossier);
    final (n, m, e, d) = (
      await nom,
      await mois,
      await echeancier,
      await documents,
    );
    if (!mounted) return;
    if (m.sessionAExpire || e.sessionAExpire || d.sessionAExpire) {
      widget.quandSessionExpire();
      return;
    }
    setState(() {
      _nom = n;
      _mois = m;
      _echeancier = e;
      _documents = d;
      _enCours = false;
      _repondues.clear();
    });
  }

  Future<void> _repondre(Attendue a, NatureDeReponse nature) async {
    final sort = await widget.tableau.repondre(
      demande: a.demande,
      nature: nature,
    );
    if (!mounted) return;
    if (sort == SortDeLaReponse.sessionExpiree) {
      widget.quandSessionExpire();
      return;
    }
    final message = switch (sort) {
      SortDeLaReponse.transmise =>
        'Réponse transmise au cabinet : « ${nature.libelle} ».',
      // ⚠️ Pas une erreur : le cabinet a déjà l'information.
      SortDeLaReponse.dejaRecue =>
        'Le cabinet a déjà votre réponse à cette demande.',
      SortDeLaReponse.refusee =>
        "Cette demande n'attend plus de réponse. Tirez vers le bas pour "
            'actualiser.',
      _ => "Le serveur n'a pas répondu. Votre réponse n'est pas partie.",
    };
    if (sort == SortDeLaReponse.transmise ||
        sort == SortDeLaReponse.dejaRecue) {
      setState(() => _repondues[a.demande] = nature.libelle);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final m = _mois;
    // Icônes de la barre d'état en blanc : l'en-tête est indigo, et l'écran
    // n'a pas de barre d'application pour le dire au système.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _relire,
          child: CustomScrollView(
            slivers: [
              // ⚠️ L'EN-TÊTE ET LE BANDEAU DU MOIS DANS LA MÊME TRANCHE.
              //
              // Le bandeau chevauche l'en-tête indigo : c'est la première chose
              // lue, et le chevauchement le montre. Il vivait dans la tranche
              // suivante, remonté par un décalage. Or dans une liste défilante,
              // la PREMIÈRE tranche se peint PAR-DESSUS les suivantes — c'est
              // ce qui permet aux barres épinglées de recouvrir le contenu. Le
              // haut du bandeau, « VOTRE MOIS · AOÛT 2026 » compris, passait
              // donc sous l'indigo. Dans une même colonne, c'est l'inverse : le
              // dernier enfant se peint au-dessus.
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EnTete(
                      nom: _nom,
                      denomination: m?.denomination ?? '',
                      dossier: _dossier,
                      seDeconnecter: widget.seDeconnecter,
                    ),
                    if (m != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Transform.translate(
                          offset: const Offset(0, -34),
                          child: m.serveurJoignable
                              ? _BandeauDuMois(mois: m)
                              : const _HorsLigne(),
                        ),
                      ),
                  ],
                ),
              ),
              if (_enCours && m == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                SliverToBoxAdapter(child: _corps(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corps(BuildContext context) {
    final m = _mois!;
    final e = _echeancier;
    final d = _documents;
    final texte = Theme.of(context).textTheme;
    // ⚠️ Pas de réseau se dit UNE fois, en tête, plutôt que dans chaque bloc.
    final horsLigne =
        !m.serveurJoignable ||
        (e != null && !e.serveurJoignable) ||
        (d != null && !d.serveurJoignable);

    return Padding(
      // ⚠️ La barre du bas FLOTTE au-dessus de la page : rien ne la déduit.
      // Sans cette marge, la dernière tuile finissait cachée derrière elle.
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        Marque.espaceSousLaBarreDe(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (horsLigne && m.serveurJoignable) ...[
            const _HorsLigne(),
            const SizedBox(height: 16),
          ],

          // ── Où j'en suis, en trois chiffres ──────────────────────────────
          //
          // ⚠️ L'ADHÉRENT OUVRE POUR SAVOIR OÙ IL EN EST, pas pour lire trois
          // sections l'une après l'autre. Les trois nombres qui comptent — ce
          // que le cabinet attend, ce qui est en retard, ce qui a été déposé
          // pour lui — se lisent d'un regard, chacun avec son signe, et chacun
          // mène à l'écran qui le détaille.
          _TroisChiffres(
            attendues: m.attendues.length,
            enRetard: e?.periodesEnRetard,
            documents: d?.documents.length,
            surAttendues: widget._deposer,
            surRetards: () =>
                widget.allerALOnglet(EcranTableauDeBord.ongletEcheances),
            surDocuments: () =>
                widget.allerALOnglet(EcranTableauDeBord.ongletDocuments),
          ),
          const SizedBox(height: Marque.espace6),

          // ── Le geste principal ───────────────────────────────────────────
          _GrandeAction(surAppui: widget._deposer),
          const SizedBox(height: Marque.espace6),

          // ── Les honoraires dus (18 octobre 2026) ─────────────────────────
          //
          // ⚠️ Le règlement est rangé sous « Plus » ; sans cette carte, un
          // adhérent en retard ne le trouverait qu'en cherchant. Elle ne paraît
          // que s'il y a un montant dû, et mène droit à l'écran du paiement.
          if ((widget.honorairesDus ?? 0) > 0 &&
              widget.ouvrirHonoraires != null) ...[
            Carte(
              key: const Key('accueil-honoraires'),
              ton: TonDeCarte.accent,
              surAppui: widget.ouvrirHonoraires,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${montantFcfa(widget.honorairesDus!)} d\'honoraires à régler',
                          style: texte.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Réglez par mobile money, en deux gestes.',
                          style: texte.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: Marque.espace6),
          ],

          // ── Ce que le cabinet demande ────────────────────────────────────
          if (m.attendues.isNotEmpty) ...[
            const TitreDeSection('Ce que le cabinet vous demande'),
            const SizedBox(height: 4),
            Text(
              'Déposez la pièce, ou dites au cabinet où vous en êtes.',
              style: texte.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final a in m.attendues)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CarteAttendue(
                  attendue: a,
                  repondu: _repondues[a.demande] ?? a.reponse,
                  surDeposer: widget._deposer,
                  surRepondre: (nature) => _repondre(a, nature),
                  surVoirLaPiece:
                      a.pieceARectifier == null || widget.ouvrirPiece == null
                      ? null
                      : () => widget.ouvrirPiece!(a.pieceARectifier!),
                ),
              ),
            const SizedBox(height: 14),
          ],

          // ── Les échéances ────────────────────────────────────────────────
          if (e != null && e.serveurJoignable) ...[
            const TitreDeSection('Vos échéances'),
            const SizedBox(height: 10),
            _ResumeDesEcheances(
              echeancier: e,
              surVoir: () =>
                  widget.allerALOnglet(EcranTableauDeBord.ongletEcheances),
            ),
            const SizedBox(height: 24),
          ],

          // ── Les documents du cabinet ─────────────────────────────────────
          if (d != null && d.serveurJoignable && d.documents.isNotEmpty) ...[
            TitreDeSection(
              'Déposés pour vous par le cabinet',
              complement: TextButton(
                key: const Key('voir-documents'),
                onPressed: () =>
                    widget.allerALOnglet(EcranTableauDeBord.ongletDocuments),
                child: const Text('Tout voir'),
              ),
            ),
            const SizedBox(height: 6),
            for (final doc in d.documents.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CarteDocument(
                  document: doc,
                  surVoir: () =>
                      widget.allerALOnglet(EcranTableauDeBord.ongletDocuments),
                ),
              ),
            const SizedBox(height: 14),
          ],

          // ── Raccourcis ───────────────────────────────────────────────────
          //
          // ⚠️ LE DÉPÔT N'EST PLUS UN RACCOURCI PARMI QUATRE. Il a sa grande
          // action plus haut, et la place centrale de la barre du bas. Le
          // répéter ici en tuile de même taille que « Écrire au cabinet »
          // reviendrait à dire que les deux gestes se valent.
          const TitreDeSection('Raccourcis'),
          const SizedBox(height: Marque.espace3),
          _Raccourcis(
            surMesPieces: widget.ouvrirMesPieces,
            surEntreprise:
                widget.ouvrirMonEntreprise ??
                () => widget.allerALOnglet(EcranTableauDeBord.ongletPlus),
            surEcrire: () => joindre(
              context,
              Cabinet.whatsappLien,
              aCopier: Cabinet.whatsapp,
            ),
          ),
        ],
      ),
    );
  }
}

/// « 12 août 2026 ». ⚠️ Jamais « 2026-08-12 » : une date ISO se lit comme un
/// code, pas comme un jour.
String jourEnFrancais(DateTime d) {
  const mois = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${d.day} ${mois[d.month - 1]} ${d.year}';
}

/// L'en-tête indigo : qui est connecté, et quel dossier.
class _EnTete extends StatelessWidget {
  const _EnTete({
    required this.nom,
    required this.denomination,
    required this.dossier,
    this.seDeconnecter,
  });

  final String? nom;
  final String denomination;
  final String dossier;
  final VoidCallback? seDeconnecter;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        // ⚠️ Le dégradé de marque, autorisé sur cette seule surface et sur la
        // grande action (voir `Marque.degradeMarque`). Le blanc posé dessus est
        // mesuré sur l'extrémité la plus claire : 7,41:1 sur le magenta.
        gradient: sombre ? Marque.degradeMarqueSombre : Marque.degradeMarque,
        // Le bas s'arrondit : l'en-tête devient un panneau posé sur la page, et
        // non une bande qui la coupe.
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(Marque.rayonCarte + 8),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 14,
        20,
        // La place que le bandeau du mois vient chevaucher.
        52,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                Marque.logoBlanc,
                height: 30,
                semanticLabel: Cabinet.nom,
              ),
              const Spacer(),
              if (seDeconnecter != null)
                IconButton(
                  key: const Key('accueil-sortir'),
                  onPressed: () async {
                    if (await confirmerLaDeconnexion(context)) seDeconnecter!();
                  },
                  color: Colors.white,
                  tooltip: 'Se déconnecter',
                  icon: const Icon(Icons.logout),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            // ⚠️ Le nom ENTIER, et non un prénom deviné : au Cameroun, le nom
            // de famille vient souvent en premier, et « Bonjour NKOA » serait
            // aussi maladroit que faux.
            nom == null ? 'Bonjour' : 'Bonjour, $nom',
            key: const Key('salutation'),
            style: texte.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            denomination.isEmpty ? dossier : '$denomination · $dossier',
            style: texte.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le bandeau du mois, dans les mots du serveur.
class _BandeauDuMois extends StatelessWidget {
  const _BandeauDuMois({required this.mois});
  final MonMois mois;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final (icone, teinte) = switch (mois.etat) {
      EtatDuMois.aEnvoyer => (Icons.upload_file, couleurs.error),
      EtatDuMois.aucunePiece => (Icons.inbox_outlined, Marque.alerte),
      EtatDuMois.enVerification => (
        Icons.manage_search,
        couleurs.onSecondaryContainer,
      ),
      EtatDuMois.complet => (Icons.task_alt, Marque.reussite),
    };
    return Carte(
      key: const Key('bandeau-du-mois'),
      ton: mois.etat == EtatDuMois.aEnvoyer
          ? TonDeCarte.alerte
          : TonDeCarte.neutre,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️ L'ANNEAU REMPLACE LA PASTILLE D'ICÔNE. Elle ne disait que l'état,
          // que le titre écrit déjà en toutes lettres. L'anneau dit où l'on en
          // est — « 2 sur 5 » —, ce qu'aucune phrase du serveur ne porte.
          if (mois.piecesDuMois > 0)
            AnneauDeProgression(
              fait: mois.justificatifsRecus,
              total: mois.piecesDuMois,
              teinte: teinte,
              libelle:
                  '${mois.justificatifsRecus} justificatif'
                  '${mois.justificatifsRecus > 1 ? "s" : ""} reçu'
                  '${mois.justificatifsRecus > 1 ? "s" : ""} sur '
                  '${mois.piecesDuMois} pour ${mois.nomDuMois}',
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: teinte.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, color: teinte),
            ),
          const SizedBox(width: Marque.espace4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOTRE MOIS · ${mois.nomDuMois.toUpperCase()}',
                  style: texte.labelSmall?.copyWith(letterSpacing: 0.8),
                ),
                const SizedBox(height: 4),
                // ⚠️ Le titre et le détail du SERVEUR, tels quels : les mots
                // sont au référentiel du cabinet, et « complet » ne s'y dit
                // que s'il est vrai.
                Text(mois.titre, style: texte.titleMedium),
                const SizedBox(height: 4),
                Text(mois.detail, style: texte.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HorsLigne extends StatelessWidget {
  const _HorsLigne();

  @override
  Widget build(BuildContext context) => const Carte(
    key: Key('hors-ligne'),
    child: Row(
      children: [
        Icon(Icons.wifi_off_outlined),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            "Pas de réseau : ce qui s'affiche peut être incomplet. Tirez vers "
            'le bas pour actualiser.',
          ),
        ),
      ],
    ),
  );
}

/// Une pièce attendue par le cabinet, et les gestes qui y répondent.
class _CarteAttendue extends StatelessWidget {
  const _CarteAttendue({
    required this.attendue,
    required this.repondu,
    required this.surDeposer,
    required this.surRepondre,
    this.surVoirLaPiece,
  });

  final Attendue attendue;

  /// Ouvre la pièce refusée, quand il y en a une.
  final VoidCallback? surVoirLaPiece;

  /// Ce que l'adhérent a répondu, s'il l'a fait.
  final String? repondu;
  final VoidCallback surDeposer;
  final void Function(NatureDeReponse) surRepondre;

  @override
  Widget build(BuildContext context) {
    final a = attendue;
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return Carte(
      key: Key('attendue-${a.demande}'),
      ton: a.enRetard ? TonDeCarte.alerte : TonDeCarte.neutre,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // ⚠️ Des mots, pas seulement une couleur : « En retard » et
              // « À corriger » disent la même chose à qui ne voit pas le
              // rouge du bandeau.
              if (a.enRetard) Etiquette('En retard', couleur: couleurs.error),
              if (a.aCorriger) const Etiquette.avertissement('À corriger'),
              if (a.bloquante && !a.enRetard)
                const Etiquette('Nécessaire à la clôture'),
            ],
          ),
          const SizedBox(height: 8),
          Text(a.libelle, style: texte.bodyMedium),
          if (a.attenduePour != null) ...[
            const SizedBox(height: 6),
            Text(
              'Attendue pour le ${jourEnFrancais(a.attenduePour!)} · '
              '${a.demande}',
              style: texte.bodySmall,
            ),
          ],
          if (surVoirLaPiece != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('voir-piece-${a.demande}'),
                onPressed: surVoirLaPiece,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Voir la pièce que vous aviez envoyée'),
              ),
            ),
          const SizedBox(height: 12),
          if (repondu != null)
            Row(
              key: Key('repondu-${a.demande}'),
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: Marque.reussite,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Vous avez répondu : « $repondu »',
                    style: texte.bodySmall,
                  ),
                ),
              ],
            )
          else ...[
            FilledButton.tonalIcon(
              key: Key('deposer-${a.demande}'),
              onPressed: surDeposer,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Déposer la pièce'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
            const SizedBox(height: 4),
            // ⚠️ Les deux réponses toutes faites, et pas un champ de saisie :
            // elles couvrent l'essentiel des cas sans clavier, sur un
            // téléphone d'entrée de gamme.
            Wrap(
              children: [
                for (final n in NatureDeReponse.values)
                  TextButton(
                    key: Key('${n.code}-${a.demande}'),
                    onPressed: () => surRepondre(n),
                    child: Text(n.libelle),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Les échéances en une carte : ce qui est en retard, ou la prochaine.
class _ResumeDesEcheances extends StatelessWidget {
  const _ResumeDesEcheances({required this.echeancier, required this.surVoir});

  final Echeancier echeancier;
  final VoidCallback surVoir;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final retard = echeancier.periodesEnRetard;
    final aVenir =
        echeancier.echeances
            .where((e) => e.etat == EtatPourLAdherent.aVenir)
            .toList()
          ..sort((a, b) => a.echeanceLe.compareTo(b.echeanceLe));
    final prochaine = aVenir.isEmpty ? null : aVenir.first;

    final (titre, detail, alerte) = retard > 0
        ? (
            // ⚠️ Des PÉRIODES, pas des cartes : une obligation en retard sur
            // six mois compte six, et c'est ce que l'administration comptera.
            '$retard période${retard > 1 ? "s" : ""} en retard',
            'Envoyez la preuve de paiement de ce qui est déjà réglé : le '
                'cabinet mettra le dossier à jour.',
            true,
          )
        : prochaine != null
        ? (
            'Prochaine : ${prochaine.titre}',
            '${prochaine.periode} · avant le '
                '${jourEnFrancais(prochaine.echeanceLe)}',
            false,
          )
        : ('Rien en retard', 'Aucune échéance à venir pour le moment.', false);

    return Carte(
      key: const Key('resume-echeances'),
      ton: alerte ? TonDeCarte.alerte : TonDeCarte.neutre,
      surAppui: surVoir,
      child: Row(
        children: [
          Icon(
            alerte ? Icons.event_busy : Icons.event_available,
            color: alerte ? couleurs.error : couleurs.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: texte.titleSmall),
                const SizedBox(height: 2),
                Text(detail, style: texte.bodySmall),
                // ⚠️ LA PART DU RETARD, DESSINÉE. « 6 périodes en retard » ne
                // dit pas si c'est six sur huit ou six sur soixante. La barre
                // le montre, et les deux nombres sont écrits dessous : la
                // couleur ne porte jamais seule l'information.
                if (retard > 0 && echeancier.echeances.isNotEmpty) ...[
                  const SizedBox(height: Marque.espace3),
                  BarreDeuxParts(
                    premier: retard,
                    second: echeancier.echeances.length - retard < 0
                        ? 0
                        : echeancier.echeances.length - retard,
                    teintePremier: couleurs.error,
                    teinteSecond: couleurs.outlineVariant,
                  ),
                  const SizedBox(height: Marque.espace2),
                  Text(
                    '$retard en retard · '
                    '${echeancier.echeances.length - retard} à jour ou à venir',
                    style: texte.labelSmall?.copyWith(
                      color: couleurs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Marque.espace2),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _CarteDocument extends StatelessWidget {
  const _CarteDocument({required this.document, required this.surVoir});
  final DocumentRecu document;
  final VoidCallback surVoir;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return Carte(
      surAppui: surVoir,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: couleurs.secondaryContainer,
              borderRadius: BorderRadius.circular(Marque.rayonBloc),
            ),
            child: Icon(
              Icons.description_outlined,
              color: couleurs.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.titre, style: texte.titleSmall),
                Text(
                  '${document.periode} · déposé le '
                  '${jourEnFrancais(document.deposeLe)}',
                  style: texte.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

/// Quatre gestes fréquents, en tuiles.
/// Les trois chiffres de l'adhérent, chacun avec son signe.
///
/// ⚠️ EN LIGNE, PUIS EN COLONNE QUAND LE TEXTE GROSSIT.
///
/// Trois colonnes sur un écran de 360 points tiennent au réglage ordinaire.
/// À 130 % — un réglage courant chez qui lit mal de près —, « documents » ne
/// rentre plus et se coupait en plein mot (« documen / ts »). Borner
/// l'agrandissement aurait rendu illisible ce qu'on venait d'agrandir ; les
/// tuiles passent donc l'une sous l'autre, où la largeur ne manque jamais.
class _TroisChiffres extends StatelessWidget {
  const _TroisChiffres({
    required this.attendues,
    required this.enRetard,
    required this.documents,
    required this.surAttendues,
    required this.surRetards,
    required this.surDocuments,
  });

  final int attendues;

  /// `null` quand le serveur n'a pas répondu : on écrit « — », jamais zéro.
  /// Zéro veut dire « rien en retard », et ce n'est pas la même nouvelle.
  final int? enRetard;
  final int? documents;
  final VoidCallback surAttendues;
  final VoidCallback surRetards;
  final VoidCallback surDocuments;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final echelle = MediaQuery.textScalerOf(context).scale(14) / 14;
    final enColonne = echelle > 1.15;
    final tuiles = [
      (
        'chiffre-attendues',
        Icons.inbox_outlined,
        attendues,
        'pièce${attendues > 1 ? "s" : ""} attendue${attendues > 1 ? "s" : ""}',
        attendues > 0,
        surAttendues,
      ),
      (
        'chiffre-retards',
        Icons.event_busy_outlined,
        enRetard,
        'période${(enRetard ?? 0) > 1 ? "s" : ""} en retard',
        (enRetard ?? 0) > 0,
        surRetards,
      ),
      (
        'chiffre-documents',
        Icons.folder_open_outlined,
        documents,
        'document${(documents ?? 0) > 1 ? "s" : ""} déposé'
            '${(documents ?? 0) > 1 ? "s" : ""}',
        false,
        surDocuments,
      ),
    ];

    Widget tuile(
      String cle,
      IconData icone,
      int? valeur,
      String libelle,
      bool alerte,
      VoidCallback geste,
    ) {
      final teinte = switch (cle) {
        _ when alerte => couleurs.error,
        'chiffre-documents' => Marque.reussite,
        'chiffre-retards' => Marque.indigo700,
        _ => couleurs.primary,
      };
      final nombre = Text(
        valeur == null ? '–' : '$valeur',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: alerte ? couleurs.error : couleurs.secondary,
        ),
      );
      Widget mot(TextAlign alignement) => Text(
        libelle,
        textAlign: alignement,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.25),
      );
      // ⚠️ 19 octobre 2026 : l'icône dans un cercle de sa teinte, à cheval sur le
      // haut de la tuile. Posée nue dans un coin, elle passait pour une
      // décoration ; sortie de moitié, elle nomme la tuile d'un coup d'œil et
      // allège la carte, qui n'a plus à la contenir.
      //
      // ⚠️ Le cercle est OPAQUE, et cerclé du fond de page : à moitié dehors, il
      // laisserait sinon voir le bord de la carte en travers de l'icône.
      Widget pastille({required bool aCheval}) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.alphaBlend(
            teinte.withValues(alpha: 0.14),
            couleurs.surfaceContainerLow,
          ),
          border: aCheval
              ? Border.all(color: couleurs.surfaceContainerLowest, width: 3)
              : null,
          boxShadow: aCheval
              ? [
                  BoxShadow(
                    color: teinte.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(icone, size: 21, color: teinte),
      );
      if (enColonne) {
        return Carte(
          key: Key(cle),
          relief: ReliefDeCarte.liste,
          lueur: teinte,
          surAppui: geste,
          padding: const EdgeInsets.all(Marque.espace3),
          // En colonne : la pastille, le nombre et le mot sur une seule ligne.
          child: Row(
            children: [
              pastille(aCheval: false),
              const SizedBox(width: Marque.espace3),
              nombre,
              const SizedBox(width: Marque.espace2),
              Expanded(child: mot(TextAlign.start)),
            ],
          ),
        );
      }
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 23),
            child: Carte(
              key: Key(cle),
              relief: ReliefDeCarte.liste,
              lueur: teinte,
              surAppui: geste,
              padding: const EdgeInsets.fromLTRB(
                Marque.espace2,
                23 + Marque.espace2,
                Marque.espace2,
                Marque.espace3,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    nombre,
                    const SizedBox(height: 2),
                    mot(TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(child: Center(child: pastille(aCheval: true))),
          ),
        ],
      );
    }

    if (enColonne) {
      return Column(
        children: [
          for (final (cle, icone, valeur, libelle, alerte, geste)
              in tuiles) ...[
            if (cle != 'chiffre-attendues')
              const SizedBox(height: Marque.espace3),
            tuile(cle, icone, valeur, libelle, alerte, geste),
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (cle, icone, valeur, libelle, alerte, geste)
              in tuiles) ...[
            if (cle != 'chiffre-attendues')
              const SizedBox(width: Marque.espace3),
            Expanded(child: tuile(cle, icone, valeur, libelle, alerte, geste)),
          ],
        ],
      ),
    );
  }
}

/// Le geste principal de l'écran : déposer une pièce.
///
/// ⚠️ UNE SEULE ACTION PLEINE PAR ÉCRAN — § 10.7. C'est celle-ci : l'adhérent
/// ouvre l'application une facture à la main. Tout le reste de l'accueil se lit ;
/// cela seul se fait.
class _GrandeAction extends StatelessWidget {
  const _GrandeAction({required this.surAppui});

  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Ink(
      key: const Key('grande-action-deposer'),
      decoration: BoxDecoration(
        gradient: sombre ? Marque.degradeMarqueSombre : Marque.degradeMarque,
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
        boxShadow: sombre ? null : Marque.ombreCarte,
      ),
      child: InkWell(
        onTap: surAppui,
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
        child: Padding(
          padding: const EdgeInsets.all(Marque.espace5),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(Marque.rayonCarte),
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: Marque.espace4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Déposer une pièce',
                      style: texte.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Photographiez ou importez votre facture : elle part au cabinet.',
                      style: texte.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les raccourcis AUXILIAIRES : ce qu'on ouvre de temps en temps.
class _Raccourcis extends StatelessWidget {
  const _Raccourcis({
    required this.surMesPieces,
    required this.surEntreprise,
    required this.surEcrire,
  });

  final VoidCallback surMesPieces;
  final VoidCallback surEntreprise;
  final VoidCallback surEcrire;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final tuiles = [
      ('raccourci-pieces', Icons.history, 'Mes pièces', surMesPieces),
      (
        'raccourci-entreprise',
        Icons.storefront_outlined,
        'Mon entreprise',
        surEntreprise,
      ),
      ('raccourci-ecrire', Icons.chat_outlined, 'Écrire', surEcrire),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (cle, icone, libelle, geste) in tuiles) ...[
            if (cle != 'raccourci-pieces')
              const SizedBox(width: Marque.espace3),
            // ⚠️ 19 octobre 2026 : PLUS DE CARTE DERRIÈRE CHAQUE RACCOURCI. Trois
            // cartes de plus sous les chiffres et la grande action faisaient un
            // écran de boîtes. Un raccourci n'est qu'une porte : une icône dans
            // son cercle et un mot suffisent, l'appui se voit par l'encre.
            Expanded(
              child: Semantics(
                button: true,
                child: InkWell(
                  key: Key(cle),
                  onTap: geste,
                  borderRadius: BorderRadius.circular(Marque.rayonCarte),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: Marque.espace2,
                      horizontal: Marque.espace1,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: couleurs.secondaryContainer,
                          ),
                          child: Icon(
                            icone,
                            color: couleurs.secondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: Marque.espace2),
                        Text(
                          libelle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: couleurs.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
