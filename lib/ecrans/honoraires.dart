import 'package:flutter/material.dart';

import '../composants/actions.dart';
import '../composants/carte.dart';
import '../composants/etat.dart';
import '../composants/paiement.dart';
import '../domaine/honoraires.dart';
import '../domaine/suivi_du_paiement.dart';
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
    required this.dossier,
    required this.quandSessionExpire,
    required this.ouvrirDocument,
    this.apresLecture,
  });

  final ServiceDeLEspace espace;

  /// ⚠️ 20 octobre 2026 : LE dossier choisi dans l'en-tête de l'accueil, et non plus
  /// une liste dont l'écran prenait le premier. Un adhérent à deux entreprises
  /// choisissait la seconde sur l'accueil et lisait les honoraires de la première.
  final String dossier;
  final VoidCallback quandSessionExpire;

  /// Chaque lecture réussie, pour les rappels d'échéances posés sur le téléphone.
  final void Function(MesHonoraires)? apresLecture;

  /// Ouvre un PDF servi par une route (note, reçu, facture) dans la visionneuse.
  final void Function(String chemin, String titre) ouvrirDocument;

  @override
  State<EcranHonoraires> createState() => _EtatDesHonoraires();
}

class _EtatDesHonoraires extends State<EcranHonoraires> {
  Lecture<MesHonoraires>? _lecture;

  /// Les périodes dont la demande de débit est partie, et que l'opérateur n'a pas
  /// encore confirmées. Voir `suivreLePaiement`.
  final _enAttenteDeValidation = <String>{};

  @override
  void initState() {
    super.initState();
    _relire();
  }

  @override
  void didUpdateWidget(EcranHonoraires ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.dossier != widget.dossier) {
      setState(() {
        _lecture = null;
        _enAttenteDeValidation.clear();
      });
      _relire();
    }
  }

  Future<void> _relire() async {
    final lue = await widget.espace.mesHonoraires(widget.dossier);
    if (!mounted) return;
    if (lue.sessionAExpire) {
      widget.quandSessionExpire();
      return;
    }
    final h = lue.valeur;
    setState(() {
      _lecture = lue;
      // Une période constatée réglée perd sa mention, quelle que soit la lecture
      // qui l'a vue passer.
      if (h != null && lue.copieDu == null) {
        _enAttenteDeValidation.removeWhere((cle) => !_encoreDue(h, cle));
      }
    });
    if (h != null && lue.copieDu == null) widget.apresLecture?.call(h);
  }

  static bool _encoreDue(MesHonoraires h, String cle) =>
      h.periodes.any((p) => p.cle == cle && p.etat != EtatDHonoraires.reglee);

  Future<void> _payer(PeriodeDHonoraires periode) async {
    final envoyee = await ouvrirUneFeuille<bool>(
      context,
      glissable: false,
      construire: (_) => FeuilleDePaiement(
        objet: 'Honoraires · ${_periode(periode)}',
        montant: periode.montant,
        envoyer: (telephone) => widget.espace.demanderLeDebit(
          dossier: widget.dossier,
          periode: periode.cle,
          telephone: telephone,
        ),
        apresLePaiement:
            'La période passera à « Réglée » dès que l\'opérateur nous l\'aura confirmé.',
      ),
    );
    if (envoyee != true || !mounted) return;
    setState(() => _enAttenteDeValidation.add(periode.cle));
    final reglee = await suivreLePaiement(
      continuer: () => mounted,
      estRegle: () async {
        await _relire();
        return !_enAttenteDeValidation.contains(periode.cle);
      },
    );
    if (reglee && mounted) {
      annoncer(
        context,
        'Paiement reçu : la période « ${_periode(periode)} » est réglée.',
      );
    }
  }

  String get _base =>
      '/souscription/honoraires/${Uri.encodeComponent(widget.dossier)}';

  @override
  Widget build(BuildContext context) {
    final lecture = _lecture;
    final h = lecture?.valeur;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes honoraires')),
      body: RefreshIndicator(
        onRefresh: _relire,
        child: switch ((lecture, h)) {
          (null, _) => const Squelette(),
          (final Lecture<MesHonoraires> l, null) => EtatDePanne(
            serveurEnPanne: l.serveurEnPanne,
            horsLigne:
                'Vos honoraires se lisent sur le serveur. Ils reparaîtront dès que la connexion revient.',
            reessayer: _relire,
          ),
          (_, final MesHonoraires x) when !x.aUnContrat => const EtatVide(
            titre: 'Aucun contrat d\'honoraires',
            detail:
                'Le cabinet ne vous a encore rien facturé. Votre chargé de clientèle vous dira quand il le fera.',
            icone: Icons.receipt_long_outlined,
          ),
          (final Lecture<MesHonoraires> l, final MesHonoraires x) => _Contenu(
            honoraires: x,
            copieDu: l.copieDu,
            serveurEnPanne: l.serveurEnPanne,
            enAttenteDeValidation: _enAttenteDeValidation,
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
    this.copieDu,
    this.serveurEnPanne = false,
    this.enAttenteDeValidation = const {},
  });

  final MesHonoraires honoraires;

  /// Non nul : la page montre la dernière lecture gardée, de cet instant-là.
  final DateTime? copieDu;
  final bool serveurEnPanne;
  final Set<String> enAttenteDeValidation;
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
        if (copieDu != null) ...[
          BandeauHorsLigne(copieDu: copieDu!, serveurEnPanne: serveurEnPanne),
          const SizedBox(height: Marque.espace3),
        ],
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
                // ⚠️ Pas de paiement depuis une copie : la période est peut-être
                // déjà réglée, et la demande partirait pour rien.
                enLigne: h.reglableEnLigne && copieDu == null,
                enAttenteDeValidation: enAttenteDeValidation.contains(p.cle),
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
    this.enAttenteDeValidation = false,
  });

  final PeriodeDHonoraires periode;
  final bool enLigne;

  /// La demande de débit est partie ; l'opérateur ne l'a pas encore confirmée.
  final bool enAttenteDeValidation;
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
                      // ⚠️ 19 octobre 2026 : passé le jour d'exigibilité, la période
                      // n'est pas encore « en retard » (le cabinet laisse un délai),
                      // mais « à régler avant le 14 » le 19 se lisait comme une
                      // erreur. Elle est échue : on le dit.
                      retard
                          ? 'Due depuis le ${jourLong(p.exigibleLe)}'
                          : _echue(p.exigibleLe)
                          ? 'Échue le ${jourLong(p.exigibleLe)} : à régler sans tarder'
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
          if (enAttenteDeValidation) ...[
            const EnAttenteDeValidation(),
            if (enLigne)
              TextButton(
                key: Key('payer-${p.cle}'),
                onPressed: payer,
                child: const Text('Rien reçu ? Renvoyer la demande'),
              ),
          ] else if (enLigne)
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

/// Le jour d'exigibilité est passé.
bool _echue(DateTime exigibleLe, [DateTime? maintenant]) {
  final jour = DateUtils.dateOnly(maintenant ?? DateTime.now());
  return DateUtils.dateOnly(exigibleLe).isBefore(jour);
}
