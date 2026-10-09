import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../marque.dart';
import '../domaine/depot.dart';
import '../domaine/file_d_attente.dart';
import '../domaine/prise_de_vue.dart';
import '../ports/service_de_session.dart';
import '../ports/service_des_fichiers.dart';
import '../ports/service_du_tableau_de_bord.dart';
import 'accueil.dart';
import 'echeances.dart';
import 'historique.dart';
import 'documents.dart';
import 'mon_entreprise.dart';
import 'tableau_de_bord.dart';
import 'visionneuse.dart';

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
/// ⚠️ CINQ DESTINATIONS, ET C'EST LE MAXIMUM.
///
/// « Mes documents » a longtemps manqué, non par oubli mais parce que le
/// serveur rendait zéro accusé : le trou était dans le jeu de démonstration, et
/// il a fallu le combler côté serveur avant d'ouvrir l'onglet. Annoncer une
/// porte qui s'ouvre sur du vide aurait été pire que de la taire.
///
/// ⚠️ Au-delà de cinq, une barre de navigation Material se replie ou se tasse,
/// et les libellés deviennent illisibles sur un téléphone étroit. Le prochain
/// écran ne s'ajoutera pas ici : il faudra choisir ce qui descend d'un rang.
/// ─────────────────────────────────────────────────────────────────────────────
class Coquille extends StatefulWidget {
  const Coquille({
    super.key,
    required this.session,
    required this.file,
    required this.priseDeVue,
    required this.remettre,
    required this.quandDeconnecte,
    required this.tableau,
    this.fichiers,
  });

  final ServiceDeSession session;

  /// Ce que l'accueil lit en plus des autres écrans : le mois, le nom.
  final ServiceDuTableauDeBord tableau;

  /// De quoi ouvrir le document d'une pièce déposée.
  final ServiceDesFichiers? fichiers;
  final FileDAttente file;
  final PriseDeVue priseDeVue;
  final Future<Reponse> Function(Depot) remettre;
  final VoidCallback quandDeconnecte;

  @override
  State<Coquille> createState() => _EtatDeLaCoquille();
}

class _EtatDeLaCoquille extends State<Coquille> {
  /// ⚠️ La clé de l'écran de dépôt : elle permet à la barre du bas de déclencher
  /// la prise de vue quand l'onglet est DÉJÀ ouvert. Autrement, le bouton
  /// central ne ferait rien sur son propre onglet, et l'adhérent attendrait
  /// l'appareil photo.
  final _depot = GlobalKey<EtatDeLAccueil>();

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

