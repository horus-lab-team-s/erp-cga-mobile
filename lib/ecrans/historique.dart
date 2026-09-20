import 'package:flutter/material.dart';

import '../domaine/piece_remise.dart';
import '../ports/service_de_session.dart';

/// Ce que le cabinet détient, et où chaque pièce en est.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ L'ÉCRAN QUI MANQUAIT, ET CE QUE SON ABSENCE COÛTAIT
///
/// L'application savait faire partir une pièce, et c'est tout. Une fois la file
/// vidée, l'accueil affichait « tout est parti » et plus rien : aucune trace des
/// deux cents justificatifs déjà remis. L'adhérent ne pouvait répondre à aucune
/// des trois questions qu'il se pose réellement :
///
///   · « Est-ce que j'ai envoyé la facture de mardi ? »
///   · « Le cabinet l'a-t-il seulement regardée ? »
///   · « Combien de pièces ai-je fournies ce mois-ci ? »
///
/// Faute de réponse dans l'application, il appelait le cabinet — et la promesse
/// du produit, qui est d'ÉPARGNER ces appels, tombait au premier usage.
///
/// ⚠️ TOUT SE LIT SUR LE SERVEUR. Voir l'en-tête de `piece_remise.dart` : un
/// historique tenu sur l'appareil se figerait sur « envoyée », mourrait avec le
/// téléphone, et ignorerait les pièces arrivées par courriel.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranHistorique extends StatefulWidget {
  const EcranHistorique({
    super.key,
    required this.session,
    required this.dossiers,
    required this.quandSessionExpire,
  });

  final ServiceDeSession session;

  /// Les dossiers du compte. ⚠️ Passés par l'accueil, qui les a déjà lus : les
  /// relire ici ferait un deuxième aller-retour pour la même réponse, sur un
  /// réseau qu'on sait mauvais.
  final List<String> dossiers;

  /// Appelé quand le serveur répond que la session n'est plus valable. L'écran
  /// ne décide pas lui-même de renvoyer à la connexion : c'est l'affaire de
  /// celui qui l'a ouvert.
  final VoidCallback quandSessionExpire;

  @override
  State<EcranHistorique> createState() => _EtatDeLHistorique();
}

