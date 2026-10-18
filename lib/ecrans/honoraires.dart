import 'package:flutter/material.dart';

import '../composants/actions.dart';
import '../composants/carte.dart';
import '../domaine/honoraires.dart';
import '../marque.dart';
import '../ports/service_de_l_espace.dart';

/// Mes honoraires : ce que je dois au cabinet, et le régler (18 octobre 2026).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// LE PARCOURS D'UN RÈGLEMENT
///
/// 1. La carte de la période dit le montant, la période et depuis quand il est dû.
/// 2. « Payer par mobile money » ouvre une feuille : le montant rappelé, le
///    numéro à débiter, et ce qui va se passer.
/// 3. Envoyée, la demande arrive sur le téléphone de l'adhérent : la feuille le
///    lui dit, en grand, et l'écran se relit de lui-même quand il revient.
///
/// ⚠️ « ENVOYÉE » N'EST PAS « PAYÉE ». C'est la notification de l'opérateur qui
/// règle la période ; un clic n'est pas un paiement. L'écran ne marque donc
/// jamais une période réglée de lui-même : il relit le serveur.
///
/// ⚠️ LE GUICHET RESTE UNE VOIE : la caisse du cabinet constate un règlement en
/// espèces ou par virement, et la ligne passe à « Réglée » toute seule.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranHonoraires extends StatefulWidget {
  const EcranHonoraires({
    super.key,
    required this.espace,
    required this.dossiers,
    required this.quandSessionExpire,
    required this.ouvrirDocument,
  });

  final ServiceDeLEspace espace;
  final List<String> dossiers;
  final VoidCallback quandSessionExpire;

  /// Ouvre un PDF servi par une route (note, reçu, facture) dans la visionneuse.
  final void Function(String chemin, String titre) ouvrirDocument;

  @override
  State<EcranHonoraires> createState() => _EtatDesHonoraires();
}

class _EtatDesHonoraires extends State<EcranHonoraires> {
  late String _dossier = widget.dossiers.first;
  Lecture<MesHonoraires>? _lecture;

  @override
  void initState() {
    super.initState();
    _relire();
  }

  Future<void> _relire() async {
    final lue = await widget.espace.mesHonoraires(_dossier);
    if (!mounted) return;
    if (lue.sessionAExpire) {
      widget.quandSessionExpire();
      return;
    }
    setState(() => _lecture = lue);
  }

  Future<void> _payer(PeriodeDHonoraires periode) async {
    final envoyee = await ouvrirUneFeuille<bool>(
      context,
      construire: (_) => _FeuilleDePaiement(
        espace: widget.espace,
        dossier: _dossier,
        periode: periode,
      ),
    );
    if (envoyee == true) await _relire();
  }

  String get _base =>
      '/souscription/honoraires/${Uri.encodeComponent(_dossier)}';

