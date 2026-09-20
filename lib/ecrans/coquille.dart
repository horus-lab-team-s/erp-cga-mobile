import 'package:flutter/material.dart';

import '../domaine/depot.dart';
import '../domaine/file_d_attente.dart';
import '../domaine/prise_de_vue.dart';
import '../ports/service_de_session.dart';
import 'accueil.dart';
import 'echeances.dart';
import 'historique.dart';

/// La charpente de l'application, une fois la session ouverte.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI UNE BARRE DE NAVIGATION, ET POURQUOI MAINTENANT
///
/// L'application n'avait qu'un écran, et ses gestes tenaient dans la barre du
/// haut : envoyer, historique, se déconnecter. L'historique a fait trois icônes,
/// les échéances en feraient quatre, et il en reste deux à venir — mes documents
/// et mon entreprise. Six icônes dans une barre de titre de téléphone ne se
/// distinguent plus les unes des autres, et l'adhérent apprend à ne plus les
/// regarder.
///
/// ⚠️ Poser la charpente MAINTENANT plutôt qu'à la sixième icône : une
/// navigation ajoutée après coup oblige à reprendre chaque écran, et les cas
/// d'essai avec. Ici elle ne coûte qu'un fichier.
///
/// ⚠️ TROIS DESTINATIONS, PAS CINQ. Les deux écrans qui manquent ne sont pas
/// encore écrits ; les annoncer dans la barre montrerait à l'adhérent des portes
/// qui ne s'ouvrent pas. On les ajoutera quand ils existeront.
/// ─────────────────────────────────────────────────────────────────────────────
class Coquille extends StatefulWidget {
  const Coquille({
    super.key,
    required this.session,
    required this.file,
    required this.priseDeVue,
    required this.remettre,
    required this.quandDeconnecte,
  });

  final ServiceDeSession session;
  final FileDAttente file;
  final PriseDeVue priseDeVue;
  final Future<Reponse> Function(Depot) remettre;
  final VoidCallback quandDeconnecte;

  @override
  State<Coquille> createState() => _EtatDeLaCoquille();
}

class _EtatDeLaCoquille extends State<Coquille> {
  int _onglet = 0;

  /// ⚠️ Lus ICI, une fois, et passés aux écrans qui en ont besoin.
  ///
  /// Chaque écran les relisait pour son compte : trois écrans, trois appels à
  /// `/transverse/moi` à chaque ouverture, sur un réseau qu'on sait mauvais. Et
  /// surtout, trois réponses possiblement différentes si l'une échoue, donc un
  /// sélecteur de dossier présent sur un écran et absent sur l'autre.
  ///
  /// ⚠️ `null` TANT QUE LA LECTURE N'A PAS ABOUTI, et non une liste vide.
  ///
  /// La distinction n'est pas cosmétique : elle a coûté un défaut visible sur
  /// l'appareil. Avec une liste vide au départ, les écrans d'échéances et
  /// d'historique se construisaient aussitôt et interrogeaient le serveur avec
  /// un dossier vide. Le serveur rendait 404, l'écran retenait « pas de réseau »,
  /// et l'adhérent ouvrait l'onglet sur un message de panne alors que tout
  /// fonctionnait. Une liste vide dit « ce compte n'a aucun dossier » ; c'est une
  /// réponse, pas une attente.
  List<String>? _dossiers;

  @override
  void initState() {
    super.initState();
    _lireLesDossiers();
  }

  Future<void> _lireLesDossiers() async {
    List<String> dossiers;
    try {
      dossiers = await widget.session.mesDossiers();
    } on Object {
      dossiers = const [];
    }
    if (mounted) setState(() => _dossiers = dossiers);
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ `IndexedStack` et non un `switch` : chaque écran garde son état, sa
    // position de défilement et sa liste déjà lue quand on change d'onglet.
    // Reconstruire à chaque passage redemanderait au serveur à chaque coup
    // d'onglet, ce qu'un adhérent en 3G paie.
    final dossiers = _dossiers;
    return Scaffold(
      body: IndexedStack(
        index: _onglet,
        children: [
          // ⚠️ L'accueil, LUI, se construit tout de suite : la file d'attente
          // vit sur l'appareil, il n'a besoin d'aucun dossier pour la montrer.
          // C'est même ce qu'il doit montrer en priorité quand le réseau manque.
          EcranAccueil(
            session: widget.session,
            file: widget.file,
            priseDeVue: widget.priseDeVue,
            remettre: widget.remettre,
            quandDeconnecte: widget.quandDeconnecte,
            dossiers: dossiers ?? const [],
          ),
          // ⚠️ Ces deux-là n'existent QUE lorsqu'un dossier est connu : tous
          // deux interrogent le serveur sur un dossier précis, et le faire avec
          // une chaîne vide rend 404, que l'écran retient comme une panne.
          if (dossiers == null)
            const _EnAttenteDeDossier(titre: 'Mes échéances')
          else if (dossiers.isEmpty)
            const _SansDossier(titre: 'Mes échéances')
          else
            EcranEcheances(
              session: widget.session,
              dossiers: dossiers,
              quandSessionExpire: widget.quandDeconnecte,
              priseDeVue: widget.priseDeVue,
            ),
          if (dossiers == null)
            const _EnAttenteDeDossier(titre: 'Pièces remises')
          else if (dossiers.isEmpty)
            const _SansDossier(titre: 'Pièces remises')
          else
            EcranHistorique(
              session: widget.session,
              dossiers: dossiers,
              quandSessionExpire: widget.quandDeconnecte,
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _onglet,
        onDestinationSelected: (i) => setState(() => _onglet = i),
        destinations: const [
          NavigationDestination(
            key: Key('onglet-deposer'),
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera),
            label: 'Déposer',
          ),
          NavigationDestination(
            key: Key('onglet-echeances'),
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Échéances',
          ),
          NavigationDestination(
            key: Key('onglet-pieces'),
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Mes pièces',
          ),
        ],
      ),
    );
  }
}

/// Le temps que la coquille sache quels dossiers le compte porte.
class _EnAttenteDeDossier extends StatelessWidget {
  const _EnAttenteDeDossier({required this.titre});

  final String titre;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(titre)),
    body: const Center(child: CircularProgressIndicator()),
  );
}

/// Le compte n'ouvre aucun dossier : il n'y a rien à interroger.
///
/// ⚠️ On le DIT, au lieu d'interroger le serveur avec un dossier vide et de
/// laisser l'écran conclure à une panne de réseau. Ce sont deux situations
/// différentes, et une seule appelle un appel au cabinet.
class _SansDossier extends StatelessWidget {
  const _SansDossier({required this.titre});

  final String titre;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(32, 90, 32, 32),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: couleurs.onSurfaceVariant,
            ),
            const SizedBox(height: 18),
            Text(
              'Aucun dossier à votre nom',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: couleurs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Le cabinet n'a pas encore ouvert votre espace. Appelez votre "
              'chargé de clientèle.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: couleurs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
