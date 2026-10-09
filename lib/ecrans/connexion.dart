import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/joindre.dart';
import '../contenu/cabinet.dart';
import '../marque.dart';
import '../ports/service_de_session.dart';

/// L'écran d'entrée de l'espace adhérent.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CET ÉCRAN DOIT FAIRE
///
///   1. dire **à qui l'on parle** avant de demander un mot de passe : la
///      marque, et une image de personnes, pas un formulaire nu ;
///   2. **rassurer** : la vitrine porte une phrase que tout cabinet devrait
///      écrire — « le cabinet ne vous demandera jamais votre mot de passe ».
///      Elle est ici, sous le bouton, là où elle protège ;
///   3. **ne jamais laisser sans issue** : un mot de passe oublié mène à un
///      lien par courriel, puis à une personne si rien n'arrive ; un visiteur
///      sans compte mène à l'offre.
///
/// ⚠️ LA PHOTO NE PORTE AUCUN TEXTE, ET C'EST UN CALCUL, PAS UN GOÛT.
///
/// Pour qu'un texte blanc tienne 4,5:1 là où la photo est la plus claire — le
/// mur, la fenêtre —, il faudrait un voile indigo à 72 %. À ce taux, les
/// visages s'éteignent et la photo ne sert plus à rien. La photo ne porte donc
/// que la flèche et le logo : des objets graphiques, dont le seuil est de 3:1,
/// atteint avec un voile à 52 % (3,35:1 sur du blanc pur). Tout le texte est
/// sur la feuille blanche, en encre sombre.
///
/// ⚠️ UNE SEULE ACTION PLEINE — « Se connecter » —, en magenta. Les autres
/// gestes sont des liens ou des boutons à contour : § 10.7.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranDeConnexion extends StatefulWidget {
  const EcranDeConnexion({
    super.key,
    required this.session,
    required this.quandConnecte,
    this.quandRetour,
    this.demanderUnLien,
  });

  final ServiceDeSession session;
  final VoidCallback quandConnecte;

  /// Demande au serveur un lien de réinitialisation. `null` : l'écran ne
  /// propose que de joindre le cabinet.
  final Future<bool> Function(String courriel)? demanderUnLien;

  /// ⚠️ LE RETOUR VERS L'OFFRE, ET SON ABSENCE ÉTAIT UN PIÈGE.
  ///
  /// L'application s'ouvre sur le catalogue. Un visiteur qui touchait « Se
  /// connecter » par curiosité arrivait ici **sans aucun moyen de revenir** :
  /// l'écran est substitué au catalogue, pas empilé dessus. Il devait tuer
  /// l'application.
  ///
  /// `null` quand il n'y a rien derrière : le cas d'une session expirée alors
  /// que l'adhérent était déjà entré.
  final VoidCallback? quandRetour;

  @override
  State<EcranDeConnexion> createState() => _EtatDeLaConnexion();
}

class _EtatDeLaConnexion extends State<EcranDeConnexion> {
  final _courriel = TextEditingController();
  final _motDePasse = TextEditingController();
  final _champMotDePasse = FocusNode();
  bool _enCours = false;
  bool _motDePasseVisible = false;
  String? _erreur;

  @override
  void dispose() {
    _courriel.dispose();
    _motDePasse.dispose();
    _champMotDePasse.dispose();
    super.dispose();
  }

