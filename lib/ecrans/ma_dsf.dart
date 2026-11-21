import 'package:flutter/material.dart';

import '../composants/actions.dart';
import '../composants/carte.dart';
import '../composants/etat.dart';
import '../composants/source_d_image.dart';
import '../domaine/ma_dsf.dart';
import '../domaine/prise_de_vue.dart';
import '../marque.dart';
import '../ports/service_de_l_espace.dart';

/// Ma déclaration annuelle (DSF) : où elle en est, et les pièces à fournir
/// (18 octobre 2026, point 24). La même vue que l'espace web.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ LE DERNIER EXERCICE D'ABORD, LES AUTRES REPLIÉS. Sur le web, trois
/// exercices dépliés faisaient une page interminable sur téléphone ; ici, le
/// plus récent est ouvert et les autres se déplient au toucher.
///
/// ⚠️ UNE PIÈCE SE PHOTOGRAPHIE. Le cabinet accepte un scan ou une photo nette ;
/// l'envoi part aussitôt, et la ligne passe à « Reçue » quand le serveur l'a.
///
/// ⚠️ « SANS OBJET » N'EST PAS UN GESTE DE L'ADHÉRENT : une pièce qui ne le
/// concerne pas (prix de transfert, droits d'accises), il le dit au cabinet,
/// qui la marque.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranMaDsf extends StatefulWidget {
  const EcranMaDsf({
    super.key,
    required this.espace,
    required this.dossier,
    required this.priseDeVue,
    required this.quandSessionExpire,
    required this.ouvrirDocument,
  });

  final ServiceDeLEspace espace;

  /// Le dossier choisi dans l'en-tête de l'accueil (20 octobre 2026).
  final String dossier;
  final PriseDeVue priseDeVue;
  final VoidCallback quandSessionExpire;
  final void Function(String chemin, String titre) ouvrirDocument;

  @override
  State<EcranMaDsf> createState() => _EtatDeMaDsf();
}

class _EtatDeMaDsf extends State<EcranMaDsf> {
  String get _dossier => widget.dossier;
  Lecture<MaDsf>? _lecture;

  /// La pièce en cours d'envoi : « exercice/numéro ».
  String? _envoi;

  @override
  void initState() {
    super.initState();
    _relire();
  }

  Future<void> _relire() async {
    final lue = await widget.espace.maDsf(_dossier);
    if (!mounted) return;
    if (lue.sessionAExpire) {
      widget.quandSessionExpire();
      return;
    }
    setState(() => _lecture = lue);
  }

