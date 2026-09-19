import 'package:flutter/material.dart';

import '../api/client_api.dart';

/// L'écran d'entrée : le seul que voit un adhérent non identifié.
class EcranDeConnexion extends StatefulWidget {
  const EcranDeConnexion({
    super.key,
    required this.client,
    required this.quandConnecte,
  });

  final ClientApi client;
  final VoidCallback quandConnecte;

  @override
  State<EcranDeConnexion> createState() => _EtatDeLaConnexion();
}

class _EtatDeLaConnexion extends State<EcranDeConnexion> {
  final _courriel = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _courriel.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _entrer() async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    bool reussi;
    try {
      reussi = await widget.client.ouvrirUneSession(
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'CGA Broad Range',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Vos justificatifs, depuis le terrain',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _courriel,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Courriel',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _motDePasse,
                  obscureText: true,
                  onSubmitted: (_) => _entrer(),
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_erreur != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _erreur!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _enCours ? null : _entrer,
                  child: Text(_enCours ? 'Un instant…' : 'Entrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
