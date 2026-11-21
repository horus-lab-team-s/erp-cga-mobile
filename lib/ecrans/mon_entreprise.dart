import 'package:flutter/material.dart';

import '../composants/actions.dart';
import '../composants/carte.dart';
import '../composants/etat.dart';
import '../composants/joindre.dart';
import '../marque.dart';
import '../domaine/fraicheur.dart';
import '../domaine/mon_entreprise.dart';
import '../ports/service_de_session.dart';

/// La fiche du dossier, et le seul geste qu'elle offre.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ SIGNALER N'EST PAS MODIFIER, ET L'ÉCRAN DOIT LE DIRE
///
/// Le serveur est formel : un signalement est « une parole datée au journal,
/// annoncée au chargé de clientèle ». **Rien ne change au dossier** ; le cabinet
/// instruit.
///
/// Laisser croire l'inverse serait grave. Un adhérent qui déménage, signale sa
/// nouvelle adresse et croit son dossier à jour continuerait de recevoir ses
/// avis à l'ancienne, et manquerait ses échéances. L'écran annonce donc ce que
/// le geste fait vraiment : il prévient quelqu'un, et il nomme cette personne.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranMonEntreprise extends StatefulWidget {
  const EcranMonEntreprise({
    super.key,
    required this.session,
    required this.dossier,
    required this.quandSessionExpire,
  });

  final ServiceDeSession session;

  /// Le dossier choisi dans l'en-tête de l'accueil (20 octobre 2026).
  final String dossier;
  final VoidCallback quandSessionExpire;

  @override
  State<EcranMonEntreprise> createState() => _EtatDeLaFiche();
}