  @override
  Widget build(BuildContext context) {
    final lecture = _lecture;
    final h = lecture?.valeur;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes honoraires'),
        actions: [
          if (widget.dossiers.length > 1)
            PopupMenuButton<String>(
              initialValue: _dossier,
              tooltip: 'Changer de dossier',
              icon: const Icon(Icons.folder_outlined),
              onSelected: (d) {
                setState(() {
                  _dossier = d;
                  _lecture = null;
                });
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
        child: switch ((lecture, h)) {
          (null, _) => const Center(child: CircularProgressIndicator()),
          (_, null) => EtatVide(
            titre: 'Pas de réseau',
            detail:
                'Vos honoraires se lisent sur le serveur. Ils reparaîtront dès que la connexion revient.',
            icone: Icons.wifi_off_outlined,
            action: OutlinedButton(
              onPressed: _relire,
              child: const Text('Réessayer'),
            ),
          ),
          (_, final MesHonoraires x) when !x.aUnContrat => const EtatVide(
            titre: 'Aucun contrat d\'honoraires',
            detail:
                'Le cabinet ne vous a encore rien facturé. Votre chargé de clientèle vous dira quand il le fera.',
            icone: Icons.receipt_long_outlined,
          ),
          (_, final MesHonoraires x) => _Contenu(
            honoraires: x,
            payer: _payer,
            ouvrir: (chemin, titre) =>
                widget.ouvrirDocument('$_base$chemin', titre),
          ),
        },
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({
    required this.honoraires,
    required this.payer,
    required this.ouvrir,
  });

  final MesHonoraires honoraires;
  final Future<void> Function(PeriodeDHonoraires) payer;
  final void Function(String chemin, String titre) ouvrir;

  @override
  Widget build(BuildContext context) {
    final h = honoraires;
    final grave = h.situation == SituationDeReglement.bloque || h.enRetard > 0;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        Marque.espace4,
        Marque.espace4,
        Marque.espace4,
        Marque.espaceSousLaBarreDe(context),
      ),
      children: [
        Chapeau(
          titre: h.du > 0
              ? '${montantFcfa(h.du)} à régler'
              : h.situation.libelle,
          detail: h.du > 0
              ? '${h.situation.libelle}. ${h.situation.explication}'
              : h.situation.explication,
          icone: h.du > 0
              ? Icons.account_balance_wallet_outlined
              : Icons.verified_outlined,
          grave: grave,
        ),
        if (h.dues.isNotEmpty) ...[
          const SizedBox(height: 24),
          const TitreDeSection('À régler'),
          const SizedBox(height: 8),
          for (final p in h.dues)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PeriodeDue(
                periode: p,
                enLigne: h.reglableEnLigne,
                payer: () => payer(p),
                note: () =>
                    ouvrir('/echeances/${p.cle}/note', 'Note d\'honoraires'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Vous pouvez aussi régler au cabinet, en espèces ou par virement : la caisse le constate, '
              'et la période passe à « Réglée » d\'elle-même.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
        if (h.reglees.isNotEmpty) ...[
          const SizedBox(height: 28),
          const TitreDeSection('Réglées'),
          const SizedBox(height: 8),
          Carte(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, p) in h.reglees.indexed) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _PeriodeReglee(
                    periode: p,
                    factureDisponible: h.factureDisponible,
                    ouvrir: ouvrir,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (h.aVenir.isNotEmpty) ...[
          const SizedBox(height: 28),
          const TitreDeSection('À venir'),
          const SizedBox(height: 8),
          for (final p in h.aVenir)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Carte(
                relief: ReliefDeCarte.liste,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _periode(p),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      montantFcfa(p.montant),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

String _periode(PeriodeDHonoraires p) {
  final mois = p.fin.difference(p.debut).inDays <= 31;
  final texte = mois
      ? moisEtAnnee(p.debut)
      : 'du ${jourLong(p.debut)} au ${jourLong(p.fin)}';
  return texte[0].toUpperCase() + texte.substring(1);
}

class _PeriodeDue extends StatelessWidget {
  const _PeriodeDue({
    required this.periode,
    required this.enLigne,
    required this.payer,
    required this.note,
  });

  final PeriodeDHonoraires periode;
  final bool enLigne;
  final VoidCallback payer;
  final VoidCallback note;

  @override
  Widget build(BuildContext context) {
    final p = periode;
    final retard = p.etat == EtatDHonoraires.enRetard;
    final theme = Theme.of(context);
    return Carte(
      ton: retard ? TonDeCarte.alerte : TonDeCarte.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_periode(p), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      retard
                          ? 'Due depuis le ${jourLong(p.exigibleLe)}'
                          : 'À régler avant le ${jourLong(p.exigibleLe)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Pastille(
                p.etat.libelle,
                ton: retard ? TonDePastille.alerte : TonDePastille.attente,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            montantFcfa(p.montant),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: Marque.policeTitre,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          if (enLigne)
            SizedBox(
              width: double.infinity,
              child: BoutonDAction(
                key: Key('payer-${p.cle}'),
                libelle: 'Payer par mobile money',
                icone: Icons.phone_iphone,
                surAppui: payer,
              ),
            ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: note,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Voir la note d\'honoraires'),
          ),
        ],
      ),
    );
  }
}

class _PeriodeReglee extends StatelessWidget {
  const _PeriodeReglee({
    required this.periode,
    required this.factureDisponible,
    required this.ouvrir,
  });

  final PeriodeDHonoraires periode;
  final bool factureDisponible;
  final void Function(String chemin, String titre) ouvrir;

  @override
  Widget build(BuildContext context) {
    final p = periode;
    final r = p.reglement;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 20, color: Marque.reussite),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_periode(p), style: theme.textTheme.titleSmall),
              ),
              Text(montantFcfa(p.montant), style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
            ],
          ),
          if (r != null)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Text(
                'Réglée le ${jourLong(r.constateLe.toLocal())} · ${r.parMobileMoney ? 'mobile money' : 'au guichet'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Wrap(
              children: [
                if (r != null)
                  TextButton(
                    onPressed: () => ouvrir(
                      '/reglements/${Uri.encodeComponent(r.identifiant)}/recu',
                      'Reçu',
                    ),
                    child: const Text('Reçu'),
                  ),
                if (factureDisponible)
                  TextButton(
                    onPressed: () =>
                        ouvrir('/echeances/${p.cle}/facture', 'Facture'),
                    child: const Text('Facture'),
                  ),
                TextButton(
                  onPressed: () =>
                      ouvrir('/echeances/${p.cle}/note', 'Note d\'honoraires'),
                  child: const Text('Note'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La feuille du paiement : récapituler, demander le numéro, puis dire quoi faire.
class _FeuilleDePaiement extends StatefulWidget {
  const _FeuilleDePaiement({
    required this.espace,
    required this.dossier,
    required this.periode,
  });

  final ServiceDeLEspace espace;
  final String dossier;
  final PeriodeDHonoraires periode;

  @override
  State<_FeuilleDePaiement> createState() => _EtatDeLaFeuilleDePaiement();
}

class _EtatDeLaFeuilleDePaiement extends State<_FeuilleDePaiement> {
  final _numero = TextEditingController();
  bool _enCours = false;
  DemandeDeDebit? _sort;

  @override
  void dispose() {
    _numero.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final numero = _numero.text.replaceAll(RegExp(r'\s'), '');
    if (numero.length < 9) {
      setState(
        () => _sort = const DemandeDeDebit(
          sort: SortDuDebit.refusee,
          message:
              'Indiquez le numéro mobile money à débiter : neuf chiffres au moins.',
        ),
      );
      return;
    }
    setState(() {
      _enCours = true;
      _sort = null;
    });
    final sort = await widget.espace.demanderLeDebit(
      dossier: widget.dossier,
      periode: widget.periode.cle,
      telephone: numero,
    );
    if (!mounted) return;
    setState(() {
      _enCours = false;
      _sort = sort;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sort = _sort;
    if (sort?.sort == SortDuDebit.envoyee) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Marque.reussite100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.phone_android, size: 36, color: Marque.reussite),
          ),
          const SizedBox(height: 18),
          Text(
            'Validez sur votre téléphone',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'La demande de ${montantFcfa(widget.periode.montant)} est partie. Composez votre code secret '
            'sur le message de votre opérateur. La période passera à « Réglée » dès qu\'il nous l\'aura confirmé.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (sort!.simule) ...[
            const SizedBox(height: 12),
            const Pastille(
              'Démonstration : aucun débit réel',
              ton: TonDePastille.attente,
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('J\'ai compris'),
            ),
          ),
        ],
      );
    }
    final message = switch (sort?.sort) {
      null || SortDuDebit.envoyee => null,
      SortDuDebit.dejaEnCours =>
        sort!.message ??
            'Une demande est déjà en cours pour cette période : validez-la sur votre téléphone.',
      SortDuDebit.refusee =>
        sort!.message ?? 'La demande a été refusée. Vérifiez le numéro.',
      SortDuDebit.sessionExpiree =>
        'Votre session a expiré : reconnectez-vous, puis recommencez.',
      SortDuDebit.indisponible =>
        'Le serveur n\'a pas répondu. Vérifiez votre connexion, puis réessayez.',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payer par mobile money', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(Marque.rayonCarte),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Honoraires · ${_periode(widget.periode)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                montantFcfa(widget.periode.montant),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('numero-mobile-money'),
          controller: _numero,
          keyboardType: TextInputType.phone,
          autofocus: true,
          enabled: !_enCours,
          decoration: const InputDecoration(
            labelText: 'Numéro à débiter',
            hintText: '6 77 12 34 56',
            prefixIcon: Icon(Icons.phone_outlined),
            helperText:
                'MTN Mobile Money ou Orange Money. Vous validerez sur ce téléphone.',
            helperMaxLines: 2,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: BoutonDAction(
            key: const Key('confirmer-le-paiement'),
            libelle:
                'Envoyer la demande de ${montantFcfa(widget.periode.montant)}',
            libelleEnCours: 'Envoi à l\'opérateur…',
            icone: Icons.send_outlined,
            enCours: _enCours,
            surAppui: _envoyer,
          ),
        ),
      ],
    );
  }
}