  /// Combien de pièces attendent encore de partir.
  ///
  /// ⚠️ UNE SEULE SOURCE, TENUE PAR L'ÉCRAN QUI RELIT LA FILE. La barre du bas
  /// l'affiche sur le bouton de dépôt ; si elle relisait la file pour son
  /// compte, deux lectures du même état pourraient se contredire à l'écran —
  /// « tout est parti » d'un côté, « 2 » de l'autre.
  final _enAttente = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _lireLesDossiers();
  }

  @override
  void dispose() {
    _enAttente.dispose();
    super.dispose();
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

  /// L'historique des pièces, ouvert PAR-DESSUS la coquille : il a sa propre
  /// flèche de retour, qui ramène à l'accueil.
  void _ouvrirMesPieces(List<String> dossiers) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EcranHistorique(
        session: widget.session,
        dossiers: dossiers,
        quandSessionExpire: widget.quandDeconnecte,
        fichiers: widget.fichiers,
      ),
    ),
  );

  /// Le document d'une pièce, ouvert par-dessus la coquille.
  void _ouvrirPiece(String piece) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EcranVisionneuse(
        fichiers: widget.fichiers!,
        piece: piece,
        titre: piece,
        quandSessionExpire: widget.quandDeconnecte,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // ⚠️ `IndexedStack` et non un `switch` : chaque écran garde son état, sa
    // position de défilement et sa liste déjà lue quand on change d'onglet.
    // Reconstruire à chaque passage redemanderait au serveur à chaque coup
    // d'onglet, ce qu'un adhérent en 3G paie.
    final dossiers = _dossiers;
    return Scaffold(
      // ⚠️ La barre FLOTTE au-dessus du contenu : elle est détachée des bords.
      // Chaque écran laisse `Marque.espaceSousLaBarre` en bas pour que sa
      // dernière carte ne finisse pas dessous.
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _onglet,
            children: [
              // ── 0. Accueil ─────────────────────────────────────────────────
              if (dossiers == null)
                const _EnAttenteDeDossier(titre: 'Accueil')
              else if (dossiers.isEmpty)
                const _SansDossier(titre: 'Accueil')
              else
                EcranTableauDeBord(
                  session: widget.session,
                  tableau: widget.tableau,
                  dossiers: dossiers,
                  quandSessionExpire: widget.quandDeconnecte,
                  allerALOnglet: (i) => setState(() => _onglet = i),
                  ouvrirMesPieces: () => _ouvrirMesPieces(dossiers),
                  ouvrirPiece: widget.fichiers == null ? null : _ouvrirPiece,
                  seDeconnecter: () async {
                    await widget.session.fermerLaSession();
                    widget.quandDeconnecte();
                  },
                ),
              // ── 1. Échéances ───────────────────────────────────────────────
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
              // ── 2. Déposer ─────────────────────────────────────────────────
              // ⚠️ Le dépôt, LUI, se construit tout de suite : la file d'attente
              // vit sur l'appareil, il n'a besoin d'aucun dossier pour la montrer.
              // C'est même ce qu'il doit montrer en priorité quand le réseau manque.
              EcranAccueil(
                key: _depot,
                session: widget.session,
                file: widget.file,
                priseDeVue: widget.priseDeVue,
                remettre: widget.remettre,
                quandDeconnecte: widget.quandDeconnecte,
                dossiers: dossiers ?? const [],
                // ⚠️ Tant que les dossiers ne sont pas lus, pas de porte : elle
                // ouvrirait sur un écran qui ne saurait pas quoi demander.
                ouvrirLHistorique: dossiers == null || dossiers.isEmpty
                    ? null
                    : () => _ouvrirMesPieces(dossiers),
                compteurEnAttente: _enAttente,
              ),
              // ── 3. Documents ───────────────────────────────────────────────
              if (dossiers == null)
                const _EnAttenteDeDossier(titre: 'Mes documents')
              else if (dossiers.isEmpty)
                const _SansDossier(titre: 'Mes documents')
              else
                EcranDocuments(
                  session: widget.session,
                  dossiers: dossiers,
                  quandSessionExpire: widget.quandDeconnecte,
                  // ⚠️ « Documents » est l'onglet où l'on cherche un document,
                  // quel qu'en soit le sens. Les accusés déposés PAR le cabinet
                  // y étaient seuls ; les pièces remises AU cabinet vivaient
                  // sur un écran auquel rien ne menait depuis ici.
                  ouvrirLHistorique: () => _ouvrirMesPieces(dossiers),
                ),
              // ── 4. Entreprise ──────────────────────────────────────────────
              if (dossiers == null)
                const _EnAttenteDeDossier(titre: 'Mon entreprise')
              else if (dossiers.isEmpty)
                const _SansDossier(titre: 'Mon entreprise')
              else
                EcranMonEntreprise(
                  session: widget.session,
                  dossiers: dossiers,
                  quandSessionExpire: widget.quandDeconnecte,
                ),
            ],
          ),
          const _VoileSousLaListe(),
        ],
      ),
      // ⚠️ LA BARRE DU BAS EST POSÉE SUR LE CONTENU, et doit le paraître :
      // une ombre remontante très basse suffit à la faire exister.
      //
      // ⚠️ CINQ DESTINATIONS, DANS L'ORDRE DES QUESTIONS DE L'ADHÉRENT : où en
      // suis-je (Accueil), qu'est-ce que je dois (Échéances), j'envoie une
      // pièce (Déposer, au centre, sous le pouce), qu'est-ce que le cabinet a
      // fait pour moi (Documents), qui suis-je pour le cabinet (Entreprise).
      // « Mes pièces » n'a plus d'onglet : c'est un historique, qu'on ouvre
      // depuis l'accueil, pas une question qu'on se pose chaque jour.
      bottomNavigationBar: _BarreDuBas(
        onglet: _onglet,
        enAttente: _enAttente,
        surChoix: (i) {
          if (i == _onglet) return;
          // ⚠️ UN RETOUR AU DOIGT, DISCRET, À CHAQUE CHANGEMENT D'ONGLET.
          //
          // Sur une dalle bon marché, l'affichage met parfois deux dixièmes de
          // seconde à basculer ; sans retour, l'adhérent croit avoir raté sa
          // cible et appuie une seconde fois. `selectionClick` est le retour le
          // plus léger du système : il dit « c'est pris », sans secouer.
          HapticFeedback.selectionClick();
          setState(() => _onglet = i);
        },
        surDeposer: () {
          // Le dépôt est le geste principal : un retour un peu plus franc.
          HapticFeedback.mediumImpact();
          _depot.currentState?.photographier();
        },
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

/// Le fondu qui termine une liste au ras de la barre.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ CE QUE CE VOILE CORRIGE, ET CE QU'IL NE CORRIGE PAS.
///
/// La barre flotte AU-DESSUS du contenu : au milieu d'un défilement, une carte
/// passe dessous et se coupe net sur son bord, comme si la page s'arrêtait là.
/// Deux lectures fausses en découlent : on croit la liste finie, et l'on croit
/// la carte tronquée.
///
/// Un fondu de la couleur du fond, sur vingt-quatre points juste au-dessus de
/// la barre, rend la coupure progressive : le contenu s'efface au lieu d'être
/// tranché, et l'œil comprend qu'il passe DERRIÈRE quelque chose.
///
/// ⚠️ Il ne remplace pas le coussin de `Marque.espaceSousLaBarreDe` : celui-ci
/// garantit que la DERNIÈRE ligne est lisible en entier. Le voile ne sert qu'au
/// trajet ; sans le coussin, il ne ferait qu'estomper joliment un texte coupé.
///
/// ⚠️ UN DÉGRADÉ, ET NON UN FLOU. Un `BackdropFilter` coûte une passe de rendu
/// par image sur un appareil d'entrée de gamme — la cible de ce produit. Le
/// dégradé ne coûte rien.
///
/// ⚠️ `IgnorePointer` : il couvre la zone que le pouce emploie pour faire
/// défiler. Sans cela, il l'avalerait.
/// ─────────────────────────────────────────────────────────────────────────────
class _VoileSousLaListe extends StatelessWidget {
  const _VoileSousLaListe();

  /// Sa hauteur. Au-delà, le fondu se remarque comme un effet ; en deçà, il ne
  /// se voit pas.
  static const hauteur = 24.0;

  @override
  Widget build(BuildContext context) {
    final fond = Theme.of(context).scaffoldBackgroundColor;
    // ⚠️ `paddingOf` et non une constante : c'est la hauteur que le `Scaffold`
    // annonce pour sa barre, encart système compris. Voir `Marque`.
    final sousLaBarre = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: sousLaBarre,
      height: hauteur,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [fond.withValues(alpha: 0), fond],
            ),
          ),
        ),
      ),
    );
  }
}

