import 'package:flutter/material.dart';

import '../composants/actions.dart';
import '../composants/carte.dart';
import '../composants/joindre.dart';
import '../composants/paiement.dart';
import '../composants/source_d_image.dart';
import '../contenu/cabinet.dart';
import '../domaine/fonds_confies.dart';
import '../marque.dart';
import '../domaine/echeance.dart';
import '../domaine/prise_de_vue.dart';
import '../domaine/preuve.dart';
import '../ports/service_de_l_espace.dart';
import '../ports/service_de_session.dart';

/// Ce que l'adhérent doit, et quand.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ LA QUESTION QUI VIENT AVANT TOUTES LES AUTRES
///
/// L'application savait déposer une pièce, et depuis peu montrer ce que le
/// cabinet en avait fait. Elle ne disait rien de ce qui précède : « qu'est-ce
/// que je dois faire, et pour quand ? »
///
/// C'est la première raison d'ouvrir l'application, et la seule que le cabinet
/// ait intérêt à satisfaire : un adhérent qui voit ses retards les règle, un
/// adhérent qui ne les voit pas appelle, ou ne fait rien.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranEcheances extends StatefulWidget {
  const EcranEcheances({
    super.key,
    required this.session,
    required this.dossiers,
    required this.quandSessionExpire,
    required this.priseDeVue,
    this.espace,
  });

  /// 18 octobre 2026 : les fonds confiés au cabinet, et leur règlement par mobile
  /// money. `null` : l'écran n'offre que la quittance, comme avant.
  final ServiceDeLEspace? espace;

  final ServiceDeSession session;
  final List<String> dossiers;
  final VoidCallback quandSessionExpire;

  /// ⚠️ La prise de vue sert ici à photographier une QUITTANCE, jamais un
  /// justificatif ordinaire : on passe donc par `copieDurable`, qui ne met rien
  /// en file. Voir son en-tête : la file la déposerait une seconde fois.
  final PriseDeVue priseDeVue;

  @override
  State<EcranEcheances> createState() => _EtatDesEcheances();
}