/// ⚠️ `WidgetsBindingObserver` : l'écran REDEMANDE au serveur chaque fois que
/// l'adhérent revient dans l'application.
///
/// Constaté sur le TECNO, et par accident : le téléphone est passé sur une autre
/// application pendant l'essai, le comptable a lu une pièce dans l'intervalle, et
/// au retour l'historique affichait encore l'état d'avant — « Reçue par le
/// cabinet » sur une pièce déjà lue, et « 7 prises en compte » au lieu de 8.
///
/// Rien ne signalait que la liste était périmée, et c'est ce qui rend le défaut
/// grave : un écran qui se trompe sans le dire vaut moins qu'un écran vide. Pour
/// cet écran-là en particulier, l'adhérent pose son téléphone, rappelle le
/// cabinet, revient — et reprend une conversation sur des chiffres faux.
///
/// Le geste de tirer vers le bas existe, mais il suppose qu'on se DOUTE que la
/// liste a vieilli. Personne ne s'en doute.
class _EtatDeLHistorique extends State<EcranHistorique>
    with WidgetsBindingObserver {
  Historique? _historique;
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
    // ⚠️ Se retirer, faute de quoi la plateforme garde une référence sur un
    // état détruit et rappelle `didChangeAppLifecycleState` dessus.
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    // ⚠️ `resumed` SEULEMENT, et pas `inactive`. Sur Android, un simple
    // déroulé du volet de notifications passe par `inactive` : relire à chaque
    // fois ferait des appels que rien ne justifie, sur un forfait que l'adhérent
    // paie.
    if (etat == AppLifecycleState.resumed) {
      _relire();
    }
  }

  Future<void> _relire() async {
    setState(() => _lectureEnCours = true);
    final lu = await widget.session.mesPieces(_dossier);
    if (!mounted) {
      return;
    }
    setState(() {
      _historique = lu;
      _lectureEnCours = false;
    });
    if (lu.sessionAExpire) {
      widget.quandSessionExpire();
    }
  }

  @override
  Widget build(BuildContext context) {
    final historique = _historique;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pièces remises'),
        actions: [
          // ⚠️ Le sélecteur ne paraît QUE si le compte a plusieurs dossiers.
          // Une liste déroulante à un seul choix est un bouton qui ne fait
          // rien : elle occupe la barre et apprend à l'adhérent à la toucher
          // pour rien.
          if (widget.dossiers.length > 1)
            PopupMenuButton<String>(
              key: const Key('choix-dossier'),
              initialValue: _dossier,
              tooltip: 'Changer de dossier',
              icon: const Icon(Icons.folder_outlined),
              onSelected: (dossier) {
                setState(() => _dossier = dossier);
                _relire();
              },
              itemBuilder: (_) => [
                for (final dossier in widget.dossiers)
                  PopupMenuItem(value: dossier, child: Text(dossier)),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _relire,
        child: switch ((_lectureEnCours, historique)) {
          // ⚠️ L'attente n'est montrée qu'à la PREMIÈRE lecture. Sur un
          // rafraîchissement, la liste reste en place sous l'anneau du geste :
          // la remplacer par un écran vide donnerait l'impression, une seconde,
          // que l'historique a disparu.
          (true, null) => const _EnAttente(),
          (_, null) => const _RienDuTout(
            titre: 'Historique indisponible',
            detail: 'Le serveur n\'a pas répondu.',
            icone: Icons.cloud_off_outlined,
          ),
          (_, final Historique h) when h.sessionAExpire => const _RienDuTout(
            titre: 'Session expirée',
            detail:
                'Reconnectez-vous pour consulter les pièces que le cabinet détient.',
            icone: Icons.lock_outline,
          ),
          (_, final Historique h) when !h.serveurJoignable => const _RienDuTout(
            // ⚠️ « Le réseau manque », et surtout PAS « aucune pièce ». Voir
            // l'en-tête de `Historique` : la confusion entre les deux afficherait
            // un dossier vide à quelqu'un qui a tout déposé.
            titre: 'Pas de réseau',
            detail:
                'Vos pièces remises sont chez le cabinet ; cette liste se lit '
                'sur le serveur. Elle reparaîtra dès que la connexion revient.',
            icone: Icons.wifi_off_outlined,
          ),
          (_, final Historique h) when h.pieces.isEmpty => const _RienDuTout(
            titre: 'Aucune pièce remise',
            detail:
                'Les justificatifs que vous photographiez apparaîtront ici une '
                'fois arrivés au cabinet.',
            icone: Icons.inbox_outlined,
          ),
          (_, final Historique h) => _Liste(historique: h),
        },
      ),
    );
  }
}

/// La liste, groupée par mois.
class _Liste extends StatelessWidget {
  const _Liste({required this.historique});

  final Historique historique;

  @override
  Widget build(BuildContext context) {
    // ⚠️ GROUPÉ PAR MOIS, et le mois est le bon découpage : c'est la maille de
    // la comptabilité et celle dont l'adhérent parle au téléphone — « et les
    // pièces d'août ? ». Grouper par jour ferait trente titres pour trente
    // lignes ; ne pas grouper du tout laisserait une liste plate où l'on perd
    // la frontière entre deux exercices.
    final parMois = <String, List<PieceRemise>>{};
    for (final piece in historique.pieces) {
      parMois.putIfAbsent(_mois(piece.deposeLe), () => []).add(piece);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Bilan(historique: historique),
        for (final entree in parMois.entries) ...[
          const SizedBox(height: 24),
          _TitreDeMois(texte: entree.key, combien: entree.value.length),
          const SizedBox(height: 10),
          for (final piece in entree.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LignePiece(piece: piece),
            ),
        ],
      ],
    );
  }
}