/// La barre du bas : quatre onglets, et le dépôt au centre.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ ELLE FLOTTE, ET C'EST UNE REPRISE DU 23 SEPTEMBRE 2026.
///
/// Collée au bord bas, pleine largeur, elle avait l'allure d'une barre système :
/// correcte, et sans caractère. Détachée — seize points sur les côtés, coins de
/// vingt-six —, elle devient un objet posé sur la page, comme les barres des
/// applications que l'adhérent emploie tous les jours.
///
/// ⚠️ L'ONGLET ACTIF PORTE UNE PASTILLE, et non une simple teinte de texte. Sur
/// une dalle bon marché au soleil, un magenta et un gris se ressemblent ; une
/// forme, non.
///
/// ⚠️ POURQUOI LE DÉPÔT N'EST PLUS UN ONGLET COMME LES AUTRES
///
/// L'adhérent ouvre l'application une facture à la main, et neuf fois sur dix
/// c'est pour la DÉPOSER ; le reste, il le consulte. Le geste principal prend
/// donc la place qu'il mérite : un bouton rond, plus grand, au centre, sous le
/// pouce. Sur son propre onglet, il déclenche l'appareil photo.
///
/// ⚠️ Mêmes index, mêmes clés (`onglet-deposer`…), même écran : ce qui change est
/// ce que l'œil comprend, pas le fonctionnement.
/// ─────────────────────────────────────────────────────────────────────────────
class _BarreDuBas extends StatelessWidget {
  const _BarreDuBas({
    required this.onglet,
    required this.enAttente,
    required this.surChoix,
    required this.surDeposer,
  });

