import 'package:flutter/material.dart';

import '../composants/actions.dart';
import '../composants/carte.dart';
import '../domaine/ma_paie.dart';
import '../marque.dart';
import '../ports/service_de_l_espace.dart';

/// Ma paie : le mois clos, ce qu'il faut verser, et les bulletins (18 octobre 2026).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ LE MOIS CLOS PAR DÉFAUT : celui du mois en cours est incomplet par
/// construction. Les flèches changent de mois ; l'avenir ne s'ouvre pas.
///
/// ⚠️ L'ÉCRAN NE CALCULE RIEN : brut, net, coût employeur et total à verser
/// arrivent du serveur. Une règle recopiée ici paierait un jour deux fois le
/// logement, parce que les avantages en nature sortent du net.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranMaPaie extends StatefulWidget {
  const EcranMaPaie({
    super.key,
    required this.espace,
    required this.dossiers,
    required this.quandSessionExpire,
    this.aujourdHui,
  });

  final ServiceDeLEspace espace;
  final List<String> dossiers;
  final VoidCallback quandSessionExpire;

  /// Pour les essais : le jour qui fixe le mois clos.
  final DateTime? aujourdHui;

  @override
  State<EcranMaPaie> createState() => _EtatDeMaPaie();
}

class _EtatDeMaPaie extends State<EcranMaPaie> {
  late final String _dossier = widget.dossiers.first;
  late final (int, int) _dernier = MaPaie.moisParDefaut(
    widget.aujourdHui ?? DateTime.now(),
  );
  late (int, int) _mois = _dernier;
  Lecture<MaPaie>? _lecture;

  @override
  void initState() {
    super.initState();
    _relire();
  }

  Future<void> _relire() async {
    setState(() => _lecture = null);
    final lue = await widget.espace.maPaie(
      _dossier,
      annee: _mois.$1,
      mois: _mois.$2,
    );
    if (!mounted) return;
    if (lue.sessionAExpire) {
      widget.quandSessionExpire();
      return;
    }
    setState(() => _lecture = lue);
  }

  void _decaler(int pas) {
    final (a, m) = _mois;
    final total = a * 12 + (m - 1) + pas;
    final suivant = (total ~/ 12, total % 12 + 1);
    if (suivant.$1 * 12 + suivant.$2 > _dernier.$1 * 12 + _dernier.$2) return;
    setState(() => _mois = suivant);
    _relire();
  }

  @override
  Widget build(BuildContext context) {
    final lecture = _lecture;
    final paie = lecture?.valeur;
    final auDernier = _mois == _dernier;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ma paie')),
      body: RefreshIndicator(
        onRefresh: _relire,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            Marque.espace4,
            Marque.espace3,
            Marque.espace4,
            Marque.espaceSousLaBarreDe(context),
          ),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mois précédent',
                  onPressed: () => _decaler(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${nomDuMois(_mois.$2)[0].toUpperCase()}${nomDuMois(_mois.$2).substring(1)} ${_mois.$1}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Mois suivant',
                  onPressed: auDernier ? null : () => _decaler(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            switch ((lecture, paie)) {
              (null, _) => const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
              (_, null) => SizedBox(
                height: 360,
                child: EtatVide(
                  titre: 'Paie indisponible',
                  detail:
                      'Votre paie se lit sur le serveur. Elle reparaîtra dès que la connexion revient.',
                  icone: Icons.wifi_off_outlined,
                  action: OutlinedButton(
                    onPressed: _relire,
                    child: const Text('Réessayer'),
                  ),
                ),
              ),
              (_, final MaPaie p) => _Mois(paie: p),
            },
          ],
        ),
      ),
    );
  }
}

class _Mois extends StatelessWidget {
  const _Mois({required this.paie});

  final MaPaie paie;

  @override
  Widget build(BuildContext context) {
    final p = paie;
    final theme = Theme.of(context);
    if (p.effectif == 0 && p.bulletins.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Chapeau(
          titre: 'Aucun salarié payé ce mois-ci',
          detail:
              'Aucun contrat ne couvrait ce mois. Si vous avez embauché, signalez-le au cabinet.',
          icone: Icons.people_outline,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Chapeau(
          titre: '${montantFcfa(p.totalAVerser)} à verser',
          detail: p.aDeposerAvant == null
              ? 'Retenues sur salaires et charges patronales du mois.'
              : p.enRetard
              ? 'La déclaration devait partir avant le ${jourLong(p.aDeposerAvant!)}.'
              : 'Retenues et charges du mois, à déclarer avant le ${jourLong(p.aDeposerAvant!)}.',
          icone: p.enRetard
              ? Icons.warning_amber_outlined
              : Icons.payments_outlined,
          grave: p.enRetard,
        ),
        const SizedBox(height: 14),
        // Les trois chiffres de même hauteur, quel que soit le libellé qui passe à la ligne.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Chiffre(
                  valeur: '${p.effectif}',
                  libelle: 'salarié${p.effectif > 1 ? 's' : ''}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Chiffre(
                  valeur: montantFcfa(p.masseBrute),
                  libelle: 'masse brute',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Chiffre(
                  valeur: montantFcfa(p.cotisationsCnps),
                  libelle: 'dont CNPS',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const TitreDeSection('Bulletins'),
        const SizedBox(height: 8),
        Carte(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, b) in p.bulletins.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      p.nomDe(b.matricule).isEmpty
                          ? '?'
                          : p.nomDe(b.matricule)[0],
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(p.nomDe(b.matricule)),
                  subtitle: Text(
                    'Brut ${montantFcfa(b.brut)}${b.alertes.isEmpty ? '' : ' · ${b.alertes.first}'}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        montantFcfa(b.net),
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        'net',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Les montants sont calculés par le cabinet, selon le référentiel en vigueur ce mois-là.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.valeur, required this.libelle});

  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Carte(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            libelle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
