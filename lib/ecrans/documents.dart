import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domaine/document_recu.dart';
import '../ports/service_de_session.dart';

/// Ce que le cabinet a déposé pour l'adhérent, et la preuve qu'il l'a fait.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ LE NUMÉRO EST LE DOCUMENT
///
/// Un accusé de dépôt n'est pas un fichier à ouvrir : c'est un NUMÉRO, celui que
/// le guichet a rendu, et c'est la seule référence que l'administration
/// reconnaîtra. L'écran est donc construit autour de lui : il se lit, il se
/// copie d'un geste, et il ne se tronque jamais.
///
/// ⚠️ ET L'ÉCRAN DIT QUAND LA PREUVE EST FAIBLE. Quand aucun justificatif n'est
/// archivé avec l'accusé, celui-ci repose sur la parole de celui qui a saisi le
/// numéro. Le taire laisserait un adhérent s'appuyer dessus devant
/// l'administration en croyant tenir une pièce.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranDocuments extends StatefulWidget {
  const EcranDocuments({
    super.key,
    required this.session,
    required this.dossiers,
    required this.quandSessionExpire,
  });

  final ServiceDeSession session;
  final List<String> dossiers;
  final VoidCallback quandSessionExpire;

  @override
  State<EcranDocuments> createState() => _EtatDesDocuments();
}

class _EtatDesDocuments extends State<EcranDocuments>
    with WidgetsBindingObserver {
  Documents? _documents;
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
    if (etat == AppLifecycleState.resumed) _relire();
  }

  Future<void> _relire() async {
    setState(() => _lectureEnCours = true);
    final lu = await widget.session.mesDocuments(_dossier);
    if (!mounted) return;
    setState(() {
      _documents = lu;
      _lectureEnCours = false;
    });
    if (lu.sessionAExpire) widget.quandSessionExpire();
  }

  @override
  Widget build(BuildContext context) {
    final d = _documents;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes documents'),
        actions: [
          if (widget.dossiers.length > 1)
            PopupMenuButton<String>(
              key: const Key('choix-dossier-documents'),
              initialValue: _dossier,
              tooltip: 'Changer de dossier',
              icon: const Icon(Icons.folder_outlined),
              onSelected: (x) {
                setState(() => _dossier = x);
                _relire();
              },
              itemBuilder: (_) => [
                for (final x in widget.dossiers)
                  PopupMenuItem(value: x, child: Text(x)),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _relire,
        child: switch ((_lectureEnCours, d)) {
          (true, null) => const Center(
            key: Key('documents-en-attente'),
            child: CircularProgressIndicator(),
          ),
          (_, null) => const _RienDuTout(
            titre: 'Documents indisponibles',
            detail: 'Le serveur n\'a pas répondu.',
            icone: Icons.cloud_off_outlined,
          ),
          (_, final Documents x) when x.sessionAExpire => const _RienDuTout(
            titre: 'Session expirée',
            detail: 'Reconnectez-vous pour consulter vos accusés de dépôt.',
            icone: Icons.lock_outline,
          ),
          (_, final Documents x) when !x.serveurJoignable => const _RienDuTout(
            // ⚠️ Jamais « aucun document » : dire à un adhérent que le cabinet
            // n'a rien déposé pour lui, parce que le réseau manquait, est
            // exactement le message qui fait appeler en urgence.
            titre: 'Pas de réseau',
            detail:
                'Vos accusés de dépôt se lisent sur le serveur. Ils '
                'reparaîtront dès que la connexion revient.',
            icone: Icons.wifi_off_outlined,
          ),
          (_, final Documents x) when x.documents.isEmpty => const _RienDuTout(
            titre: 'Aucun accusé de dépôt',
            detail:
                'Le cabinet n\'a encore consigné aucun dépôt à votre nom. Les '
                'accusés apparaîtront ici au fur et à mesure.',
            icone: Icons.inbox_outlined,
          ),
          (_, final Documents x) => _Liste(documents: x.documents),
        },
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({required this.documents});

  final List<DocumentRecu> documents;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    // ⚠️ Groupé par ANNÉE, et non par mois comme les pièces remises. Un accusé
    // se cherche par exercice — « les dépôts de 2024 » — parce que c'est la
    // maille dont l'administration parle quand elle en réclame un.
    final parAnnee = <int, List<DocumentRecu>>{};
    for (final d in documents) {
      parAnnee.putIfAbsent(d.deposeLe.year, () => []).add(d);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: couleurs.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${documents.length} accusé${documents.length > 1 ? "s" : ""} '
                'de dépôt',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: couleurs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Le cabinet a déposé ces déclarations en votre nom. Citez le '
                'numéro si l\'administration vous en demande la preuve.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: couleurs.onPrimaryContainer.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        for (final annee in parAnnee.keys) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                '$annee',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: couleurs.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${parAnnee[annee]!.length}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: couleurs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: couleurs.outlineVariant, height: 1)),
            ],
          ),
          const SizedBox(height: 10),
          for (final d in parAnnee[annee]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Carte(document: d),
            ),
        ],
      ],
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({required this.document});

  final DocumentRecu document;

  @override
  Widget build(BuildContext context) {
    final d = document;
    final couleurs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: couleurs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleurs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  d.titre,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: couleurs.onSurface,
                  ),
                ),
              ),
              if (d.montantConstate != null)
                Text(
                  _montant(d.montantConstate!),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: couleurs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${d.periode} · ${d.guichet} · déposé le ${_jour(d.deposeLe)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: couleurs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // ⚠️ LE NUMÉRO, ET LE GESTE DE LE COPIER.
          //
          // C'est la seule référence que l'administration reconnaîtra. Le lire à
          // voix haute au téléphone ou le recopier à la main invite la faute ;
          // un appui le met dans le presse-papiers.
          InkWell(
            key: Key('copier-${d.numero}'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: d.numero));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Numéro ${d.numero} copié')),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      d.numero,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: couleurs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.copy_rounded,
                    size: 17,
                    color: couleurs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          if (!d.verifiable) ...[
            const SizedBox(height: 8),
            // ⚠️ La nuance que l'adhérent doit connaître AVANT de s'appuyer sur
            // cet accusé. Sans justificatif archivé, il repose sur la parole de
            // celui qui a saisi le numéro.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 15,
                  color: couleurs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Aucun justificatif n\'est archivé avec cet accusé : il '
                    'repose sur le numéro saisi par le cabinet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: couleurs.onSurfaceVariant,
                      height: 1.4,
                    ),
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

const _moisEnFrancais = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String _jour(DateTime d) => '${d.day} ${_moisEnFrancais[d.month - 1]} ${d.year}';

/// « 1 340 000 F » : tranches de trois, séparées par une espace.
String _montant(double v) {
  final entier = v.round().toString();
  final tranches = <String>[];
  for (var fin = entier.length; fin > 0; fin -= 3) {
    tranches.insert(0, entier.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
  }
  return '${tranches.join(' ')} F';
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