/// ⚠️ `WidgetsBindingObserver` : l'écran redemande au serveur à chaque retour au
/// premier plan. Même raison que l'historique, et plus forte : une échéance
/// franchie pendant que l'application dormait change l'état de la carte, et un
/// écran qui dit « à venir » sur une obligation passée en retard se trompe dans
/// le sens qui coûte des majorations.
class _EtatDesEcheances extends State<EcranEcheances>
    with WidgetsBindingObserver {
  Echeancier? _echeancier;
  bool _lectureEnCours = true;
  late String _dossier = widget.dossiers.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _relire();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat == AppLifecycleState.resumed) {
      _relire();
    }
  }

  /// Ce que le cabinet paie pour l'adhérent. Sans réseau, aucun : l'écran offre
  /// alors la quittance, la voie qui marche toujours.
  FondsConfies _fonds = FondsConfies.aucun;

  Future<void> _relire() async {
    setState(() => _lectureEnCours = true);
    final espace = widget.espace;
    final (lu, fonds) = await (
      widget.session.mesEcheances(_dossier),
      espace == null
          ? Future.value(const Lecture<FondsConfies>.lue(FondsConfies.aucun))
          : espace.mesFondsConfies(_dossier),
    ).wait;
    if (!mounted) return;
    setState(() {
      _echeancier = lu;
      _fonds = fonds.valeur ?? FondsConfies.aucun;
      _lectureEnCours = false;
    });
    if (lu.sessionAExpire) widget.quandSessionExpire();
  }

  /// L'obligation dont la preuve est en cours d'envoi, s'il y en a une.
  ///
  /// ⚠️ Une seule à la fois : deux envois simultanés déposeraient deux
  /// quittances que le cabinet devrait démêler.
  String? _envoiEnCours;

  /// Sous mandat : remettre ses fonds au cabinet par mobile money. L'adhérent n'a
  /// alors rien à photographier : le cabinet paie et porte la quittance.
  Future<void> _regler(Echeance e, AppelDeFonds appel) async {
    final espace = widget.espace;
    if (espace == null) return;
    final envoyee = await ouvrirUneFeuille<bool>(
      context,
      construire: (_) => FeuilleDePaiement(
        objet: '${e.titre} · ${e.periode}',
        montant: appel.montant,
        envoyer: (telephone) => espace.confierSesFonds(
          dossier: _dossier,
          appel: appel.identifiant,
          telephone: telephone,
        ),
        apresLePaiement:
            'Le cabinet paie l\'administration pour vous et garde la quittance : vous n\'avez rien à envoyer.',
      ),
    );
    if (envoyee == true) await _relire();
  }

  /// Les façons de régler une échéance, dites une fois, clairement.
  Future<void> _autresVoies(Echeance e) => ouvrirUneFeuille<void>(
    context,
    construire: (contexte) => _VoiesDeReglement(
      echeance: e,
      mandatee: _fonds.mandate(e.codeObligation),
      envoyerLaQuittance: () {
        Navigator.of(contexte).pop();
        _jaiPaye(e);
      },
    ),
  );

  Future<void> _jaiPaye(Echeance e) async {
    final chemin = await obtenirUneImage(context, widget.priseDeVue);
    if (chemin == null || !mounted) return;
    setState(() => _envoiEnCours = e.codeObligation);
    final sort = await widget.session.envoyerLaPreuve(
      dossier: _dossier,
      echeance: e,
      cheminDeLaPhoto: chemin,
    );
    if (!mounted) return;
    setState(() => _envoiEnCours = null);

    // ⚠️ Chaque sort a sa phrase, et « indisponible » en a une qui compte : la
    // quittance est CHEZ LE CABINET, sans son rattachement. Le taire ferait
    // photographier une seconde fois.
    final (String message, bool grave) = switch (sort) {
      // ⚠️ LA PÉRIODE EST NOMMÉE, ET CE N'EST PAS UN ORNEMENT.
      //
      // Constaté contre le vrai serveur : une fois la preuve reçue, la carte
      // ne disparaît pas et ne passe pas au vert. Elle GLISSE à la période
      // suivante — de janvier à février — et reste « en retard », parce qu'il
      // reste dix-huit mois derrière. Seul le compte du bandeau baisse d'une
      // unité.
      //
      // Sans nommer la période acquittée, l'adhérent voit un message de succès
      // suivi d'une carte qui dit toujours « en retard de 554 jours », et
      // conclut que rien n'a été pris. Il recommence.
      Preuve.recue => (
        'Preuve envoyée pour ${e.periode}. Le cabinet la vérifie ; '
            'la carte passe à la période suivante.',
        false,
      ),
      Preuve.refusee => (
        'Le cabinet ne peut pas rattacher cette preuve : l\'obligation est '
            'peut-être déjà déposée, ou la preuve déjà envoyée.',
        true,
      ),
      Preuve.sessionExpiree => ('Session expirée. Reconnectez-vous.', true),
      Preuve.indisponible => (
        'Votre quittance est arrivée au cabinet, mais nous n\'avons pas pu dire '
            'ce qu\'elle règle. Inutile de la reprendre en photo : appelez votre '
            'chargé de clientèle.',
        true,
      ),
    };
    final couleurs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: grave ? couleurs.error : null,
        duration: Duration(seconds: grave ? 8 : 4),
      ),
    );
    if (sort == Preuve.sessionExpiree) widget.quandSessionExpire();
    if (sort == Preuve.recue) await _relire();
  }

  @override
  Widget build(BuildContext context) {
    final e = _echeancier;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes échéances'),
        actions: [
          if (widget.dossiers.length > 1)
            PopupMenuButton<String>(
              key: const Key('choix-dossier-echeances'),
              initialValue: _dossier,
              tooltip: 'Changer de dossier',
              icon: const Icon(Icons.folder_outlined),
              onSelected: (d) {
                setState(() => _dossier = d);
                _relire();
              },
              itemBuilder: (_) => [
                for (final d in widget.dossiers)
                  PopupMenuItem(value: d, child: Text(d)),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _relire,
        child: switch ((_lectureEnCours, e)) {
          (true, null) => const Center(
            key: Key('echeances-en-attente'),
            child: CircularProgressIndicator(),
          ),
          (_, null) => const _RienDuTout(
            titre: 'Échéancier indisponible',
            detail: 'Le serveur n\'a pas répondu.',
            icone: Icons.cloud_off_outlined,
          ),
          (_, final Echeancier x) when x.sessionAExpire => const _RienDuTout(
            titre: 'Session expirée',
            detail: 'Reconnectez-vous pour consulter vos échéances.',
            icone: Icons.lock_outline,
          ),
          (_, final Echeancier x) when !x.serveurJoignable => const _RienDuTout(
            // ⚠️ SURTOUT PAS « vous êtes à jour ». Voir l'en-tête d'`Echeancier` :
            // dire cela à un adhérent en retard de dix-neuf mois parce que le
            // réseau manquait est le pire mensonge que cet écran puisse faire.
            titre: 'Pas de réseau',
            detail:
                'Vos échéances se lisent sur le serveur. Cette liste reparaîtra '
                'dès que la connexion revient.',
            icone: Icons.wifi_off_outlined,
          ),
          (_, final Echeancier x) when x.echeances.isEmpty => const _RienDuTout(
            titre: 'Aucune échéance',
            detail:
                'Le cabinet n\'a encore inscrit aucune obligation à votre '
                'calendrier. Appelez votre chargé de clientèle si cela vous '
                'étonne.',
            icone: Icons.event_available_outlined,
          ),
          (_, final Echeancier x) => _Liste(
            echeancier: x,
            jaiPaye: _jaiPaye,
            envoiEnCours: _envoiEnCours,
            fonds: _fonds,
            regler: widget.espace == null ? null : _regler,
            autresVoies: _autresVoies,
          ),
        },
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.echeancier,
    required this.jaiPaye,
    required this.envoiEnCours,
    this.fonds = FondsConfies.aucun,
    this.regler,
    this.autresVoies,
  });

  final FondsConfies fonds;
  final Future<void> Function(Echeance, AppelDeFonds)? regler;
  final Future<void> Function(Echeance)? autresVoies;
  final Echeancier echeancier;
  final Future<void> Function(Echeance) jaiPaye;
  final String? envoiEnCours;

  @override
  Widget build(BuildContext context) => ListView(
    // ⚠️ La barre du bas flotte : la dernière échéance finirait dessous.
    padding: EdgeInsets.fromLTRB(
      Marque.espace4,
      Marque.espace4,
      Marque.espace4,
      // ⚠️ `…De(context)` et non la constante : la barre flotte AU-DESSUS de
      // l'encart système, que la constante seule ne couvre pas.
      Marque.espaceSousLaBarreDe(context),
    ),
    children: [
      _Verdict(echeancier: echeancier),
      const SizedBox(height: 22),
      for (final e in echeancier.echeances)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Carte(
            echeance: e,
            jaiPaye: jaiPaye,
            enCours: envoiEnCours == e.codeObligation,
            mandatee: fonds.mandate(e.codeObligation),
            appel: fonds.appelPour(e.codeObligation, e.periodeDebut),
            regler: regler,
            autresVoies: autresVoies,
          ),
        ),
    ],
  );
}