  final int onglet;

  /// Combien de pièces attendent encore de partir, tenu par l'écran du dépôt.
  final ValueListenable<int> enAttente;

  final ValueChanged<int> surChoix;

  /// Ce que fait le bouton central quand l'onglet du dépôt est DÉJÀ ouvert :
  /// l'appareil photo, tout de suite.
  final VoidCallback surDeposer;

  /// L'index du dépôt dans les destinations de la coquille.
  static const _depot = 2;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final sombre = Theme.of(context).brightness == Brightness.dark;
    // La barre grandit avec le texte : à 130 %, les libellés débordaient.
    final echelle = MediaQuery.textScalerOf(context).scale(12) / 12;
    // ⚠️ 86 : le bouton central mesure 58 points, plus l'anneau de 8, plus son
    // libellé. À 70, il DÉBORDAIT de la barre — et ce qui déborde d'un parent
    // ne reçoit pas les appuis : le haut du bouton le plus important de
    // l'application était mort. Il tient désormais entièrement dedans.
    final hauteur = 86 + (echelle.clamp(1.0, 2.0) - 1) * 22;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Marque.espace4,
          0,
          Marque.espace4,
          Marque.espace3,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: couleurs.surface,
            borderRadius: BorderRadius.circular(26),
            border: sombre ? Border.all(color: couleurs.outlineVariant) : null,
            boxShadow: sombre ? null : Marque.ombreFlottante,
          ),
          child: SizedBox(
            height: hauteur,
            child: Row(
              // ⚠️ `stretch` : sans lui, chaque onglet ne fait que la hauteur de
              // son contenu — mesuré à 46 points, sous le seuil de 48 des règles
              // d'accessibilité. Étirés, ils occupent toute la barre, et le pouce
              // n'a plus à viser.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Onglet(
                  cle: 'onglet-accueil',
                  icone: Icons.home_outlined,
                  iconeChoisie: Icons.home,
                  libelle: 'Accueil',
                  choisi: onglet == 0,
                  surAppui: () => surChoix(0),
                ),
                _Onglet(
                  cle: 'onglet-echeances',
                  icone: Icons.event_outlined,
                  iconeChoisie: Icons.event,
                  libelle: 'Échéances',
                  choisi: onglet == 1,
                  surAppui: () => surChoix(1),
                ),
                _BoutonDeDepot(
                  choisi: onglet == _depot,
                  enAttente: enAttente,
                  surAppui: onglet == _depot
                      ? surDeposer
                      : () => surChoix(_depot),
                ),
                _Onglet(
                  cle: 'onglet-documents',
                  icone: Icons.description_outlined,
                  iconeChoisie: Icons.description,
                  libelle: 'Documents',
                  choisi: onglet == 3,
                  surAppui: () => surChoix(3),
                ),
                _Onglet(
                  cle: 'onglet-entreprise',
                  icone: Icons.storefront_outlined,
                  iconeChoisie: Icons.storefront,
                  // ⚠️ « Entreprise » et non « Mon entreprise » : l'écran porte
                  // déjà ce titre, et le répéter fait lire deux fois la même chose.
                  libelle: 'Entreprise',
                  choisi: onglet == 4,
                  surAppui: () => surChoix(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({
    required this.cle,
    required this.icone,
    required this.iconeChoisie,
    required this.libelle,
    required this.choisi,
    required this.surAppui,
  });

  final String cle;
  final IconData icone;
  final IconData iconeChoisie;
  final String libelle;
  final bool choisi;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final teinte = choisi ? couleurs.primary : couleurs.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        key: Key(cle),
        onTap: surAppui,
        borderRadius: BorderRadius.circular(20),
        child: Semantics(
          selected: choisi,
          button: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // La pastille : une FORME sous l'onglet actif, pas seulement une
              // teinte. Elle s'anime en cent cinquante millisecondes — assez
              // pour être vue, trop peu pour être attendue.
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: Marque.espace4,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: choisi
                      ? couleurs.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(Marque.rayonPastille),
                ),
                child: Icon(
                  choisi ? iconeChoisie : icone,
                  size: 21,
                  color: teinte,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  color: teinte,
                  fontWeight: choisi ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le dépôt : rond, surélevé, au centre.
class _BoutonDeDepot extends StatelessWidget {
  const _BoutonDeDepot({
    required this.choisi,
    required this.enAttente,
    required this.surAppui,
  });

  final bool choisi;

  /// Combien de pièces attendent encore de partir.
  final ValueListenable<int> enAttente;

  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Expanded(
      child: Center(
        child: Transform.translate(
          // Un léger décalage vers le haut : assez pour dire « ceci d'abord »,
          // pas assez pour sortir de la barre et perdre ses appuis.
          offset: const Offset(0, -6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ⚠️ UN ANNEAU DE LA COULEUR DE LA BARRE, et non une ombre portée.
              //
              // Le bouton déborde sur le contenu qui défile dessous. Posé avec une
              // simple élévation, son ombre dessinait un halo gris sale sur le
              // texte, et le bouton paraissait décollé de la barre. L'anneau le
              // détache franchement : il appartient à la barre, et il est devant.
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: couleurs.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      key: const Key('onglet-deposer'),
                      color: couleurs.primary,
                      shape: const CircleBorder(),
                      elevation: choisi ? 0 : 1,
                      shadowColor: Marque.indigo900.withValues(alpha: 0.25),
                      child: InkWell(
                        onTap: surAppui,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 58,
                          height: 58,
                          child: Icon(
                            Icons.photo_camera_rounded,
                            size: 27,
                            color: couleurs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: enAttente,
                    builder: (context, combien, _) =>
                        _PastilleDAttente(combien: combien),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Déposer',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  color: choisi ? couleurs.primary : couleurs.onSurfaceVariant,
                  fontWeight: choisi ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le nombre de pièces qui attendent encore, sur le bouton de dépôt.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ LA SEULE INFORMATION QUE L'APPLICATION DÉTIENT ET QUE LE SERVEUR IGNORE.
///
/// Une pièce photographiée hors réseau n'existe que sur ce téléphone. Rien ne
/// la signalait tant qu'on n'ouvrait pas l'onglet du dépôt : l'adhérent
/// consultait ses échéances sans savoir qu'une facture l'attendait à deux
/// écrans de là. Le compteur le dit depuis n'importe quel onglet.
///
/// ⚠️ ELLE RESTE DANS L'ANNEAU, et ne déborde pas au-dessus de la barre. Ce qui
/// déborde d'un parent ne reçoit pas les appuis — la leçon du 23 septembre sur
/// ce même bouton. Posée au coin haut-droit du disque, elle est lue sans rien
/// coûter à la cible du pouce.
///
/// ⚠️ FOND CLAIR ET CHIFFRE SOMBRE, et non l'inverse : la pastille se détache
/// du magenta du bouton, là où un rond magenta sur magenta disparaîtrait. Même
/// règle qu'ailleurs — jamais la couleur seule.
/// ─────────────────────────────────────────────────────────────────────────────
class _PastilleDAttente extends StatelessWidget {
  const _PastilleDAttente({required this.combien});

  final int combien;

  @override
  Widget build(BuildContext context) {
    if (combien == 0) return const SizedBox.shrink();
    final couleurs = Theme.of(context).colorScheme;
    return Semantics(
      label: combien == 1
          ? 'une pièce attend de partir'
          : '$combien pièces attendent de partir',
      child: Container(
        constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: couleurs.surface,
          shape: BoxShape.circle,
          border: Border.all(color: couleurs.primary, width: 1.5),
        ),
        child: Text(
          // ⚠️ Au-delà de neuf, « 9+ » : trois chiffres dans dix-neuf points
          // deviennent illisibles, et le nombre exact n'apprend plus rien —
          // à ce stade, ce qui compte est qu'il y en a beaucoup.
          combien > 9 ? '9+' : '$combien',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w800,
            color: couleurs.primary,
          ),
        ),
      ),
    );
  }
}
