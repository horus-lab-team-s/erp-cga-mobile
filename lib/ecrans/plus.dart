import 'package:flutter/material.dart';

import '../composants/actions.dart';
import '../composants/carte.dart';
import '../domaine/honoraires.dart';
import '../domaine/ma_dsf.dart';
import '../marque.dart';
import '../ports/service_de_l_espace.dart';

/// « Plus » : tout l'espace adhérent qui n'a pas sa place dans la barre (18 octobre 2026).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE LE CABINET A DEMANDÉ : « fournis tous les onglets ». L'espace web en
/// compte sept, plus la DSF ; une barre de téléphone n'en tient que cinq avant
/// que les libellés deviennent illisibles. La barre garde ce qu'on ouvre chaque
/// jour (accueil, échéances, dépôt, documents) ; tout le reste est ici, à un
/// toucher, avec ce qui demande un geste signalé d'une pastille.
///
/// ⚠️ LES PASTILLES SE LISENT AU SERVEUR, sans bloquer la page : sans réseau, la
/// liste s'affiche quand même, simplement sans pastille.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranPlus extends StatefulWidget {
  const EcranPlus({
    super.key,
    required this.espace,
    required this.dossier,
    required this.ouvrirHonoraires,
    required this.ouvrirMaDsf,
    required this.ouvrirMaPaie,
    required this.ouvrirMonEntreprise,
    required this.ouvrirMesPieces,
    required this.seDeconnecter,
  });

  final ServiceDeLEspace espace;
  final String? dossier;
  final VoidCallback ouvrirHonoraires;
  final VoidCallback ouvrirMaDsf;
  final VoidCallback ouvrirMaPaie;
  final VoidCallback ouvrirMonEntreprise;
  final VoidCallback? ouvrirMesPieces;
  final Future<void> Function() seDeconnecter;

  @override
  State<EcranPlus> createState() => EtatDuPlus();
}

class EtatDuPlus extends State<EcranPlus> {
  MesHonoraires? _honoraires;
  MaDsf? _dsf;

  @override
  void initState() {
    super.initState();
    relire();
  }

  /// Relu à chaque retour sur l'onglet : une période réglée doit perdre sa pastille.
  Future<void> relire() async {
    final dossier = widget.dossier;
    if (dossier == null) return;
    final (h, d) = await (
      widget.espace.mesHonoraires(dossier),
      widget.espace.maDsf(dossier),
    ).wait;
    if (!mounted) return;
    setState(() {
      _honoraires = h.valeur;
      _dsf = d.valeur;
    });
  }

  Future<void> _confirmerLaDeconnexion() async {
    if (await confirmerLaDeconnexion(context)) await widget.seDeconnecter();
  }

  @override
  Widget build(BuildContext context) {
    final du = _honoraires?.du ?? 0;
    // ⚠️ L'EXERCICE LE PLUS RÉCENT NON DÉPOSÉ, et non la somme : additionner trois
    // exercices affichait « 23 à fournir » là où le cabinet en attend 7.
    final aFournir =
        _dsf?.exercices
            .where((e) => e.etat != EtatDeMaDsf.deposee)
            .firstOrNull
            ?.aFournir ??
        0;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon espace')),
      body: RefreshIndicator(
        onRefresh: relire,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            Marque.espace4,
            Marque.espace3,
            Marque.espace4,
            Marque.espaceSousLaBarreDe(context),
          ),
          children: [
            const TitreDeSection('Avec le cabinet'),
            const SizedBox(height: 8),
            _Groupe(
              entrees: [
                _Entree(
                  cle: 'plus-honoraires',
                  icone: Icons.account_balance_wallet_outlined,
                  titre: 'Mes honoraires',
                  detail: 'Régler par mobile money, reçus, notes et factures',
                  pastille: du > 0 ? '${montantFcfa(du)} à régler' : null,
                  surAppui: widget.ouvrirHonoraires,
                ),
                _Entree(
                  cle: 'plus-dsf',
                  icone: Icons.assignment_outlined,
                  titre: 'Ma déclaration annuelle (DSF)',
                  detail: 'Où elle en est, les pièces à fournir',
                  pastille: aFournir > 0 ? '$aFournir à fournir' : null,
                  surAppui: widget.ouvrirMaDsf,
                ),
                if (widget.ouvrirMesPieces != null)
                  _Entree(
                    cle: 'plus-pieces',
                    icone: Icons.history,
                    titre: 'Mes pièces envoyées',
                    detail: 'Ce que vous avez remis, et son avancement',
                    surAppui: widget.ouvrirMesPieces!,
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const TitreDeSection('Mon entreprise'),
            const SizedBox(height: 8),
            _Groupe(
              entrees: [
                _Entree(
                  cle: 'plus-entreprise',
                  icone: Icons.storefront_outlined,
                  titre: 'Mon entreprise',
                  detail: 'Votre régime, votre dossier, signaler un changement',
                  surAppui: widget.ouvrirMonEntreprise,
                ),
                _Entree(
                  cle: 'plus-paie',
                  icone: Icons.badge_outlined,
                  titre: 'Ma paie',
                  detail:
                      'Vos salariés, les bulletins et ce qu\'il faut verser',
                  surAppui: widget.ouvrirMaPaie,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Center(
              child: TextButton.icon(
                key: const Key('plus-deconnexion'),
                onPressed: _confirmerLaDeconnexion,
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Entree {
  const _Entree({
    required this.cle,
    required this.icone,
    required this.titre,
    required this.detail,
    required this.surAppui,
    this.pastille,
  });

  final String cle;
  final IconData icone;
  final String titre;
  final String detail;
  final VoidCallback surAppui;
  final String? pastille;
}

class _Groupe extends StatelessWidget {
  const _Groupe({required this.entrees});

  final List<_Entree> entrees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Carte(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, e) in entrees.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 68),
            ListTile(
              key: Key(e.cle),
              contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  e.icone,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
              title: Text(e.titre, style: theme.textTheme.titleSmall),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: e.pastille == null
                    ? Text(e.detail)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.detail),
                          const SizedBox(height: 6),
                          Pastille(e.pastille!, ton: TonDePastille.attente),
                        ],
                      ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: e.surAppui,
            ),
          ],
        ],
      ),
    );
  }
}
