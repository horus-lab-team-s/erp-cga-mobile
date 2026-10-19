import 'dart:async';

import 'package:flutter/material.dart';

import '../adaptateurs/numero_memorise.dart';
import '../domaine/honoraires.dart';
import '../marque.dart';
import 'actions.dart';

/// La feuille d'un paiement par mobile money (18 octobre 2026) : récapituler,
/// demander le numéro, envoyer, puis dire quoi faire.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// UNE FEUILLE POUR TOUS LES PAIEMENTS : les honoraires du cabinet, et les fonds
/// confiés pour payer la TVA ou la CNPS. L'adhérent apprend un seul geste.
///
/// ⚠️ « ENVOYÉE » N'EST PAS « PAYÉE ». La demande arrive sur son téléphone ; il
/// valide avec son code ; c'est la notification de l'opérateur qui constate le
/// paiement. La feuille se ferme sur `true`, et l'écran appelant relit le serveur.
/// ─────────────────────────────────────────────────────────────────────────────
class FeuilleDePaiement extends StatefulWidget {
  const FeuilleDePaiement({
    super.key,
    required this.objet,
    required this.montant,
    required this.envoyer,
    this.apresLePaiement,
  });

  /// « Honoraires · septembre 2026 », « CNPS · juillet 2026 ».
  final String objet;
  final int montant;

  /// Envoie la demande avec le numéro saisi, sans espaces.
  final Future<DemandeDeDebit> Function(String telephone) envoyer;

  /// Ce qui se passe après la validation, dit à l'adhérent.
  final String? apresLePaiement;

  @override
  State<FeuilleDePaiement> createState() => _EtatDeLaFeuilleDePaiement();
}

class _EtatDeLaFeuilleDePaiement extends State<FeuilleDePaiement> {
  final _numero = TextEditingController();
  bool _enCours = false;
  DemandeDeDebit? _sort;

  @override
  void initState() {
    super.initState();
    _preremplir();
  }

  Future<void> _preremplir() async {
    final connu = await NumeroMemorise.lire();
    if (connu != null && mounted && _numero.text.isEmpty) _numero.text = connu;
  }

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
    final sort = await widget.envoyer(numero);
    // Sans attendre : la mémoire ne doit pas retenir l'écran.
    if (sort.sort == SortDuDebit.envoyee) {
      unawaited(NumeroMemorise.retenir(numero));
    }
    if (!mounted) return;
    setState(() {
      _enCours = false;
      _sort = sort;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ 19 octobre 2026 : pendant l'envoi, la feuille ne se ferme ni par le retour
    // ni par un appui à côté. Fermée en route, la demande partait sans que l'écran
    // le dise, et l'adhérent recommençait.
    return PopScope(canPop: !_enCours, child: _contenu(context));
  }

  Widget _contenu(BuildContext context) {
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
            decoration: const BoxDecoration(
              color: Marque.reussite100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_android,
              size: 36,
              color: Marque.reussite,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Validez sur votre téléphone',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'La demande de ${montantFcfa(widget.montant)} est partie. Composez votre code secret sur le '
                    'message de votre opérateur. ${widget.apresLePaiement ?? ''}'
                .trim(),
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
            'Une demande est déjà en cours : validez-la sur votre téléphone.',
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
                child: Text(widget.objet, style: theme.textTheme.bodyMedium),
              ),
              Text(
                montantFcfa(widget.montant),
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
            // Espaces insécables : « 45 000 / F » se coupait, le F seul à la ligne.
            libelle:
                'Envoyer la demande de ${montantFcfa(widget.montant).replaceAll(' ', '\u00A0')}',
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

/// La mention d'une carte dont la demande de débit est partie (20 octobre 2026).
///
/// ⚠️ Elle remplace le bouton « Payer » : laissé en place, il invitait à payer une
/// seconde fois une période que l'adhérent venait de valider sur son téléphone.
class EnAttenteDeValidation extends StatelessWidget {
  const EnAttenteDeValidation({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('paiement-en-attente'),
        width: double.infinity,
        padding: const EdgeInsets.all(Marque.espace3),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(Marque.rayonBloc + 4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 20,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: Marque.espace2 + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paiement en attente de validation',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Composez votre code sur le message de l\'opérateur. La carte '
                    'change dès que le paiement est confirmé.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
