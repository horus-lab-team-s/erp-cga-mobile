import 'package:flutter/material.dart';

import '../adaptateurs/numero_memorise.dart';
import '../composants/actions.dart';
import '../composants/carte.dart';
import '../composants/choix_du_dossier.dart';
import '../domaine/fraicheur.dart';
import '../domaine/honoraires.dart';
import '../domaine/ma_dsf.dart';
import '../domaine/rappels.dart';
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
    this.dossiers = const [],
    this.noms = const {},
    this.choisirLeDossier,
    this.rappels,
    this.version,
    this.demanderUnLien,
  });

  /// Tous les dossiers du compte, pour le choix de l'entreprise (20 octobre 2026).
  final List<String> dossiers;
  final Map<String, String> noms;
  final ValueChanged<String>? choisirLeDossier;

  /// Les rappels d'échéances posés sur le téléphone. `null` : pas de réglage.
  final Rappels? rappels;

  /// « 1.0.0 (1) », lue au démarrage. `null` : la ligne ne paraît pas.
  final String? version;

  /// Demande un lien pour choisir un nouveau mot de passe. Voir « Mon compte ».
  final Future<bool> Function(String courriel)? demanderUnLien;

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
  final _fraicheur = Fraicheur();

  /// Le réglage des rappels, tel qu'il est gardé ; `null` le temps de le lire.
  bool? _rappelsActifs;
  bool _reglageEnCours = false;

  /// Le numéro mobile money retenu, que la feuille de paiement préremplit.
  String? _numero;

  @override
  void initState() {
    super.initState();
    relire();
    _lireLeCompte();
  }

  @override
  void didUpdateWidget(EcranPlus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dossier != widget.dossier) {
      setState(() {
        _honoraires = null;
        _dsf = null;
      });
      relire();
    }
  }

  Future<void> _lireLeCompte() async {
    final actifs = await widget.rappels?.actifs();
    final numero = await NumeroMemorise.lire();
    if (!mounted) return;
    setState(() {
      _rappelsActifs = actifs;
      _numero = numero;
    });
  }

  /// Relu au retour sur l'onglet : une période réglée doit perdre sa pastille.
  ///
  /// ⚠️ 20 octobre 2026 : [siPerime] au simple passage d'onglet, pour ne relire
  /// que si la lecture a plus de cinq minutes (voir `Fraicheur`). Tirer vers le
  /// bas et le retour d'un écran de l'espace relisent toujours.
  Future<void> relire({bool siPerime = false}) async {
    final dossier = widget.dossier;
    if (dossier == null) return;
    if (siPerime && !_fraicheur.perimee) return;
    final (h, d) = await (
      widget.espace.mesHonoraires(dossier),
      widget.espace.maDsf(dossier),
    ).wait;
    if (!mounted) return;
    setState(() {
      _honoraires = h.valeur;
      _dsf = d.valeur;
    });
    if (h.valeur != null && h.copieDu == null) _fraicheur.marquer();
  }

  /// ⚠️ La permission d'Android 13 se demande ICI, au geste, et non à l'ouverture
  /// de l'application : voir `Rappels`.
  Future<void> _reglerLesRappels(bool actifs) async {
    final rappels = widget.rappels;
    if (rappels == null) return;
    setState(() => _reglageEnCours = true);
    final accordes = actifs ? await rappels.activer() : false;
    if (!actifs) await rappels.desactiver();
    if (!mounted) return;
    setState(() {
      _reglageEnCours = false;
      _rappelsActifs = actifs && accordes;
    });
    if (actifs && !accordes) {
      annoncer(
        context,
        'Le téléphone refuse les notifications de l\'application. Autorisez-les '
        'dans ses réglages, rubrique Notifications, puis réessayez.',
        echec: true,
      );
    } else if (actifs) {
      annoncer(
        context,
        'Rappels activés : trois jours avant et la veille de chaque échéance, '
        'à 9 h.',
      );
    }
  }

  Future<void> _changerLeNumero() async {
    final numero = await ouvrirUneFeuille<String>(
      context,
      construire: (_) => _FeuilleDuNumero(numero: _numero),
    );
    if (numero == null || !mounted) return;
    if (numero.isEmpty) {
      await NumeroMemorise.oublier();
    } else {
      await NumeroMemorise.retenir(numero);
    }
    if (!mounted) return;
    setState(() => _numero = numero.isEmpty ? null : numero);
  }

  Future<void> _motDePasse() => ouvrirUneFeuille<void>(
    context,
    construire: (_) =>
        _FeuilleDuMotDePasse(demanderUnLien: widget.demanderUnLien!),
  );

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
            // 20 octobre 2026 : l'entreprise en cours, et le choix d'une autre.
            if (widget.dossier != null) ...[
              Carte(
                relief: ReliefDeCarte.liste,
                child: Row(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: Marque.espace3),
                    Expanded(
                      child: EntrepriseEnCours(
                        dossier: widget.dossier!,
                        dossiers: widget.dossiers,
                        noms: widget.noms,
                        choisir: widget.choisirLeDossier,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
            ],
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
            const SizedBox(height: 22),
            const TitreDeSection('Mon compte'),
            const SizedBox(height: 8),
            _MonCompte(
              numero: _numero,
              changerLeNumero: _changerLeNumero,
              rappelsActifs: widget.rappels == null ? null : _rappelsActifs,
              reglageEnCours: _reglageEnCours,
              reglerLesRappels: _reglerLesRappels,
              motDePasse: widget.demanderUnLien == null ? null : _motDePasse,
              version: widget.version,
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

/// « Mon compte » : ce que l'adhérent règle pour lui-même (20 octobre 2026).
///
/// ⚠️ LE MOT DE PASSE NE SE CHANGE PAS ICI, FAUTE DE ROUTE. Le serveur n'offre pas
/// de changement de mot de passe à une session ouverte ; il offre le lien de
/// réinitialisation, le même que « Mot de passe oublié ». C'est donc celui-là que
/// l'écran propose, en le disant : un formulaire « ancien / nouveau » qui
/// n'aboutirait nulle part serait pire que pas de formulaire.
class _MonCompte extends StatelessWidget {
  const _MonCompte({
    required this.numero,
    required this.changerLeNumero,
    required this.rappelsActifs,
    required this.reglageEnCours,
    required this.reglerLesRappels,
    required this.motDePasse,
    required this.version,
  });

  final String? numero;
  final VoidCallback changerLeNumero;

  /// `null` : pas de rappels sur cet appareil, la ligne ne paraît pas.
  final bool? rappelsActifs;
  final bool reglageEnCours;
  final ValueChanged<bool> reglerLesRappels;
  final VoidCallback? motDePasse;
  final String? version;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget icone(IconData i) => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(i, color: theme.colorScheme.onPrimaryContainer, size: 22),
    );
    const marge = EdgeInsets.fromLTRB(16, 6, 12, 6);
    final lignes = <Widget>[
      ListTile(
        key: const Key('compte-numero'),
        contentPadding: marge,
        leading: icone(Icons.phone_iphone),
        title: Text('Numéro mobile money', style: theme.textTheme.titleSmall),
        subtitle: Text(
          numero == null
              ? 'Aucun : vous le saisirez au premier paiement'
              : '$numero · proposé à chaque paiement',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: changerLeNumero,
      ),
      if (rappelsActifs != null)
        SwitchListTile(
          key: const Key('reglage-rappels'),
          contentPadding: marge,
          secondary: icone(Icons.notifications_active_outlined),
          title: Text(
            'Me rappeler mes échéances',
            style: theme.textTheme.titleSmall,
          ),
          subtitle: const Text(
            'Une notification trois jours avant et la veille, à 9 h. Rien ne '
            'part au cabinet.',
          ),
          value: rappelsActifs!,
          onChanged: reglageEnCours ? null : reglerLesRappels,
        ),
      if (motDePasse != null)
        ListTile(
          key: const Key('compte-mot-de-passe'),
          contentPadding: marge,
          leading: icone(Icons.lock_reset_outlined),
          title: Text(
            'Changer de mot de passe',
            style: theme.textTheme.titleSmall,
          ),
          subtitle: const Text('Par un lien reçu dans votre boîte de courriel'),
          trailing: const Icon(Icons.chevron_right),
          onTap: motDePasse,
        ),
      if (version != null)
        ListTile(
          key: const Key('compte-version'),
          contentPadding: marge,
          leading: icone(Icons.info_outline),
          title: Text(
            'Version de l\'application',
            style: theme.textTheme.titleSmall,
          ),
          subtitle: Text(version!),
        ),
    ];
    return Carte(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, l) in lignes.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 68),
            l,
          ],
        ],
      ),
    );
  }
}

