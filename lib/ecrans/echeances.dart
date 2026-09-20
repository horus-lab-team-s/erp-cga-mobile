import 'package:flutter/material.dart';

import '../domaine/echeance.dart';
import '../domaine/prise_de_vue.dart';
import '../domaine/preuve.dart';
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
  });

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

  Future<void> _relire() async {
    setState(() => _lectureEnCours = true);
    final lu = await widget.session.mesEcheances(_dossier);
    if (!mounted) return;
    setState(() {
      _echeancier = lu;
      _lectureEnCours = false;
    });
    if (lu.sessionAExpire) widget.quandSessionExpire();
  }

  /// L'obligation dont la preuve est en cours d'envoi, s'il y en a une.
  ///
  /// ⚠️ Une seule à la fois : deux envois simultanés déposeraient deux
  /// quittances que le cabinet devrait démêler.
  String? _envoiEnCours;

  Future<void> _jaiPaye(Echeance e) async {
    final chemin = await widget.priseDeVue.copieDurable();
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
      Preuve.recue => ('Preuve envoyée. Le cabinet la vérifie.', false),
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
  });

  final Echeancier echeancier;
  final Future<void> Function(Echeance) jaiPaye;
  final String? envoiEnCours;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
    final couleurs = Theme.of(context).colorScheme;
    final periodes = echeancier.periodesEnRetard;
    final grave = periodes > 0;

    final (String phrase, String detail) = grave
        ? (
            '$periodes période${periodes > 1 ? "s" : ""} en retard',
            'Réglez la plus ancienne d\'abord, puis envoyez la preuve au cabinet.',
          )
        : (
            'Rien en retard',
            'Vos prochaines échéances sont listées ci-dessous.',
          );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: grave ? couleurs.errorContainer : couleurs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            grave ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: grave
                ? couleurs.onErrorContainer
                : couleurs.onPrimaryContainer,
          ),
          const SizedBox(height: 10),
          Text(
            phrase,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: grave
                  ? couleurs.onErrorContainer
                  : couleurs.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color:
                  (grave
                          ? couleurs.onErrorContainer
                          : couleurs.onPrimaryContainer)
                      .withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une obligation, avec ce qu'elle est et ce qu'un retard coûte.
class _Carte extends StatefulWidget {
  const _Carte({
    required this.echeance,
    required this.jaiPaye,
    required this.enCours,
  });

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

    return Container(
      decoration: BoxDecoration(
        color: couleurs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: alerte ? couleurs.error : couleurs.outlineVariant,
          width: alerte ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
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
                const SizedBox(height: 3),
                Text(
                  e.periode,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: couleurs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                // ⚠️ L'état en MOTS, et la couleur seulement en renfort : la
                // règle du dossier de design, la couleur ne porte jamais seule
                // une information.
                Row(
                  children: [
                    Icon(
                      alerte
                          ? Icons.error_outline
                          : e.etat == EtatPourLAdherent.preuveEnvoyee
                          ? Icons.hourglass_top_outlined
                          : e.etat.close
                          ? Icons.task_alt
                          : Icons.schedule_outlined,
                      size: 17,
                      color: alerte ? couleurs.error : couleurs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        alerte
                            ? '${e.etat.libelle} de ${e.jours} jour${e.jours > 1 ? "s" : ""}'
                            : e.etat.libelle,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: alerte
                              ? couleurs.error
                              : couleurs.onSurfaceVariant,
                          fontWeight: alerte
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (e.autresPeriodesEnRetard > 0) ...[
                  const SizedBox(height: 8),
                  // ⚠️ Ne jamais taire ce nombre. Un adhérent qui règle la carte
                  // affichée et croit en avoir fini se trompe d'autant de mois.
                  Text(
                    'Et ${e.autresPeriodesEnRetard} autre'
                    '${e.autresPeriodesEnRetard > 1 ? "s" : ""} période'
                    '${e.autresPeriodesEnRetard > 1 ? "s" : ""} en retard '
                    'derrière celle-ci.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: couleurs.error,
                      height: 1.35,
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
          if (alerte)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: FilledButton.tonalIcon(
                key: Key('jai-paye-${e.codeObligation}'),
                onPressed: widget.enCours
                    ? null
                    : () => widget.jaiPaye(e),
                icon: widget.enCours
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(
                  widget.enCours
                      ? 'Envoi en cours…'
                      : 'J\'ai déjà payé — envoyer la quittance',
                ),
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
