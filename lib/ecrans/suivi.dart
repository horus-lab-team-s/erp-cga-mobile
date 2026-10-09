import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/carte.dart';
import '../composants/joindre.dart';
import '../contenu/cabinet.dart';
import '../domaine/suivi.dart';
import '../marque.dart';
import '../ports/service_public.dart';

/// Suivre une souscription, avant même d'avoir un compte.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ L'ÉCRAN QUI MANQUAIT ENTRE « PAYER » ET « ENTRER ».
///
/// Après le paiement, l'application disait « validez sur votre téléphone »,
/// donnait une référence… et c'était tout. Le souscripteur ne savait pas si
/// l'argent était arrivé, ni pourquoi son lien d'accès tardait : il ignorait
/// qu'une vérification d'identité s'intercale. Il appelait le cabinet.
///
/// Cet écran répond à ces trois questions, dans l'ordre où elles se posent :
/// l'argent est-il arrivé, qu'est-ce qu'on attend encore, et quand paierai-je
/// ensuite.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranSuivi extends StatefulWidget {
  const EcranSuivi({
    super.key,
    required this.servicePublic,
    required this.reference,
  });

  final ServicePublic servicePublic;
  final String reference;

  @override
  State<EcranSuivi> createState() => _EtatDuSuivi();
}

class _EtatDuSuivi extends State<EcranSuivi> {
  LectureDuSuivi? _lecture;
  List<Mensualite>? _mensualites;

  @override
  void initState() {
    super.initState();
    _relire();
  }

  Future<void> _relire() async {
    final l = await widget.servicePublic.suivreUneSouscription(
      widget.reference,
    );
    List<Mensualite>? m;
    final s = l.suivi;
    // L'échéancier n'existe qu'une fois l'abonnement en vigueur : le demander
    // avant rendrait une liste vide qu'il faudrait encore expliquer.
    if (s != null && s.estUnAbonnement && s.prendEffetLe != null) {
      m = await widget.servicePublic.mensualites(
        widget.reference,
        // Six mois devant : assez pour voir venir, pas assez pour noyer.
        DateTime.now().add(const Duration(days: 183)),
      );
    }
    if (!mounted) return;
    setState(() {
      _lecture = l;
      _mensualites = m;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = _lecture;
    return Scaffold(
      appBar: AppBar(title: const Text('Ma souscription')),
      body: RefreshIndicator(
        onRefresh: _relire,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _Reference(reference: widget.reference),
            const SizedBox(height: 18),
            switch (l) {
              null => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              LectureDuSuivi(sort: SortDuSuivi.introuvable) => const Carte(
                key: Key('suivi-introuvable'),
                child: Text(
                  'Aucune souscription ne porte cette référence. Vérifiez-la : '
                  'elle commence par « SO- » et figure sur l\'écran de '
                  'paiement.',
                ),
              ),
              LectureDuSuivi(sort: SortDuSuivi.indisponible) => const Carte(
                key: Key('suivi-hors-ligne'),
                child: Text(
                  "Pas de réseau : l'état de la souscription n'a pas pu être "
                  'lu. Tirez vers le bas pour réessayer.',
                ),
              ),
              LectureDuSuivi(suivi: final s?) => _Corps(
                suivi: s,
                mensualites: _mensualites,
              ),
              _ => const SizedBox(),
            },
          ],
        ),
      ),
    );
  }
}

class _Reference extends StatelessWidget {
  const _Reference({required this.reference});
  final String reference;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Bloc(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Référence', style: texte.bodySmall),
                SelectableText(reference, style: texte.titleSmall),
              ],
            ),
          ),
          IconButton(
            key: const Key('copier-reference-suivi'),
            tooltip: 'Copier la référence',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: reference));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Référence copiée.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Corps extends StatelessWidget {
  const _Corps({required this.suivi, required this.mensualites});

  final SuiviDeSouscription suivi;
  final List<Mensualite>? mensualites;

  @override
  Widget build(BuildContext context) {
    final s = suivi;
    final texte = Theme.of(context).textTheme;
    final interrompue =
        s.etat == EtatDeLaSouscription.abandonnee ||
        s.etat == EtatDeLaSouscription.resiliee;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.libelle, style: texte.titleMedium),
        const SizedBox(height: 16),
        if (interrompue)
          Carte(
            key: const Key('suivi-interrompu'),
            ton: TonDeCarte.alerte,
            child: Text(
              s.etat == EtatDeLaSouscription.abandonnee
                  ? 'Le paiement n\'a pas abouti : rien n\'a été débité. '
                            '${s.motif ?? ''}'
                        .trim()
                  : 'Cette souscription est résiliée. ${s.motif ?? ''}'.trim(),
            ),
          )
        else
          _Etapes(suivi: s),
        if (mensualites != null) ...[
          const SizedBox(height: 26),
          Text('Vos mensualités', style: texte.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Chaque période se paie d\'avance, à la date anniversaire de '
            'votre adhésion.',
            style: texte.bodySmall,
          ),
          const SizedBox(height: 12),
          if (mensualites!.isEmpty)
            const Text('Aucune mensualité à venir pour le moment.')
          else
            for (final m in mensualites!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LigneDeMensualite(mensualite: m),
              ),
        ],
        const SizedBox(height: 26),
        OutlinedButton.icon(
          key: const Key('suivi-joindre'),
          onPressed: () =>
              joindre(context, Cabinet.whatsappLien, aCopier: Cabinet.whatsapp),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Une question ? Écrire au cabinet'),
        ),
      ],
    );
  }
}