/// Le numéro proposé à chaque paiement, à changer ou à oublier.
///
/// Rend le nouveau numéro, une chaîne vide pour l'oublier, `null` pour rien.
class _FeuilleDuNumero extends StatefulWidget {
  const _FeuilleDuNumero({required this.numero});

  final String? numero;

  @override
  State<_FeuilleDuNumero> createState() => _EtatDeLaFeuilleDuNumero();
}

class _EtatDeLaFeuilleDuNumero extends State<_FeuilleDuNumero> {
  late final _champ = TextEditingController(text: widget.numero ?? '');
  String? _erreur;

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  void _enregistrer() {
    final numero = _champ.text.replaceAll(RegExp(r'\s'), '');
    if (numero.length < 9) {
      setState(() => _erreur = 'Neuf chiffres au moins.');
      return;
    }
    Navigator.of(context).pop(numero);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Numéro mobile money', style: theme.textTheme.titleLarge),
        const SizedBox(height: Marque.espace1),
        Text(
          'Il est proposé à chaque paiement ; vous pouvez toujours en saisir un '
          'autre. Il ne débite rien sans votre code secret.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Marque.espace4),
        TextField(
          key: const Key('champ-numero'),
          controller: _champ,
          keyboardType: TextInputType.phone,
          autofocus: true,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: InputDecoration(
            labelText: 'Numéro',
            hintText: '6 77 12 34 56',
            prefixIcon: const Icon(Icons.phone_outlined),
            errorText: _erreur,
          ),
          onSubmitted: (_) => _enregistrer(),
        ),
        const SizedBox(height: Marque.espace4),
        BoutonDAction(
          key: const Key('enregistrer-numero'),
          libelle: 'Enregistrer',
          icone: Icons.check,
          surAppui: _enregistrer,
        ),
        if (widget.numero != null)
          TextButton(
            key: const Key('oublier-numero'),
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Oublier ce numéro'),
          ),
      ],
    );
  }
}