class _EtatDeLaFiche extends State<EcranMonEntreprise>
    with WidgetsBindingObserver {
  Fiche? _fiche;
  bool _lectureEnCours = true;
  String get _dossier => widget.dossier;
  final _fraicheur = Fraicheur();

  /// Ce que l'adhérent a commencé d'écrire, par nature de changement.
  ///
  /// ⚠️ 20 octobre 2026 : un « Annuler » touché par erreur, ou une panne de
  /// réseau, jetait un message tapé lettre à lettre sur un clavier de téléphone.
  /// Il reste là, et revient quand on rouvre la même nature.
  final _brouillons = <String, String>{};

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
    if (etat == AppLifecycleState.resumed && _fraicheur.perimee) _relire();
  }

  Future<void> _relire() async {
    setState(() => _lectureEnCours = true);
    final lu = await widget.session.monEntreprise(_dossier);
    if (!mounted) return;
    setState(() {
      _fiche = lu;
      _lectureEnCours = false;
    });
    if (lu.sessionAExpire) widget.quandSessionExpire();
    if (lu.serveurJoignable) _fraicheur.marquer();
  }

  Future<void> _signaler(MonEntreprise e) async {
    final nature = await showModalBottomSheet<NatureDeChangement>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ChoixDeNature(natures: e.natures),
    );
    if (nature == null || !mounted) return;

    // ⚠️ 20 octobre 2026 : L'ENVOI SE FAIT DANS LA BOÎTE, qui reste ouverte tant
    // qu'il n'a pas abouti. La boîte se fermait avant l'envoi : rien ne disait
    // qu'il était en cours, et une panne de réseau perdait le message.
    final sort = await showDialog<SortDuSignalement>(
      context: context,
      builder: (_) => _SaisieDuMessage(
        nature: nature,
        brouillon: _brouillons[nature.code] ?? '',
        retenir: (texte) => _brouillons[nature.code] = texte,
        envoyer: (message) => widget.session.signalerUnChangement(
          dossier: _dossier,
          nature: nature.code,
          message: message,
        ),
      ),
    );
    if (sort == null || !mounted) return;
    if (sort == SortDuSignalement.transmis ||
        sort == SortDuSignalement.dejaSignale) {
      _brouillons.remove(nature.code);
    }

    final interlocuteur = e.interlocuteur?.nom;
    // ⚠️ Chaque sort a sa phrase, et deux d'entre elles demandent du soin :
    // « déjà signalé » n'est PAS un échec, et « transmis » ne doit jamais
    // laisser croire que le dossier a changé.
    final (String texte, bool grave) = switch (sort) {
      SortDuSignalement.transmis => (
        interlocuteur == null
            ? 'Signalement transmis au cabinet. Votre dossier ne change pas '
                  'tant que le cabinet ne l\'a pas instruit.'
            : 'Signalement transmis à $interlocuteur. Votre dossier ne change '
                  'pas tant que le cabinet ne l\'a pas instruit.',
        false,
      ),
      SortDuSignalement.dejaSignale => (
        'Vous avez déjà signalé ce changement aujourd\'hui. Le cabinet est '
            'prévenu : inutile de recommencer.',
        false,
      ),
      SortDuSignalement.refuse => (
        'Le cabinet n\'a pas pu enregistrer ce signalement.',
        true,
      ),
      SortDuSignalement.sessionExpiree => (
        'Session expirée. Reconnectez-vous.',
        true,
      ),
      SortDuSignalement.indisponible => (
        'Pas de réseau : le signalement n\'est pas parti. Réessayez.',
        true,
      ),
    };
    final couleurs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texte),
        backgroundColor: grave ? couleurs.error : null,
        duration: Duration(seconds: grave ? 7 : 6),
      ),
    );
    if (sort == SortDuSignalement.sessionExpiree) widget.quandSessionExpire();
    if (sort == SortDuSignalement.transmis) await _relire();
  }

  @override
  Widget build(BuildContext context) {
    final f = _fiche;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon entreprise')),
      body: RefreshIndicator(
        onRefresh: _relire,
        child: switch ((_lectureEnCours, f)) {
          (true, null) => const Squelette(
            key: Key('fiche-en-attente'),
            cartes: 2,
            hauteurDeCarte: 140,
          ),
          (_, null) => EtatDePanne(serveurEnPanne: true, reessayer: _relire),
          (_, final Fiche x) when x.sessionAExpire => const EtatVide(
            titre: 'Session expirée',
            detail: 'Reconnectez-vous pour consulter votre fiche.',
            icone: Icons.lock_outline,
          ),
          (_, final Fiche x) when !x.serveurJoignable => EtatDePanne(
            serveurEnPanne: x.serveurEnPanne,
            horsLigne:
                'Votre fiche se lit sur le serveur. Elle reparaîtra dès que la '
                'connexion revient.',
            reessayer: _relire,
          ),
          (_, final Fiche x) when x.entreprise == null => const EtatVide(
            titre: 'Aucune fiche',
            detail: 'Appelez votre chargé de clientèle.',
            icone: Icons.help_outline,
          ),
          (_, final Fiche x) => _Contenu(
            entreprise: x.entreprise!,
            signaler: () => _signaler(x.entreprise!),
          ),
        },
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({required this.entreprise, required this.signaler});

  final MonEntreprise entreprise;
  final VoidCallback signaler;

  @override
  Widget build(BuildContext context) {
    final e = entreprise;
    final couleurs = Theme.of(context).colorScheme;
    return ListView(
      // ⚠️ La barre du bas flotte : le dernier bloc finirait dessous.
      padding: EdgeInsets.fromLTRB(
        Marque.espace4,
        Marque.espace4,
        Marque.espace4,
        // ⚠️ `…De(context)` et non la constante : la barre flotte AU-DESSUS de
        // l'encart système, que la constante seule ne couvre pas.
        Marque.espaceSousLaBarreDe(context),
      ),
      children: [
        // ── L'identité ────────────────────────────────────────────────────
        Chapeau(
          titre: e.denomination,
          detail: e.forme,
          // ⚠️ Le NIU est ce que l'adhérent doit citer partout : au cabinet,
          // aux impôts, sur ses factures. Il se sélectionne pour être recopié,
          // ce qui évite de le lire à voix haute au téléphone.
          dessous: SelectableText(
            e.niu,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: couleurs.onSecondaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),

        // ── Le régime, qui EST la formule ─────────────────────────────────
        const SizedBox(height: 22),
        const _Titre('Votre régime'),
        const SizedBox(height: 10),
        _Bloc(
          children: [
            _Ligne(intitule: 'Régime', valeur: e.regimeTitre, fort: true),
            if (e.regimeDepuis != null)
              _Ligne(intitule: 'Depuis', valeur: _enFrancais(e.regimeDepuis!)),
            _Ligne(
              intitule: 'TVA',
              valeur: e.assujettieTva
                  ? 'Vous la facturez et la reversez'
                  : 'Vous n\'y êtes pas assujetti',
            ),
            if (e.regimeExplication != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  e.regimeExplication!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: couleurs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),

        // ── Le dossier ────────────────────────────────────────────────────
        const SizedBox(height: 22),
        const _Titre('Votre dossier'),
        const SizedBox(height: 10),
        _Bloc(
          children: [
            if (e.activite != null)
              _Ligne(intitule: 'Activité', valeur: e.activite!),
            if (e.rccm != null) _Ligne(intitule: 'RCCM', valeur: e.rccm!),
            if (e.siege != null) _Ligne(intitule: 'Siège', valeur: e.siege!),
            if (e.centre != null)
              _Ligne(intitule: 'Centre des impôts', valeur: e.centre!),
            if (e.adhesionNumero != null)
              _Ligne(intitule: 'Adhésion', valeur: e.adhesionNumero!),
            if (e.adherenteDepuis != null)
              _Ligne(
                intitule: 'Adhérent depuis',
                valeur: _enFrancais(e.adherenteDepuis!),
              ),
            for (final d in e.dirigeants)
              _Ligne(intitule: d.qualite, valeur: d.nom),
          ],
        ),

        // ── À qui parler ──────────────────────────────────────────────────
        if (e.interlocuteur != null) ...[
          const SizedBox(height: 22),
          const _Titre('Votre interlocuteur'),
          const SizedBox(height: 10),
          _Bloc(
            children: [
              _Ligne(
                intitule: e.interlocuteur!.roleLisible,
                valeur: e.interlocuteur!.nom,
                fort: true,
              ),
              if (e.interlocuteur!.telephone != null)
                _Ligne(
                  intitule: 'Téléphone',
                  valeur: e.interlocuteur!.telephone!,
                ),
              if (e.interlocuteur!.courriel != null)
                _Ligne(
                  intitule: 'Courriel',
                  valeur: e.interlocuteur!.courriel!,
                ),
            ],
          ),
          // 19 octobre 2026 : le numéro et l'adresse n'étaient que du texte. L'occasion
          // d'appeler, ou d'écrire sur WhatsApp, était là, sans geste pour la saisir.
          const SizedBox(height: 10),
          _JoindreLInterlocuteur(
            telephone: e.interlocuteur!.telephone,
            courriel: e.interlocuteur!.courriel,
            denomination: e.denomination,
          ),
        ],

        // ── Le seul geste ─────────────────────────────────────────────────
        const SizedBox(height: 26),
        FilledButton.tonalIcon(
          key: const Key('signaler-un-changement'),
          onPressed: signaler,
          icon: const Icon(Icons.edit_note_outlined, size: 19),
          label: const Text('Signaler un changement'),
        ),
        const SizedBox(height: 8),
        // ⚠️ La phrase qui évite le pire malentendu de cet écran.
        Text(
          'Le cabinet en est prévenu et vous rappelle. Votre dossier ne change '
          'pas tant qu\'il ne l\'a pas instruit.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: couleurs.onSurfaceVariant,
            height: 1.5,
          ),
        ),

        if (e.signalements.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _Titre('Ce que vous avez déjà signalé'),
          const SizedBox(height: 10),
          for (final s in e.signalements)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Bloc(
                children: [
                  _Ligne(intitule: s.libelle, valeur: s.le),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      s.message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: couleurs.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
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

/// « 2023-01-01 » devient « 1er janvier 2023 ».
///
/// ⚠️ CONSTATÉ SUR LE TECNO : la fiche affichait « Depuis 2023-01-01 », une date
/// de base de données montrée telle quelle à un commerçant. Deux écrans plus
/// loin, les accusés de dépôt disaient « déposé le 15 mars 2024 » : le même
/// produit parlait deux langues selon l'écran.
///
/// ⚠️ La chaîne est rendue TELLE QUELLE si elle ne se lit pas. Un serveur qui
/// changerait de format ne doit pas faire disparaître la date : mieux vaut une
/// date mal mise en forme qu'un champ vide.
String _enFrancais(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final jour = d.day == 1 ? '1er' : '${d.day}';
  return '$jour ${_moisEnFrancais[d.month - 1]} ${d.year}';
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Text(
    texte,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

class _Bloc extends StatelessWidget {
  const _Bloc({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Carte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.intitule,
    required this.valeur,
    this.fort = false,
  });

  final String intitule;
  final String valeur;
  final bool fort;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️ L'intitulé borné à 40 % : au-delà, « Centre des impôts » pousse
          // sa valeur sur trois lignes à largeur de téléphone.
          SizedBox(
            width: 128,
            child: Text(
              intitule,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: couleurs.onSurfaceVariant),
            ),
          ),
          // 19 octobre 2026 : sans espace, un intitulé qui remplit sa colonne
          // (« Chargé de clientèle ») venait toucher la valeur sur le TECNO.
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              valeur,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: couleurs.onSurface,
                fontWeight: fort ? FontWeight.w600 : null,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le choix de la nature, avec l'aide que le serveur fournit pour chacune.
class _ChoixDeNature extends StatelessWidget {
  const _ChoixDeNature({required this.natures});
  final List<NatureDeChangement> natures;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            'Que voulez-vous signaler ?',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          for (final n in natures)
            ListTile(
              key: Key('nature-${n.code}'),
              contentPadding: EdgeInsets.zero,
              title: Text(n.libelle),
              // ⚠️ L'aide vient du serveur et dit ce que le changement
              // ENTRAÎNE : « une nouvelle adresse peut changer votre centre des
              // impôts, donc vos dates ». L'application n'explique pas le droit.
              subtitle: Text(
                n.aide,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: couleurs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              onTap: () => Navigator.of(context).pop(n),
            ),
        ],
      ),
    );
  }
}

/// La saisie du message, et son envoi. ⚠️ Cinq caractères au moins : c'est la
/// borne du serveur, appliquée ici pour qu'un envoi ne parte pas se faire refuser.
///
/// ⚠️ 20 octobre 2026 : la boîte reste ouverte pendant l'envoi, roue dans le bouton,
/// et ne se ferme qu'une fois le cabinet prévenu. Une panne laisse le texte en
/// place, avec un mot pour réessayer.
class _SaisieDuMessage extends StatefulWidget {
  const _SaisieDuMessage({
    required this.nature,
    required this.envoyer,
    this.brouillon = '',
    this.retenir,
  });

  final NatureDeChangement nature;
  final Future<SortDuSignalement> Function(String message) envoyer;

  /// Ce que l'adhérent avait déjà écrit pour cette nature.
  final String brouillon;

  /// Garde le texte à chaque frappe, pour qu'il survive à la boîte.
  final ValueChanged<String>? retenir;

  @override
  State<_SaisieDuMessage> createState() => _EtatDeLaSaisie();
}

class _EtatDeLaSaisie extends State<_SaisieDuMessage> {
  late final _controleur = TextEditingController(text: widget.brouillon);
  bool _enCours = false;
  String? _echec;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    setState(() {
      _enCours = true;
      _echec = null;
    });
    final sort = await widget.envoyer(_controleur.text.trim());
    if (!mounted) return;
    switch (sort) {
      case SortDuSignalement.indisponible:
        setState(() {
          _enCours = false;
          _echec =
              'Pas de réseau : le signalement n\'est pas parti. Votre texte est '
              'gardé ; réessayez.';
        });
      case SortDuSignalement.refuse:
        setState(() {
          _enCours = false;
          _echec = 'Le cabinet n\'a pas pu enregistrer ce signalement.';
        });
      case SortDuSignalement.transmis ||
          SortDuSignalement.dejaSignale ||
          SortDuSignalement.sessionExpiree:
        Navigator.of(context).pop(sort);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assezLong = _controleur.text.trim().length >= 5;
    return PopScope(
      canPop: !_enCours,
      child: AlertDialog(
        title: Text(widget.nature.libelle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('message-du-signalement'),
              controller: _controleur,
              autofocus: true,
              enabled: !_enCours,
              maxLines: 4,
              maxLength: 1000,
              onChanged: (texte) {
                widget.retenir?.call(texte);
                setState(() {});
              },
              decoration: const InputDecoration(
                hintText: 'Décrivez le changement',
                border: OutlineInputBorder(),
              ),
            ),
            if (_echec != null)
              Text(
                _echec!,
                key: const Key('echec-du-signalement'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _enCours ? null : () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          BoutonDAction(
            key: const Key('envoyer-le-signalement'),
            libelle: _echec == null ? 'Envoyer' : 'Réessayer',
            libelleEnCours: 'Envoi…',
            icone: Icons.send_rounded,
            enCours: _enCours,
            surAppui: assezLong ? _envoyer : null,
          ),
        ],
      ),
    );
  }
}

/// Appeler, écrire sur WhatsApp ou par courriel, en un appui (19 octobre 2026).
class _JoindreLInterlocuteur extends StatelessWidget {
  const _JoindreLInterlocuteur({
    required this.telephone,
    required this.courriel,
    required this.denomination,
  });

  final String? telephone;
  final String? courriel;
  final String denomination;

  /// Les chiffres seuls, indicatif du Cameroun compris : sans lui, WhatsApp ouvre
  /// une conversation avec un numéro étranger.
  String? get _international {
    final chiffres = (telephone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (chiffres.isEmpty) return null;
    return chiffres.startsWith('237') ? chiffres : '237$chiffres';
  }

  @override
  Widget build(BuildContext context) {
    final numero = _international;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (numero != null)
          FilledButton.tonalIcon(
            key: const Key('interlocuteur-appeler'),
            onPressed: () => joindre(
              context,
              Uri(scheme: 'tel', path: '+$numero'),
              aCopier: telephone!,
            ),
            icon: const Icon(Icons.call_outlined, size: 18),
            label: const Text('Appeler'),
          ),
        if (numero != null)
          FilledButton.tonalIcon(
            key: const Key('interlocuteur-whatsapp'),
            onPressed: () => joindre(
              context,
              Uri.https('wa.me', '/$numero', {
                'text':
                    'Bonjour, je vous écris au sujet du dossier $denomination.',
              }),
              aCopier: telephone!,
            ),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('WhatsApp'),
          ),
        if (courriel != null)
          OutlinedButton.icon(
            key: const Key('interlocuteur-courriel'),
            onPressed: () => joindre(
              context,
              Uri(
                scheme: 'mailto',
                path: courriel,
                queryParameters: {'subject': 'Dossier $denomination'},
              ),
              aCopier: courriel!,
            ),
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('Écrire'),
          ),
      ],
    );
  }
}