/// La phrase qui conclut, avant le détail.
///
/// ⚠️ Elle annonce le nombre de PÉRIODES en retard, pas le nombre de cartes.
/// Six cartes peuvent cacher une centaine de mois : conclure sur les cartes
/// minimiserait le retard d'un facteur vingt.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.echeancier});

  final Echeancier echeancier;

  @override
  Widget build(BuildContext context) {
    final periodes = echeancier.periodesEnRetard;
    final grave = periodes > 0;

    final (String phrase, String detail) = grave
        ? (
            '$periodes période${periodes > 1 ? "s" : ""} en retard',
            // 18 octobre 2026 : deux voies, dites dès le chapeau.
            'Réglez la plus ancienne d\'abord : par mobile money quand le cabinet paie '
                'pour vous, sinon envoyez votre quittance.',
          )
        : (
            'Rien en retard',
            'Vos prochaines échéances sont listées ci-dessous.',
          );

    return Chapeau(
      grave: grave,
      icone: grave ? Icons.warning_amber_rounded : Icons.check_circle_outline,
      titre: phrase,
      detail: detail,
    );
  }
}

/// Une obligation, avec ce qu'elle est et ce qu'un retard coûte.
class _Carte extends StatefulWidget {
  const _Carte({
    required this.echeance,
    required this.jaiPaye,
    required this.enCours,
    this.mandatee = false,
    this.appel,
    this.regler,
    this.autresVoies,
  });