/// La phrase qui conclut, avant le détail.
///
/// ⚠️ Même parti pris que le verdict de l'accueil : on répond d'abord, on
/// détaille ensuite. « 12 pièces remises, 3 déjà comptabilisées » se lit en une
/// seconde ; la même information répartie sur douze lignes demande de compter.
class _Bilan extends StatelessWidget {
  const _Bilan({required this.historique});

  final Historique historique;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final total = historique.pieces.length;
    final prises = historique.prisesEnCompte;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: couleurs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$total pièce${total > 1 ? "s" : ""} au cabinet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: couleurs.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            // ⚠️ Les deux cas sont écrits en toutes lettres plutôt qu'avec un
            // « 0 » : « aucune n'a encore été traitée » est une phrase, « 0
            // traitée » est un relevé. La première dit à l'adhérent qu'il n'a
            // rien à faire, la seconde le laisse se demander si c'est normal.
            prises == 0
                ? 'Aucune n\'a encore été traitée. Le cabinet les reprend par lot.'
                : '$prises déjà prise${prises > 1 ? "s" : ""} en compte par le cabinet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: couleurs.onPrimaryContainer.withValues(alpha: 0.82),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TitreDeMois extends StatelessWidget {
  const _TitreDeMois({required this.texte, required this.combien});

  final String texte;
  final int combien;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          texte,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: couleurs.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$combien',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: couleurs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: couleurs.outlineVariant, height: 1)),
      ],
    );
  }
}

/// Une pièce, avec ce que le cabinet en a tiré.
class _LignePiece extends StatelessWidget {
  const _LignePiece({required this.piece});

  final PieceRemise piece;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final detail = [
      if (piece.emetteur != null) _jour(piece.deposeLe),
      if (piece.referenceDocument != null) piece.referenceDocument!,
      if (piece.canal != 'MOBILE') _canal(piece.canal),
    ];
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
                  // ⚠️ L'ÉMETTEUR EN TITRE DÈS QUE LE CABINET L'A LU, et la date
                  // sinon. C'est la preuve visible que quelqu'un a ouvert la
                  // photo : voir « ENEO » remplacer « Pièce du 12 septembre »,
                  // c'est constater le travail, pas le croire sur parole.
                  piece.emetteur ?? 'Pièce du ${_jour(piece.deposeLe)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: couleurs.onSurface,
                  ),
                ),
              ),
              if (piece.montantTtc != null)
                Text(
                  _montant(piece.montantTtc!),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: couleurs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          // ⚠️ LA LIGNE DE DÉTAIL N'EXISTE QUE SI ELLE A QUELQUE CHOSE À DIRE.
          //
          // Mesuré sur le TECNO : une pièce photographiée que le cabinet n'a
          // pas encore ouverte n'a ni émetteur, ni référence, et son canal est
          // le téléphone — les trois morceaux sont donc absents. Le `Text` vide
          // restait pourtant là, entre deux marges, et creusait sous le titre un
          // blanc de vingt pixels qu'aucune ligne ne venait occuper. Les quatre
          // pièces de septembre paraissaient mal composées, et elles l'étaient.
          //
          // Le canal n'est cité que s'il n'est PAS le téléphone : écrire
          // « envoyée depuis le mobile » sous chaque ligne d'une application
          // mobile est une répétition ; écrire « reçue par courriel » sous
          // celles qui le sont est un renseignement.
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detail.join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: couleurs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Avancement(etat: piece.etat),
        ],
      ),
    );
  }
}

/// Où en est la pièce, en mots ET en segments.
///
/// ⚠️ LES DEUX, ET C'EST UNE RÈGLE DU DOSSIER DE DESIGN : « la couleur ne porte
/// jamais seule une information ». Cinq segments qui se remplissent disent
/// l'avancement d'un coup d'œil, mais un daltonien, un écran au soleil ou une
/// capture en noir et blanc les rendent muets. Le libellé est donc écrit à côté,
/// et c'est lui qui fait foi.
class _Avancement extends StatelessWidget {
  const _Avancement({required this.etat});