  @override
  void didUpdateWidget(EcranMaDsf ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.dossier != widget.dossier) {
      setState(() => _lecture = null);
      _relire();
    }
  }

  /// ⚠️ 20 octobre 2026 : « Remplacer » écrasait d'un appui la pièce que le cabinet
  /// avait déjà reçue, à côté du bouton qu'on touche pour l'envoyer. On demande.
  Future<bool> _confirmerLeRemplacement(MaPieceDsf piece) async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Remplacer cette pièce ?'),
        content: Text(
          'Le cabinet a déjà reçu « ${piece.libelle} »'
          '${piece.nomDuFichier == null ? '' : ' (${piece.nomDuFichier})'}. '
          'La nouvelle prendra sa place.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: const Text('Garder l\'actuelle'),
          ),
          FilledButton(
            key: const Key('confirmer-remplacement'),
            onPressed: () => Navigator.of(contexte).pop(true),
            child: const Text('Remplacer'),
          ),
        ],
      ),
    );
    return oui == true;
  }

  Future<void> _envoyer(MaDsfDeLExercice exercice, MaPieceDsf piece) async {
    if (piece.etat == EtatDeMaPiece.jointe &&
        !await _confirmerLeRemplacement(piece)) {
      return;
    }
    if (!mounted) return;
    final chemin = await obtenirUneImage(context, widget.priseDeVue);
    if (chemin == null || !mounted) return;
    setState(() => _envoi = '${exercice.exercice}/${piece.numero}');
    final sort = await widget.espace.verserUnePieceDsf(
      dossier: _dossier,
      exercice: exercice.exercice,
      numero: piece.numero,
      cheminDuFichier: chemin,
    );
    if (!mounted) return;
    setState(() => _envoi = null);
    switch (sort) {
      case SortDuVersement.recue:
        annoncer(context, '« ${piece.libelle} » est bien arrivée au cabinet.');
        await _relire();
      case SortDuVersement.sessionExpiree:
        widget.quandSessionExpire();
      case SortDuVersement.tropLourde:
        annoncer(
          context,
          'La photo dépasse 15 Mo. Reprenez-la d\'un peu plus loin.',
          echec: true,
        );
      case SortDuVersement.formatRefuse:
        annoncer(
          context,
          'Ce fichier n\'est ni une photo ni un PDF lisible.',
          echec: true,
        );
      case SortDuVersement.refusee:
        annoncer(
          context,
          'Le cabinet a déjà traité cette pièce : écrivez-lui pour la changer.',
          echec: true,
        );
        await _relire();
      case SortDuVersement.indisponible:
        annoncer(
          context,
          'Le serveur n\'a pas répondu. Vérifiez la connexion, puis réessayez.',
          echec: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lecture = _lecture;
    final dsf = lecture?.valeur;
    return Scaffold(
      appBar: AppBar(title: const Text('Ma déclaration annuelle')),
      body: RefreshIndicator(
        onRefresh: _relire,
        child: switch ((lecture, dsf)) {
          (null, _) => const Squelette(chapeau: false, cartes: 2),
          (final Lecture<MaDsf> l, null) => EtatDePanne(
            serveurEnPanne: l.serveurEnPanne,
            horsLigne:
                'L\'état de votre DSF se lit sur le serveur. Il reparaîtra dès que la connexion revient.',
            reessayer: _relire,
          ),
          (_, final MaDsf x) when x.exercices.isEmpty => const EtatVide(
            titre: 'Aucun exercice clos',
            detail:
                'Votre première DSF apparaîtra ici après la clôture de l\'exercice.',
            icone: Icons.event_note_outlined,
          ),
          (final Lecture<MaDsf> l, final MaDsf x) => ListView(
            padding: EdgeInsets.fromLTRB(
              Marque.espace4,
              Marque.espace4,
              Marque.espace4,
              Marque.espaceSousLaBarreDe(context),
            ),
            children: [
              if (l.copieDu != null) ...[
                BandeauHorsLigne(
                  copieDu: l.copieDu!,
                  serveurEnPanne: l.serveurEnPanne,
                ),
                const SizedBox(height: Marque.espace3),
              ],
              Text(
                'Après la clôture de l\'exercice, le cabinet établit votre déclaration statistique et fiscale et la '
                'dépose sur le portail de la DGI. Il lui faut quelques pièces que vous seul détenez.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              for (final (i, e) in x.exercices.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Exercice(
                    exercice: e,
                    ouvert: i == 0,
                    envoi: _envoi,
                    envoyer: (p) => _envoyer(e, p),
                    voirLaCopie: () => widget.ouvrirDocument(
                      '/cloture/dossiers/${Uri.encodeComponent(_dossier)}/ma-dsf/'
                          '${Uri.encodeComponent(e.exercice)}/document',
                      'DSF ${e.exercice}',
                    ),
                  ),
                ),
            ],
          ),
        },
      ),
    );
  }
}

class _Exercice extends StatelessWidget {
  const _Exercice({
    required this.exercice,
    required this.ouvert,
    required this.envoi,
    required this.envoyer,
    required this.voirLaCopie,
  });

  final MaDsfDeLExercice exercice;
  final bool ouvert;
  final String? envoi;
  final void Function(MaPieceDsf) envoyer;
  final VoidCallback voirLaCopie;