/// La frise : ce qui est fait, ce qui est en cours, ce qui vient.
class _Etapes extends StatelessWidget {
  const _Etapes({required this.suivi});
  final SuiviDeSouscription suivi;

  @override
  Widget build(BuildContext context) {
    final s = suivi;
    final paye =
        s.etat == EtatDeLaSouscription.payee ||
        s.etat == EtatDeLaSouscription.activee;
    final active = s.etat == EtatDeLaSouscription.activee;

    final etapes = <(String, String, bool)>[
      (
        'Paiement demandé',
        s.engageeLe == null
            ? 'Validez la demande reçue sur votre téléphone avec votre code.'
            : 'Le ${_jour(s.engageeLe!)}. Validez la demande reçue sur votre '
                  'téléphone avec votre code.',
        true,
      ),
      (
        'Paiement reçu',
        paye
            ? 'Le ${_jour(s.payeeLe ?? DateTime.now())}.'
            : 'En attente de votre validation.',
        paye,
      ),
      if (s.ouvreUnAcces)
        (
          'Identité vérifiée par le cabinet',
          active
              ? 'Vérification faite.'
              // ⚠️ L'étape qu'on oublie : sans elle, l'écran ferait attendre
              // un lien qui ne peut pas encore partir.
              : paye
              ? 'Le cabinet vous contacte pour vérifier que vous représentez '
                    'l\'entreprise. Le NIU seul ne le prouve pas.'
              : 'Après le paiement.',
          active,
        ),
      (
        s.ouvreUnAcces ? 'Accès ouvert' : 'Prestation confirmée',
        active
            ? 'Le lien de connexion est parti à ${s.courriel}.'
            : s.ouvreUnAcces
            ? 'Le lien de connexion partira à ${s.courriel}.'
            : 'Le cabinet vous contacte pour la suite.',
        active || (paye && !s.ouvreUnAcces),
      ),
    ];
    // L'étape en cours est la première qui n'est pas faite.
    final enCours = etapes.indexWhere((e) => !e.$3);

    return Carte(
      key: const Key('suivi-etapes'),
      child: Column(
        children: [
          for (final (i, e) in etapes.indexed)
            _Etape(
              titre: e.$1,
              detail: e.$2,
              faite: e.$3,
              courante: i == enCours,
              derniere: i == etapes.length - 1,
            ),
        ],
      ),
    );
  }
}

class _Etape extends StatelessWidget {
  const _Etape({
    required this.titre,
    required this.detail,
    required this.faite,
    required this.courante,
    required this.derniere,
  });

  final String titre;
  final String detail;
  final bool faite;
  final bool courante;
  final bool derniere;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final teinte = faite
        ? Marque.reussite
        : courante
        ? couleurs.primary
        : couleurs.outline;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Icon(
                  faite
                      ? Icons.check_circle
                      : courante
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: teinte,
                  size: 24,
                ),
                if (!derniere)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: faite ? Marque.reussite : couleurs.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: derniere ? 0 : 18, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // ⚠️ L'état en MOT, pas seulement en couleur : « En cours »
                    // se lit sans distinguer le vert du violet.
                    faite
                        ? '$titre · fait'
                        : courante
                        ? '$titre · en cours'
                        : titre,
                    style: texte.titleSmall?.copyWith(
                      color: faite || courante
                          ? couleurs.onSurface
                          : couleurs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(detail, style: texte.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneDeMensualite extends StatelessWidget {
  const _LigneDeMensualite({required this.mensualite});
  final Mensualite mensualite;

  @override
  Widget build(BuildContext context) {
    final m = mensualite;
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    return Carte(
      ton: m.etat.alerte ? TonDeCarte.alerte : TonDeCarte.neutre,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Du ${_jourCourt(m.du)} au ${_jourCourt(m.au)}',
                  style: texte.titleSmall,
                ),
                const SizedBox(height: 4),
                Etiquette(
                  m.etat.libelle,
                  couleur: switch (m.etat) {
                    EtatDeMensualite.reglee => Marque.reussite,
                    EtatDeMensualite.impayee ||
                    EtatDeMensualite.enDefaut => couleurs.error,
                    _ => null,
                  },
                ),
              ],
            ),
          ),
          Text(
            _francs(m.montant),
            style: texte.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

const _mois = [
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

String _jour(DateTime d) => '${d.day} ${_mois[d.month - 1]} ${d.year}';
String _jourCourt(DateTime d) => '${d.day} ${_mois[d.month - 1]}';

String _francs(double v) {
  final e = v.round().toString();
  final t = <String>[];
  for (var f = e.length; f > 0; f -= 3) {
    t.insert(0, e.substring(f - 3 < 0 ? 0 : f - 3, f));
  }
  return '${t.join(' ')} F';
}
