import 'package:flutter/material.dart';

import '../marque.dart';
import 'package:flutter/services.dart';

import '../composants/carte.dart';
import '../composants/champ_de_recherche.dart';
import '../composants/porte_de_l_historique.dart';
import '../domaine/recherche.dart';
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
    this.ouvrirLHistorique,
  });

  final ServiceDeSession session;
  final List<String> dossiers;
  final VoidCallback quandSessionExpire;

  /// Ouvre l'historique des pièces REMISES par l'adhérent.
  ///
  /// ⚠️ DEUX SENS, ET C'EST TOUT LE PROPOS DE CETTE PORTE.
  ///
  /// Cet écran ne montre qu'un sens : ce que le cabinet a déposé POUR
  /// l'adhérent. L'autre sens — ce que l'adhérent a envoyé AU cabinet — vit sur
  /// un écran distinct, et rien ici n'y menait. Or « Documents » est l'onglet
  /// où l'on cherche un document, quel qu'en soit le sens : y taire la moitié
  /// de ses documents revenait à les cacher.
  final VoidCallback? ouvrirLHistorique;

  @override
  State<EcranDocuments> createState() => _EtatDesDocuments();
}

class _EtatDesDocuments extends State<EcranDocuments>
    with WidgetsBindingObserver {
  /// Ce qui est tapé dans le champ de recherche.
  ///
  /// ⚠️ TENU PAR L'ÉCRAN, et non par le champ : la liste se reconstruit à
  /// chaque frappe, et un état logé dans le champ se perdrait au premier
  /// rafraîchissement.
  String _recherche = '';

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
          (_, final Documents x) => _Liste(
            documents: x.documents,
            ouvrirLHistorique: widget.ouvrirLHistorique,
            recherche: _recherche,
            surRecherche: (v) => setState(() => _recherche = v),
          ),
        },
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.documents,
    required this.recherche,
    required this.surRecherche,
    this.ouvrirLHistorique,
  });

  final List<DocumentRecu> documents;
  final VoidCallback? ouvrirLHistorique;
  final String recherche;
  final ValueChanged<String> surRecherche;

  /// À partir de combien d'accusés le champ de recherche apparaît.
  ///
  /// ⚠️ HUIT : au-delà, la liste dépasse un écran de téléphone et l'on commence
  /// à faire défiler pour retrouver une ligne. En deçà, on lit les huit plus
  /// vite qu'on ne tape, et le champ n'est que du bruit en tête de page.
  static const seuilDeRecherche = 8;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    // ⚠️ Groupé par ANNÉE, et non par mois comme les pièces remises. Un accusé
    // se cherche par exercice — « les dépôts de 2024 » — parce que c'est la
    // maille dont l'administration parle quand elle en réclame un.
    // ⚠️ LE FILTRE PORTE SUR CE QUE L'ADHÉRENT CONNAÎT DE LA LIGNE : le numéro
    // qu'il recopie, le nom de la déclaration, la période, et le guichet. Pas
    // sur le montant : on ne cherche pas un accusé par son montant, et « 1 340 »
    // rendrait des lignes au hasard.
    final retenus = [
      for (final d in documents)
        if (correspond([d.numero, d.titre, d.periode, d.guichet], recherche)) d,
    ];
    final parAnnee = <int, List<DocumentRecu>>{};
    for (final d in retenus) {
      parAnnee.putIfAbsent(d.deposeLe.year, () => []).add(d);
    }
    return ListView(
      // ⚠️ La barre du bas flotte : le dernier accusé finirait dessous.
      padding: EdgeInsets.fromLTRB(
        Marque.espace4,
        Marque.espace4,
        Marque.espace4,
        // ⚠️ `…De(context)` et non la constante : la barre flotte AU-DESSUS de
        // l'encart système, que la constante seule ne couvre pas.
        Marque.espaceSousLaBarreDe(context),
      ),
      children: [
        Chapeau(
          titre: recherche.isEmpty
              ? '${documents.length} accusé${documents.length > 1 ? "s" : ""} '
                    'de dépôt'
              // ⚠️ Pendant une recherche, le compte porte sur ce qui est
              // MONTRÉ, sinon le chapeau annonce soixante-cinq lignes au-dessus
              // de trois.
              : '${retenus.length} sur ${documents.length}',
          detail:
              'Le cabinet a déposé ces déclarations en votre nom. Citez le '
              'numéro si l\'administration vous en demande la preuve.',
        ),
        if (ouvrirLHistorique != null) ...[
          const SizedBox(height: 14),
          PorteDeLHistorique(surAppui: ouvrirLHistorique!),
        ],
        if (documents.length >= seuilDeRecherche) ...[
          const SizedBox(height: 14),
          ChampDeRecherche(
            valeur: recherche,
            surChangement: surRecherche,
            invite: 'Numéro, déclaration, période…',
          ),
        ],
        // ⚠️ « Rien ne correspond » et JAMAIS « aucun accusé » : dire à un
        // adhérent que le cabinet n'a rien déposé pour lui, alors que c'est sa
        // recherche qui ne rend rien, est le message qui fait appeler en
        // urgence.
        if (retenus.isEmpty)
          RienNeCorrespond(
            recherche: recherche,
            surEffacer: () => surRecherche(''),
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
              Expanded(
                child: Divider(color: couleurs.outlineVariant, height: 1),
              ),
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
    return Carte(
      relief: ReliefDeCarte.liste,
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: couleurs.onSurfaceVariant),
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
            borderRadius: BorderRadius.circular(Marque.rayonBloc),
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

String _jour(DateTime d) =>
    '${d.day} ${_moisEnFrancais[d.month - 1]} ${d.year}';

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