  /// Le cabinet paie cette obligation pour l'adhérent (mandat de paiement).
  final bool mandatee;

  /// L'appel de fonds de cette période, quand le cabinet l'a arrêté.
  final AppelDeFonds? appel;
  final Future<void> Function(Echeance, AppelDeFonds)? regler;
  final Future<void> Function(Echeance)? autresVoies;
  final Echeance echeance;
  final Future<void> Function(Echeance) jaiPaye;
  final bool enCours;

  @override
  State<_Carte> createState() => _EtatDeLaCarte();
}

class _EtatDeLaCarte extends State<_Carte> {
  bool _deplie = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.echeance;
    final couleurs = Theme.of(context).colorScheme;
    final alerte = e.etat.demandeUnGeste;
    final appel = widget.appel;

    // ⚠️ L'ALERTE SE DIT PAR UN BANDEAU, PLUS PAR UN CADRE ROUGE.
    //
    // La carte entière était cerclée de rouge épaissi dès qu'une échéance
    // demandait un geste. Sur un dossier qui en compte plusieurs, l'écran
    // devenait une suite de cadres rouges : tout crie, donc plus rien ne se
    // distingue. Le bandeau latéral se repère aussi vite et laisse la carte
    // lisible. Le mot reste, juste en dessous — la couleur ne porte jamais
    // seule l'information.
    return Carte(
      padding: EdgeInsets.zero,
      ton: alerte ? TonDeCarte.alerte : TonDeCarte.neutre,
      // ⚠️ Relief de LISTE : huit échéances portant chacune l'ombre pleine
      // faisaient vibrer l'écran. Voir `ReliefDeCarte`.
      relief: ReliefDeCarte.liste,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Marque.espace4,
              Marque.espace4,
              Marque.espace4,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.titre,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: couleurs.onSurface,
                  ),
                ),
                const SizedBox(height: Marque.espace1),
                Text(
                  e.periode,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: couleurs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Marque.espace3),
                // ⚠️ L'ÉTAT EN ÉTIQUETTE, ET NON EN PHRASE ROUGE PLEINE LARGEUR.
                //
                // Vu sur l'appareil : le bandeau latéral, l'icône et la phrase
                // disaient tous les trois la même alerte, en rouge, sur chaque
                // carte. Une page de retards devenait un mur rouge, où plus rien
                // ne se distinguait. L'étiquette garde le MOT et l'icône — la
                // couleur ne porte donc toujours pas seule l'information — mais
                // à la taille d'un état, pas d'un titre.
                Etiquette(
                  alerte
                      ? '${e.etat.libelle} de ${e.jours} jour'
                            '${e.jours > 1 ? "s" : ""}'
                      : e.etat.libelle,
                  couleur: alerte ? couleurs.error : null,
                  icone: alerte
                      ? Icons.error_outline
                      : e.etat == EtatPourLAdherent.preuveEnvoyee ||
                            e.etat == EtatPourLAdherent.fondsRecus
                      ? Icons.hourglass_top_outlined
                      : e.etat == EtatPourLAdherent.payee
                      ? Icons.task_alt
                      : e.etat.close
                      ? Icons.task_alt
                      : Icons.schedule_outlined,
                ),
                if (e.autresPeriodesEnRetard > 0) ...[
                  const SizedBox(height: Marque.espace2),
                  // ⚠️ Ne jamais taire ce nombre. Un adhérent qui règle la carte
                  // affichée et croit en avoir fini se trompe d'autant de mois.
                  //
                  // ⚠️ En encre douce et non en rouge : c'est une PRÉCISION sur
                  // l'alerte que l'étiquette vient de donner, pas une seconde
                  // alerte. En rouge, elle doublait le cri.
                  Text(
                    'Et ${e.autresPeriodesEnRetard} autre'
                    '${e.autresPeriodesEnRetard > 1 ? "s" : ""} période'
                    '${e.autresPeriodesEnRetard > 1 ? "s" : ""} en retard '
                    'derrière celle-ci.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: couleurs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // ⚠️ LE GESTE N'EST OFFERT QUE SUR CE QUI EST EN RETARD.
          //
          // Sur une échéance à venir il n'y a rien à prouver, et sur une preuve
          // déjà envoyée le cabinet vérifie : reproposer le geste ferait
          // déposer une seconde quittance que quelqu'un devrait démêler.
          //
          // ⚠️ Le libellé dit « j'ai déjà payé », jamais « payer ». L'adhérent
          // a réglé ailleurs — guichet, Mobile Money, virement — et il en
          // apporte la preuve. L'application ne sait pas encaisser, et le
          // serveur non plus pour un adhérent.
          // ── Comment régler (18 octobre 2026) ──────────────────────────
          //
          // « Je peux faire ce versement depuis mon téléphone, et je n'ai plus
          // besoin d'envoyer une capture. » Sous mandat, l'adhérent remet ses
          // fonds au cabinet par mobile money, et le cabinet paie
          // l'administration : rien à photographier. Sinon, il paie lui-même et
          // envoie sa quittance, qui reste la voie qui marche toujours.
          //
          // ⚠️ LE GESTE N'EST OFFERT QUE SUR CE QUI DEMANDE UN GESTE : sur une
          // échéance à venir il n'y a rien à prouver, et sur une preuve déjà
          // envoyée le cabinet vérifie.
          if (alerte || appel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Marque.espace4,
                Marque.espace3,
                Marque.espace4,
                0,
              ),
              child: _Voie(
                echeance: e,
                mandatee: widget.mandatee,
                appel: widget.appel,
                enCours: widget.enCours,
                jaiPaye: () => widget.jaiPaye(e),
                regler: widget.regler == null || widget.appel == null
                    ? null
                    : () => widget.regler!(e, widget.appel!),
                autresVoies: widget.autresVoies == null
                    ? null
                    : () => widget.autresVoies!(e),
              ),
            ),
          if (e.deQuoiSAgitIl != null || e.enCasDeRetard != null)
            // ⚠️ L'explication est REPLIÉE par défaut. Dépliée, cinq cartes
            // font un mur de texte que personne ne lit ; absente, l'adhérent
            // ignore ce que « CNPS » veut dire. Le serveur fournit ces phrases,
            // et elles viennent du référentiel : ce n'est pas l'application qui
            // explique le droit.
            TextButton.icon(
              key: Key('expliquer-${e.codeObligation}'),
              onPressed: () => setState(() => _deplie = !_deplie),
              icon: Icon(
                _deplie ? Icons.expand_less : Icons.expand_more,
                size: 19,
              ),
              label: Text(_deplie ? 'Masquer' : 'De quoi s\'agit-il ?'),
            ),
          if (_deplie)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.deQuoiSAgitIl != null)
                    Text(
                      e.deQuoiSAgitIl!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: couleurs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  if (e.enCasDeRetard != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      e.enCasDeRetard!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: couleurs.error,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RienDuTout extends StatelessWidget {
  const _RienDuTout({
    required this.titre,
    required this.detail,
    required this.icone,
  });

  final String titre;
  final String detail;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    // `ListView` et non `Center` : le geste de tirer pour rafraîchir ne
    // fonctionne que sur une zone qui défile.
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 90, 32, 32),
      children: [
        Icon(icone, size: 44, color: couleurs.onSurfaceVariant),
        const SizedBox(height: 18),
        Text(
          titre,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: couleurs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: couleurs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// La voie de règlement d'une échéance, selon qu'elle est confiée au cabinet ou non.
class _Voie extends StatelessWidget {
  const _Voie({
    required this.echeance,
    required this.mandatee,
    required this.appel,
    required this.enCours,
    required this.jaiPaye,
    required this.regler,
    required this.autresVoies,
  });

  final Echeance echeance;
  final bool mandatee;
  final AppelDeFonds? appel;
  final bool enCours;
  final VoidCallback jaiPaye;
  final VoidCallback? regler;
  final VoidCallback? autresVoies;

  @override
  Widget build(BuildContext context) {
    final e = echeance;
    final a = appel;
    final theme = Theme.of(context);
    final douce = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.4,
    );
    final montant = a?.montant ?? e.montantEstime?.round();

    // Les fonds sont remis : le cabinet paie, ou a payé. Rien à faire.
    if (a != null && a.etat != EtatDeLAppel.aRegler) {
      final reverse = a.etat == EtatDeLAppel.reverse;
      return Row(
        children: [
          Icon(
            reverse ? Icons.verified : Icons.hourglass_top_outlined,
            size: 20,
            color: reverse ? Marque.reussite : theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reverse
                  ? 'Payée par le cabinet, quittance gardée à votre dossier.'
                  : 'Vos ${montantFcfa(a.montant)} sont reçus : le cabinet paie l\'administration pour vous.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (montant != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                // Sans appel, le montant n'est qu'estimé d'après la paie : le
                // dire, plutôt que « à verser » à côté de « pas encore arrêté ».
                Text(
                  a == null ? 'Estimé d\'après votre paie' : 'À verser',
                  style: douce,
                ),
                const Spacer(),
                Text(
                  montantFcfa(montant),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        if (a != null && regler != null) ...[
          BoutonDAction(
            key: Key('regler-${e.codeObligation}'),
            libelle: 'Régler par mobile money',
            icone: Icons.phone_iphone,
            surAppui: regler,
          ),
          const SizedBox(height: 6),
          Text(
            'Le cabinet paie l\'administration pour vous et garde la quittance : rien à photographier.',
            style: douce,
          ),
          TextButton(
            key: Key('jai-paye-${e.codeObligation}'),
            onPressed: enCours ? null : jaiPaye,
            child: Text(
              enCours
                  ? 'Envoi en cours…'
                  : 'J\'ai déjà payé moi-même : envoyer la quittance',
            ),
          ),
        ] else ...[
          if (mandatee)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                montant != null
                    ? 'Le cabinet paie cette échéance pour vous. Dès qu\'il vous aura '
                          'appelé ce montant, vous le réglerez ici par mobile money.'
                    : 'Le cabinet paie cette échéance pour vous. Dès qu\'il aura arrêté le montant, '
                          'vous le réglerez ici par mobile money.',
                style: douce,
              ),
            ),
          // ⚠️ Le libellé dit « j'ai déjà payé », jamais « payer » : l'adhérent a
          // réglé ailleurs, et il en apporte la preuve.
          BoutonDAction(
            key: Key('jai-paye-${e.codeObligation}'),
            libelle: 'J\'ai déjà payé : envoyer la quittance',
            libelleEnCours: 'Envoi en cours…',
            icone: Icons.photo_camera_outlined,
            enCours: enCours,
            surAppui: jaiPaye,
            tonal: true,
          ),
        ],
        if (autresVoies != null)
          TextButton.icon(
            key: Key('voies-${e.codeObligation}'),
            onPressed: autresVoies,
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text('Comment régler cette échéance ?'),
          ),
      ],
    );
  }
}

/// Les façons de régler une échéance, expliquées une fois.
class _VoiesDeReglement extends StatelessWidget {
  const _VoiesDeReglement({
    required this.echeance,
    required this.mandatee,
    required this.envoyerLaQuittance,
  });

  final Echeance echeance;
  final bool mandatee;
  final VoidCallback envoyerLaQuittance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget voie(IconData icone, String titre, String detail, {Widget? geste}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icone,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    ?geste,
                  ],
                ),
              ),
            ],
          ),
        );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comment régler ${echeance.titre.toLowerCase()} ?',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          voie(
            Icons.phone_iphone,
            'Le cabinet paie pour vous',
            mandatee
                ? 'C\'est votre cas pour cette obligation. Le cabinet arrête le montant ; vous le réglez ici par '
                      'mobile money ; il paie l\'administration et garde la quittance. Rien à photographier.'
                : 'Vous réglez ici par mobile money, le cabinet paie l\'administration et garde la quittance. '
                      'Rien à photographier. Le cabinet l\'ouvre sur demande.',
            geste: mandatee
                ? null
                : TextButton.icon(
                    onPressed: () => joindre(
                      context,
                      Cabinet.whatsappLien,
                      aCopier: Cabinet.whatsapp,
                    ),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Le demander au cabinet'),
                  ),
          ),
          voie(
            Icons.account_balance_outlined,
            'Vous payez vous-même',
            'Sur le portail de paiement de l\'administration, ou à son guichet. Puis envoyez la quittance : le '
                'cabinet la rattache à la déclaration.',
            geste: TextButton.icon(
              onPressed: envoyerLaQuittance,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Envoyer ma quittance'),
            ),
          ),
        ],
      ),
    );
  }
}