  final EtatChezLeCabinet etat;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    // ⚠️ L'INDIGO DE L'INSTITUTION, et non un vert « succès ».
    //
    // Le dossier de design n'admet que deux couleurs de marque : l'indigo de
    // l'institution et le magenta de l'action. Un vert venu d'ailleurs ferait
    // une troisième couleur dans un produit qui en tient deux.
    //
    // Entre les deux, c'est l'indigo : cette barre ne montre pas une action de
    // l'adhérent, elle montre le TRAVAIL DU CABINET sur sa pièce. Le magenta est
    // réservé à ce qu'on lui demande de faire — photographier, envoyer — et
    // l'étaler sur ce qu'il n'a pas à faire lui ôterait sa valeur d'appel.
    //
    // ⚠️ Ce commentaire affirmait le contraire de ce que la ligne suivante fait,
    // et la ligne était juste. Un commentaire qui ment coûte plus cher qu'un
    // commentaire absent : le prochain lecteur corrige le code pour le mettre
    // d'accord avec lui.
    final faite = couleurs.secondary;
    return Row(
      children: [
        for (var rang = 0; rang < EtatChezLeCabinet.values.length; rang++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: rang <= etat.rang ? faite : couleurs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (rang < EtatChezLeCabinet.values.length - 1)
            const SizedBox(width: 3),
        ],
        const SizedBox(width: 10),
        Text(
          etat.libelle,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: etat.priseEnCompte ? faite : couleurs.onSurfaceVariant,
            fontWeight: etat.priseEnCompte ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EnAttente extends StatelessWidget {
  const _EnAttente();

  @override
  Widget build(BuildContext context) => const Center(
    key: Key('historique-en-attente'),
    child: CircularProgressIndicator(),
  );
}

/// Un état vide qui DIT POURQUOI. Jamais une liste vide muette : voir l'en-tête
/// de `Historique`.
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
    // ⚠️ `ListView` et non `Center` : le geste de tirer pour rafraîchir ne
    // fonctionne que sur une zone qui défile. Avec un `Center`, l'adhérent sans
    // réseau se retrouvait devant un message qu'aucun geste ne pouvait relancer.
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

const _moisEnFrancais = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

String _mois(DateTime date) => '${_moisEnFrancais[date.month - 1]} ${date.year}';

String _jour(DateTime date) =>
    '${date.day} ${_moisEnFrancais[date.month - 1].toLowerCase()}';

/// « 45 000 F ». ⚠️ Le franc CFA s'écrit par tranches de trois, séparées par une
/// espace et non par une virgule : « 45,000 » se lit comme quarante-cinq à
/// virgule chez un lecteur francophone.
String _montant(double valeur) {
  final entier = valeur.round().toString();
  final tranches = <String>[];
  for (var fin = entier.length; fin > 0; fin -= 3) {
    tranches.insert(0, entier.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
  }
  return '${tranches.join(' ')} F';
}

/// ⚠️ Les six canaux du serveur, et AUCUN autre. Cette fonction en listait
/// quatre inventés de mémoire — « DEPOT », « SCAN » — qui n'existent nulle part
/// côté serveur, tandis que WhatsApp et l'import bancaire, eux bien réels,
/// tombaient dans le cas par défaut et s'affichaient « import_bancaire ».
String _canal(String canal) => switch (canal) {
  'COURRIEL' => 'reçue par courriel',
  'WHATSAPP' => 'reçue par WhatsApp',
  'PORTAIL' => 'déposée sur le portail',
  'IMPORT_BANCAIRE' => 'relevé importé',
  'DEPOT_CABINET' => 'remise en main propre',
  _ => canal.toLowerCase().replaceAll('_', ' '),
};