  @override
  Widget build(BuildContext context) {
    final e = exercice;
    final theme = Theme.of(context);
    final deposee = e.etat == EtatDeMaDsf.deposee;
    // 18 octobre 2026 : déposée, la DSF montrait encore ses pièces « à fournir », cercles
    // vides, comme si quelque chose manquait. Ne restent que celles qu'il a versées.
    final pieces = deposee
        ? e.attendues.where((p) => p.etat == EtatDeMaPiece.jointe).toList()
        : e.attendues;
    return Carte(
      padding: EdgeInsets.zero,
      ton: !deposee && e.aFournir > 0 ? TonDeCarte.accent : TonDeCarte.neutre,
      child: Theme(
        // Sans filet autour de la tuile dépliable : la carte en dessine déjà un.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: ouvert,
          tilePadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            'Exercice ${e.exercice}',
            style: theme.textTheme.titleMedium,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Pastille(
                  e.etat.libelle,
                  ton: deposee ? TonDePastille.reussite : TonDePastille.neutre,
                ),
                if (!deposee && e.aFournir > 0)
                  Pastille(
                    '${e.aFournir} à fournir',
                    ton: TonDePastille.attente,
                  ),
              ],
            ),
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Frise(etat: e.etat),
            const SizedBox(height: 12),
            Text(
              e.etat.explication,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            if (deposee) ...[
              const SizedBox(height: 12),
              if (e.numeroAccuse != null)
                Text(
                  'Accusé de la DGI n° ${e.numeroAccuse}',
                  style: theme.textTheme.titleSmall,
                ),
              if (e.deposeeLe != null)
                Text(
                  'Déposée le ${jourLong(e.deposeeLe!.toLocal())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (e.document) ...[
                const SizedBox(height: 12),
                BoutonDAction(
                  libelle: 'Voir la copie déposée',
                  icone: Icons.picture_as_pdf_outlined,
                  surAppui: voirLaCopie,
                  secondaire: true,
                ),
              ],
            ],
            if (pieces.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Vos pièces', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              if (!deposee && e.aFournir > 0)
                Text(
                  'Une pièce ne concerne pas votre entreprise ? Ne la cherchez pas : dites-le au cabinet, '
                  'qui la marque sans objet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 8),
              for (final p in pieces)
                _Piece(
                  piece: p,
                  enCours: envoi == '${e.exercice}/${p.numero}',
                  occupe: envoi != null,
                  envoyer: () => envoyer(p),
                ),
            ],
            if (e.parLeCabinet.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Établies par le cabinet ou sans objet : ${e.parLeCabinet.map((p) => p.libelle).join(' · ')}.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Les quatre étapes d'une DSF, l'étape atteinte soulignée.
class _Frise extends StatelessWidget {
  const _Frise({required this.etat});

  final EtatDeMaDsf etat;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    const etapes = ['Préparation', 'Relecture', 'Validée', 'Déposée'];
    return Row(
      children: [
        for (var i = 0; i < etapes.length; i++)
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i < etat.rang
                        ? couleurs.primary
                        : couleurs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  etapes[i],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: i < etat.rang
                        ? couleurs.primary
                        : couleurs.onSurfaceVariant,
                    fontWeight: i == etat.rang - 1
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Piece extends StatelessWidget {
  const _Piece({
    required this.piece,
    required this.enCours,
    required this.occupe,
    required this.envoyer,
  });

  final MaPieceDsf piece;
  final bool enCours;

  /// Une autre pièce part : un envoi à la fois, sur un réseau qu'on sait lent.
  final bool occupe;
  final VoidCallback envoyer;

  @override
  Widget build(BuildContext context) {
    final p = piece;
    final theme = Theme.of(context);
    final recue = p.etat == EtatDeMaPiece.jointe;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                recue ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: recue
                    ? Marque.reussiteDe(context)
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.libelle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (recue && p.nomDuFichier != null)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Text(
                'Reçue : ${p.nomDuFichier}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (p.versable)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 6),
              child: BoutonDAction(
                key: Key('verser-${p.numero}'),
                libelle: recue ? 'Remplacer' : 'Envoyer la pièce',
                libelleEnCours: 'Envoi…',
                icone: recue ? Icons.autorenew : Icons.photo_camera_outlined,
                enCours: enCours,
                surAppui: occupe && !enCours ? null : envoyer,
                secondaire: recue,
                tonal: !recue,
              ),
            ),
        ],
      ),
    );
  }
}
