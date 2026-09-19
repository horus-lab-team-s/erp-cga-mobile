import 'package:flutter/material.dart';

import '../ports/service_de_session.dart';
import '../marque.dart';

/// L'écran d'entrée : le seul que voit un adhérent non identifié.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CE QUE CET ÉCRAN DOIT FAIRE, ET QU'IL NE FAISAIT PAS
///
/// Il doit dire **à qui l'on parle** avant de demander quoi que ce soit. Un
/// adhérent qui ouvre une application pour y taper le mot de passe de son
/// cabinet doit reconnaître le cabinet, pas un titre en toutes lettres sur fond
/// clair, qui ressemble à n'importe quelle application.
///
/// D'où le bandeau indigo et le logo. L'indigo porte l'institution ; c'est son
/// rôle dans le système, et c'est ici qu'il sert le plus.
///
/// ⚠️ ET LE SEUL BOUTON DE L'ÉCRAN EST MAGENTA, une seule fois. Le magenta porte
/// l'action. Deux boutons magenta sur un écran, et plus aucun ne se détache.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranDeConnexion extends StatefulWidget {
  const EcranDeConnexion({
    super.key,
    required this.session,
    required this.quandConnecte,
  });

  final ServiceDeSession session;
  final VoidCallback quandConnecte;

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

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Column(
        children: [
          _Enseigne(sombre: sombre),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('champ-courriel'),
                    controller: _courriel,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _champMotDePasse.requestFocus(),
                    decoration: const InputDecoration(
                      labelText: 'Courriel',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('champ-mot-de-passe'),
                    controller: _motDePasse,
                    focusNode: _champMotDePasse,
                    obscureText: !_motDePasseVisible,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _entrer(),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      // ⚠️ Un mot de passe de vingt-quatre caractères se tape
                      // sur un clavier de téléphone. Sans moyen de le relire,
                      // on se trompe et on ne sait pas où.
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
                  if (_erreur != null) ...[
                    const SizedBox(height: 16),
                    _Avertissement(texte: _erreur!),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    key: const Key('bouton-entrer'),
                    onPressed: _enCours ? null : _entrer,
                    child: _enCours
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Entrer'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Vous n'avez pas encore de mot de passe ? Le cabinet vous a "
                    'envoyé un lien par courriel lors de votre adhésion.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le bandeau qui dit à qui l'on parle.
class _Enseigne extends StatelessWidget {
  const _Enseigne({required this.sombre});

  final bool sombre;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: sombre ? Marque.indigo900Sombre : Marque.indigo900,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.paddingOf(context).top + 36,
        24,
        36,
      ),
      child: Column(
        children: [
          // ⚠️ Le logo BLANC sur l'indigo. La version en couleur porte un fond
          // blanc opaque : posée ici, elle ferait une vignette rectangulaire au
          // milieu du bandeau.
          Image.asset(
            Marque.logoBlanc,
            height: 72,
            fit: BoxFit.contain,
            // Le nom du cabinet est DANS l'image : sans cette étiquette, un
            // lecteur d'écran annonce « image » et rien d'autre.
            semanticLabel: 'CGA Broad Range Consulting Group',
          ),
          const SizedBox(height: 20),
          const Text(
            'Vos justificatifs, depuis le terrain',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Color(0xFFD9D2E8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un refus, dit par la couleur ET par un mot.
///
/// ⚠️ L'icône et le texte comptent autant que le fond : le § 9 du dossier de
/// design interdit que la couleur porte seule l'information. Un adhérent qui ne
/// distingue pas le rouge doit comprendre la même chose.
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
        borderRadius: BorderRadius.circular(10),
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