/// Le lien pour choisir un nouveau mot de passe, envoyé par courriel.
class _FeuilleDuMotDePasse extends StatefulWidget {
  const _FeuilleDuMotDePasse({required this.demanderUnLien});

  final Future<bool> Function(String courriel) demanderUnLien;

  @override
  State<_FeuilleDuMotDePasse> createState() => _EtatDuMotDePasse();
}

class _EtatDuMotDePasse extends State<_FeuilleDuMotDePasse> {
  final _courriel = TextEditingController();
  bool _enCours = false;

  /// Vrai : la demande est prise. Faux : elle n'est pas arrivée. `null` : rien.
  bool? _sort;

  @override
  void dispose() {
    _courriel.dispose();
    super.dispose();
  }

  Future<void> _demander() async {
    final courriel = _courriel.text.trim();
    if (!courriel.contains('@')) {
      setState(() => _sort = false);
      return;
    }
    setState(() {
      _enCours = true;
      _sort = null;
    });
    final pris = await widget.demanderUnLien(courriel);
    if (!mounted) return;
    setState(() {
      _enCours = false;
      _sort = pris;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final douce = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.4,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Changer de mot de passe', style: theme.textTheme.titleLarge),
        const SizedBox(height: Marque.espace1),
        Text(
          'Le cabinet vous envoie un lien, valable une fois : il ouvre la page où '
          'vous choisissez le nouveau. Votre session ici reste ouverte.',
          style: douce,
        ),
        const SizedBox(height: Marque.espace4),
        if (_sort == true)
          // ⚠️ Comme à la connexion : « la demande est prise », jamais « un lien est
          // parti ». Le serveur répond de même pour une adresse inconnue, et c'est
          // voulu (voir `ServicePublic.demanderUnLienDeReinitialisation`).
          Text(
            'Demande prise. Si cette adresse est celle de votre compte, le lien '
            'arrive dans quelques minutes ; pensez aux courriels indésirables.',
            key: const Key('lien-demande'),
            style: theme.textTheme.bodyMedium,
          )
        else ...[
          AutofillGroup(
            child: TextField(
              key: const Key('champ-courriel-lien'),
              controller: _courriel,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              enabled: !_enCours,
              decoration: InputDecoration(
                labelText: 'Votre adresse de courriel',
                prefixIcon: const Icon(Icons.alternate_email),
                errorText: _sort == false
                    ? 'La demande n\'est pas partie : vérifiez l\'adresse et '
                          'le réseau.'
                    : null,
                errorMaxLines: 2,
              ),
              onSubmitted: (_) => _demander(),
            ),
          ),
          const SizedBox(height: Marque.espace4),
          BoutonDAction(
            key: const Key('demander-le-lien'),
            libelle: 'Recevoir le lien',
            libelleEnCours: 'Envoi…',
            icone: Icons.mail_outline,
            enCours: _enCours,
            surAppui: _demander,
          ),
        ],
      ],
    );
  }
}