  Future<void> _entrer() async {
    // ⚠️ Le clavier se ferme AVANT l'appel. Sans cela, le message d'erreur
    // s'affiche derrière le clavier : l'adhérent voit le bouton redevenir actif
    // sans comprendre pourquoi rien ne se passe.
    FocusScope.of(context).unfocus();
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    bool reussi;
    try {
      reussi = await widget.session.ouvrirUneSession(
        _courriel.text.trim(),
        _motDePasse.text,
      );
    } on Object {
      // ⚠️ Sans réseau, on ne dit pas « identifiants incorrects ». L'adhérent
      // recommencerait dix fois en croyant s'être trompé, et finirait par
      // demander une réinitialisation dont il n'a pas besoin.
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur = "Le serveur n'a pas répondu. Vérifiez votre connexion.";
      });
      return;
    }
    if (!mounted) return;
    setState(() => _enCours = false);
    if (reussi) {
      widget.quandConnecte();
    } else {
      setState(() => _erreur = 'Courriel ou mot de passe incorrect.');
    }
  }

  /// « Mot de passe oublié ? » : un lien par courriel, et une personne à
  /// joindre si rien n'arrive.
  ///
  /// ⚠️ LE SERVEUR ENVOIE LE LIEN À L'ADRESSE QU'IL CONNAÎT, et répond « pris
  /// en compte » dans tous les cas — y compris pour une adresse inconnue, pour
  /// ne pas révéler qui est client du cabinet. L'écran ne peut donc JAMAIS
  /// dire « un lien vous a été envoyé » : il dit « si un compte existe à cette
  /// adresse, un lien vient d'y partir ».
  void _motDePasseOublie() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // Le clavier doit pouvoir remonter la feuille, qui porte un champ.
      isScrollControlled: true,
      builder: (_) => _FeuilleOubli(
        parent: context,
        courriel: _courriel.text.trim(),
        demanderUnLien: widget.demanderUnLien,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    // ⚠️ La photo se RÉDUIT quand le clavier s'ouvre. Sur un écran de six
    // pouces, clavier ouvert, il reste environ 380 points : avec la photo
    // entière, le champ du mot de passe passait sous le clavier, et
    // l'adhérent tapait à l'aveugle.
    final clavierOuvert = media.viewInsets.bottom > 0;
    final hauteurPhoto = clavierOuvert
        ? media.padding.top + 64
        : (media.size.height * 0.36).clamp(220.0, 340.0);

    // ⚠️ LES ICÔNES DE LA BARRE D'ÉTAT EN BLANC. L'écran n'a pas de barre
    // d'application pour le dire au système : l'heure et la batterie
    // s'affichaient en gris foncé sur la photo sombre, presque invisibles —
    // vu sur le téléphone.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        // ⚠️ Le bouton « retour » du téléphone fait la même chose que la
        // flèche. Sur Android, c'est le geste que tout le monde essaie en
        // premier ; s'il fermait l'application, le visiteur croirait s'être
        // trompé d'application.
        canPop: widget.quandRetour == null,
        onPopInvokedWithResult: (parti, _) {
          if (!parti) widget.quandRetour?.call();
        },
        child: Scaffold(
          backgroundColor: Marque.indigo900,
          body: Column(
            children: [
              // ── La photo, la marque, la sortie ─────────────────────────────
              AnimatedContainer(
                // 200 ms : juste assez pour que l'œil suive la photo qui se
                // retire, sans rien de spectaculaire — § 10.7.
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                height: hauteurPhoto,
                width: double.infinity,
                child: _Photo(quandRetour: widget.quandRetour),
              ),

              // ── La feuille ─────────────────────────────────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: couleurs.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(Marque.rayonCarte + 6),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      28,
                      24,
                      24 + media.padding.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'ESPACE ADHÉRENT',
                          style: texte.labelMedium?.copyWith(
                            color: couleurs.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Accéder à votre dossier',
                          style: texte.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Vos échéances, vos justificatifs et les documents que '
                          'le cabinet dépose pour vous.',
                          style: texte.bodyMedium?.copyWith(
                            color: couleurs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),

                        TextField(
                          key: const Key('champ-courriel'),
                          controller: _courriel,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _champMotDePasse.requestFocus(),
                          decoration: const InputDecoration(
                            labelText: 'Adresse électronique',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: const Key('champ-mot-de-passe'),
                          controller: _motDePasse,
                          focusNode: _champMotDePasse,
                          obscureText: !_motDePasseVisible,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _entrer(),
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            // ⚠️ Un mot de passe de vingt-quatre caractères se
                            // tape sur un clavier de téléphone. Sans moyen de le
                            // relire, on se trompe et on ne sait pas où.
                            suffixIcon: IconButton(
                              key: const Key('bascule-mot-de-passe'),
                              onPressed: () => setState(
                                () => _motDePasseVisible = !_motDePasseVisible,
                              ),
                              icon: Icon(
                                _motDePasseVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              tooltip: _motDePasseVisible
                                  ? 'Masquer le mot de passe'
                                  : 'Afficher le mot de passe',
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const Key('mot-de-passe-oublie'),
                            onPressed: _motDePasseOublie,
                            child: const Text('Mot de passe oublié ?'),
                          ),
                        ),

                        if (_erreur != null) ...[
                          _Avertissement(texte: _erreur!),
                          const SizedBox(height: 14),
                        ] else
                          const SizedBox(height: 4),

                        FilledButton(
                          key: const Key('bouton-entrer'),
                          onPressed: _enCours ? null : _entrer,
                          child: _enCours
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: couleurs.onPrimary,
                                  ),
                                )
                              : const Text('Se connecter'),
                        ),
                        const SizedBox(height: 20),

                        // ⚠️ La phrase est celle de la vitrine, mot pour mot, et
                        // posée SOUS le bouton : à l'endroit exact où l'on vient
                        // de taper le mot de passe. C'est là qu'un faux
                        // « conseiller » qui le réclamerait au téléphone doit
                        // paraître suspect.
                        const _NoteDeSecurite(),

                        if (widget.quandRetour != null) ...[
                          const SizedBox(height: 28),
                          const _Separateur(texte: 'Pas encore adhérent ?'),
                          const SizedBox(height: 12),
                          Text(
                            'Votre accès vous est envoyé par courriel dès votre '
                            'souscription réglée.',
                            textAlign: TextAlign.center,
                            style: texte.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            key: const Key('voir-l-offre'),
                            onPressed: widget.quandRetour,
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text("Découvrir l'offre du cabinet"),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La photo, sous un voile indigo, avec la marque et la sortie.
class _Photo extends StatelessWidget {
  const _Photo({required this.quandRetour});
  final VoidCallback? quandRetour;

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/photos/connexion.jpg',
          fit: BoxFit.cover,
          // Les visages sont dans le tiers haut de l'image : c'est eux que
          // l'on garde quand la hauteur se réduit.
          alignment: const Alignment(0, -0.35),
          // ⚠️ Décorative : un lecteur d'écran n'a rien à en dire, et
          // l'annoncer ferait entendre « image » avant le nom du cabinet.
          excludeFromSemantics: true,
          // Sans l'image — paquet corrompu, mémoire saturée —, l'aplat
          // indigo reste : l'écran demeure utilisable.
          errorBuilder: (_, _, _) => const SizedBox(),
        ),
        // ⚠️ 52 % d'indigo : 3,35:1 pour une icône blanche sur la zone la
        // plus claire de la photo. Voir l'en-tête du fichier.
        ColoredBox(color: Marque.indigo900.withValues(alpha: 0.52)),
        Positioned(
          left: 16,
          right: 20,
          top: haut + 8,
          child: Row(
            children: [
              if (quandRetour != null)
                IconButton(
                  key: const Key('retour-a-l-offre'),
                  onPressed: quandRetour,
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.white,
                  // ⚠️ L'étiquette dit OÙ l'on revient, pas « retour ».
                  tooltip: "Revenir à l'offre du cabinet",
                ),
              const Spacer(),
              // ⚠️ Le logo BLANC. La version en couleur porte un fond blanc
              // opaque : posée ici, elle ferait une vignette rectangulaire.
              Image.asset(
                Marque.logoBlanc,
                height: 44,
                fit: BoxFit.contain,
                // Le nom du cabinet est DANS l'image : sans cette étiquette,
                // un lecteur d'écran annonce « image » et rien d'autre.
                semanticLabel: Cabinet.nom,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// La phrase qui protège du faux conseiller.
class _NoteDeSecurite extends StatelessWidget {
  const _NoteDeSecurite();

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: couleurs.secondaryContainer,
        borderRadius: BorderRadius.circular(Marque.rayonBloc),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 20,
            color: couleurs.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Le cabinet ne vous demandera jamais votre mot de passe, ni par '
              'téléphone, ni par WhatsApp, ni par courriel.',
              key: const Key('note-de-securite'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: couleurs.onSecondaryContainer,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Separateur extends StatelessWidget {
  const _Separateur({required this.texte});
  final String texte;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(texte, style: Theme.of(context).textTheme.titleSmall),
      ),
      const Expanded(child: Divider()),
    ],
  );
}

/// Ce qu'on fait quand on a oublié son mot de passe.
class _FeuilleOubli extends StatefulWidget {
  const _FeuilleOubli({
    required this.parent,
    required this.courriel,
    required this.demanderUnLien,
  });

  /// Le contexte de l'écran, et non celui de la feuille : le message de repli
  /// de `joindre` doit s'afficher après la fermeture de la feuille.
  final BuildContext parent;

  /// Ce que l'adhérent a déjà tapé sur l'écran : inutile de le lui redemander.
  final String courriel;
  final Future<bool> Function(String)? demanderUnLien;

  @override
  State<_FeuilleOubli> createState() => _EtatDeLOubli();
}

enum _EtapeOubli { saisie, enCours, prise, echec }

class _EtatDeLOubli extends State<_FeuilleOubli> {
  late final _champ = TextEditingController(text: widget.courriel);
  var _etape = _EtapeOubli.saisie;

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  Future<void> _demander() async {
    final demander = widget.demanderUnLien;
    final courriel = _champ.text.trim();
    if (demander == null || !courriel.contains('@')) return;
    FocusScope.of(context).unfocus();
    setState(() => _etape = _EtapeOubli.enCours);
    final pris = await demander(courriel);
    if (!mounted) return;
    setState(() => _etape = pris ? _EtapeOubli.prise : _EtapeOubli.echec);
  }

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final couleurs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mot de passe oublié', style: texte.titleLarge),
            const SizedBox(height: 8),
            if (widget.demanderUnLien != null &&
                _etape != _EtapeOubli.prise) ...[
              Text(
                'Indiquez votre adresse : le cabinet y envoie un lien pour '
                'choisir un nouveau mot de passe.',
                style: texte.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('champ-oubli'),
                controller: _champ,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _demander(),
                decoration: const InputDecoration(
                  labelText: 'Adresse électronique',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              if (_etape == _EtapeOubli.echec) ...[
                const SizedBox(height: 10),
                Text(
                  "Le serveur n'a pas reçu la demande. Vérifiez votre "
                  'connexion, puis réessayez.',
                  key: const Key('oubli-echec'),
                  style: texte.bodySmall?.copyWith(color: couleurs.error),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                key: const Key('oubli-envoyer'),
                onPressed: _etape == _EtapeOubli.enCours ? null : _demander,
                child: _etape == _EtapeOubli.enCours
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: couleurs.onPrimary,
                        ),
                      )
                    : const Text('Recevoir un lien'),
              ),
            ],
            if (_etape == _EtapeOubli.prise)
              // ⚠️ « SI un compte existe » : le serveur répond de la même
              // façon pour une adresse inconnue, et c'est voulu. Écrire « un
              // lien vous a été envoyé » serait faux une fois sur deux.
              Container(
                key: const Key('oubli-pris'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: couleurs.secondaryContainer,
                  borderRadius: BorderRadius.circular(Marque.rayonBloc),
                ),
                child: Text(
                  'Si un compte est ouvert à cette adresse, un lien vient d\'y '
                  'partir. Pensez à regarder dans les courriers indésirables.',
                  style: texte.bodyMedium?.copyWith(
                    color: couleurs.onSecondaryContainer,
                  ),
                ),
              ),
            const SizedBox(height: 22),
            Text(
              'Rien reçu, ou plus accès à cette adresse ? Votre chargé de '
              'clientèle vous renvoie un lien. Il ne vous demandera jamais '
              'votre mot de passe.',
              key: const Key('aide-oubli'),
              style: texte.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('oubli-whatsapp'),
                    onPressed: () {
                      Navigator.pop(context);
                      joindre(
                        widget.parent,
                        Cabinet.whatsappLien,
                        aCopier: Cabinet.whatsapp,
                      );
                    },
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('WhatsApp'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('oubli-appeler'),
                    onPressed: () {
                      Navigator.pop(context);
                      joindre(
                        widget.parent,
                        Cabinet.telephoneLien,
                        aCopier: Cabinet.telephone,
                      );
                    },
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Appeler'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Un refus, dit par la couleur ET par un mot.
class _Avertissement extends StatelessWidget {
  const _Avertissement({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: couleurs.errorContainer,
        borderRadius: BorderRadius.circular(Marque.rayonBloc),
        border: Border(left: BorderSide(color: couleurs.error, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: couleurs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texte,
              key: const Key('message-erreur'),
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: couleurs.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
