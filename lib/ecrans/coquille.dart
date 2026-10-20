import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../marque.dart';
import '../domaine/depot.dart';
import '../domaine/file_d_attente.dart';
import '../domaine/fraicheur.dart';
import '../domaine/prise_de_vue.dart';
import '../domaine/rappels.dart';
import '../ports/memoire_des_dossiers.dart';
import '../ports/service_de_l_espace.dart';
import '../ports/service_de_session.dart';
import '../ports/service_des_fichiers.dart';
import '../ports/service_du_tableau_de_bord.dart';
import 'accueil.dart';
import 'echeances.dart';
import 'historique.dart';
import 'documents.dart';
import 'honoraires.dart';
import 'ma_dsf.dart';
import 'ma_paie.dart';
import 'mon_entreprise.dart';
import 'plus.dart';
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
    required this.espace,
    this.fichiers,
    this.memoire,
    this.rappels,
    this.version,
    this.demanderUnLien,
  });

  /// Les rappels d'échéances posés sur le téléphone (20 octobre 2026). `null` :
  /// aucun rappel, et pas de réglage dans « Mon espace ».
  final Rappels? rappels;

  /// La version de l'application, pour « Mon compte ».
  final String? version;

  /// Le lien de réinitialisation du mot de passe, pour « Mon compte ».
  final Future<bool> Function(String courriel)? demanderUnLien;

  /// Les derniers dossiers connus, pour déposer sans réseau (19 octobre 2026).
  final MemoireDesDossiers? memoire;

  /// Honoraires, DSF, paie et documents servis par une route (18 octobre 2026).
  final ServiceDeLEspace espace;

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

  /// LE dossier en cours, pour tous les écrans (20 octobre 2026).
  ///
  /// ⚠️ UN SEUL CHOIX, TENU ICI. Chaque écran choisissait le sien, et l'accueil, la
  /// DSF et la paie prenaient d'office le premier : un adhérent à deux entreprises
  /// lisait la paie de l'une sous l'en-tête de l'autre. Il se choisit désormais
  /// dans l'en-tête de l'accueil ou de « Mon espace », et vaut partout.
  ///
  /// ⚠️ Le premier de la liste par défaut, et seulement par défaut : c'est l'ordre
  /// du serveur, et presque tous les adhérents n'en ont qu'un.
  String? _choisi;

  /// Les noms d'entreprise appris en route, par NIU, pour le choix. ⚠️ Le serveur
  /// ne rend que les NIU des dossiers (`/transverse/moi`) ; le nom vient du mois
  /// de chaque dossier, la première fois qu'on le lit.
  final _noms = <String, String>{};

  /// Vrai quand le serveur n'a pas répondu et qu'aucune liste n'est connue.
  bool _injoignable = false;

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

  /// Le geste principal : l'onglet de dépôt, puis l'appareil photo, d'un seul appui.
  void _deposer([
    SourceDuDepot source = SourceDuDepot.appareil,
    String? demande,
  ]) {
    // Le dépôt est le geste principal : un retour un peu plus franc.
    HapticFeedback.mediumImpact();
    if (_onglet != 2) setState(() => _onglet = 2);
    // Après l'image : l'écran de dépôt doit être monté pour ouvrir l'appareil.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _depot.currentState?.photographier(
        depuisLaGalerie: source == SourceDuDepot.galerie,
        depuisUnFichier: source == SourceDuDepot.fichier,
        demande: demande,
      ),
    );
  }

  /// 19 octobre 2026 : une pièce que le cabinet demande arrive souvent déjà en PDF.
  /// On demande d'où elle vient avant d'ouvrir quoi que ce soit.
  ///
  /// [demande] : 20 octobre 2026, le numéro de la demande suit la pièce dans la
  /// file (voir `Depot.demande`).
  Future<void> _deposerAuChoix([String? demande]) async {
    final source = await choisirLaSourceDuDepot(context, widget.priseDeVue);
    if (source != null && mounted) _deposer(source, demande);
  }

  /// L'adhérent change d'entreprise : tous les écrans suivent.
  void _choisirLeDossier(String dossier) {
    if (dossier == _choisi) return;
    HapticFeedback.selectionClick();
    setState(() {
      _choisi = dossier;
      _honorairesDus = null;
    });
    _fraicheurDesHonoraires.oublier();
    _lireLesHonoraires();
  }

  Future<void> _lireLesDossiers() async {
    if (_injoignable && mounted) setState(() => _injoignable = false);
    List<String>? dossiers;
    try {
      dossiers = await widget.session.mesDossiers();
      await widget.memoire?.retenir(dossiers);
    } on Object {
      // ⚠️ 19 octobre 2026 : la panne se dit « pas de réseau », avec un bouton pour
      // réessayer ; les derniers dossiers connus permettent encore de déposer.
      dossiers = await widget.memoire?.lire();
      if (dossiers == null || dossiers.isEmpty) {
        if (mounted) setState(() => _injoignable = true);
        return;
      }
    }
    if (mounted) {
      setState(() {
        _dossiers = dossiers;
        final connus = dossiers!;
        if (_choisi == null || !connus.contains(_choisi)) {
          _choisi = connus.firstOrNull;
        }
      });
    }
    await _lireLesHonoraires();
  }

  /// L'historique des pièces, ouvert PAR-DESSUS la coquille : il a sa propre
  /// flèche de retour, qui ramène à l'accueil.
  void _ouvrirMesPieces(String dossier) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EcranHistorique(
        session: widget.session,
        dossier: dossier,
        quandSessionExpire: widget.quandDeconnecte,
        fichiers: widget.fichiers,
      ),
    ),
  );

  final _plus = GlobalKey<EtatDuPlus>();

  /// 18 octobre 2026 : l'accueil gardait ses chiffres de la connexion. Une CNPS
  /// réglée depuis les échéances y restait « en retard » ; il se relit au retour.
  final _tableauDeBord = GlobalKey<EtatDuTableauDeBord>();

  /// Ce que l'adhérent doit au cabinet, pour la carte de l'accueil. Relu au
  /// retour d'un écran : une période réglée doit faire disparaître la carte.
  int? _honorairesDus;

  /// ⚠️ 20 octobre 2026 : relus au retour sur l'accueil seulement si la dernière
  /// lecture a plus de cinq minutes. Voir `Fraicheur`.
  final _fraicheurDesHonoraires = Fraicheur();

  Future<void> _lireLesHonoraires({bool siPerime = false}) async {
    final dossier = _choisi;
    if (dossier == null) return;
    if (siPerime && !_fraicheurDesHonoraires.perimee) return;
    final lue = await widget.espace.mesHonoraires(dossier);
    final h = lue.valeur;
    if (!mounted || h == null || dossier != _choisi) return;
    setState(() => _honorairesDus = h.du);
    if (lue.copieDu == null) {
      _fraicheurDesHonoraires.marquer();
      await widget.rappels?.retenirLesHonoraires(dossier, h);
    }
  }

  void _ouvrirLesHonoraires(String dossier) => _ouvrir(
    () => EcranHonoraires(
      espace: widget.espace,
      dossier: dossier,
      quandSessionExpire: widget.quandDeconnecte,
      ouvrirDocument: _ouvrirDocument,
      apresLecture: (h) => widget.rappels?.retenirLesHonoraires(dossier, h),
    ),
  );

  void _ouvrirMonEntreprise(String dossier) => _ouvrir(
    () => EcranMonEntreprise(
      session: widget.session,
      dossier: dossier,
      quandSessionExpire: widget.quandDeconnecte,
    ),
  );

  /// « Régler la CNPS », depuis la paie : retour à la coquille, onglet Échéances.
  void _allerAuxEcheances() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _onglet = 1);
  }

  /// Un écran de l'espace, ouvert par-dessus la coquille ; « Plus » se relit au
  /// retour, pour qu'une période réglée ou une pièce versée perde sa pastille.
  ///
  /// ⚠️ 20 octobre 2026 : l'accueil aussi, sans attendre ses cinq minutes : une
  /// période réglée à l'instant doit quitter sa carte tout de suite.
  Future<void> _ouvrir(Widget Function() ecran) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ecran()));
    await _plus.currentState?.relire();
    await _lireLesHonoraires();
    await _tableauDeBord.currentState?.relire(forcer: true);
  }

  /// Un PDF servi par une route : note, reçu, facture, DSF déposée.
  void _ouvrirDocument(String chemin, String titre) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EcranVisionneuse(
            fichiers: DocumentsDeLEspace(widget.espace),
            piece: chemin,
            titre: titre,
            quandSessionExpire: widget.quandDeconnecte,
          ),
        ),
      );

  /// Le document d'une pièce, ouvert par-dessus la coquille.
  void _ouvrirPiece(String piece) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EcranVisionneuse(
        fichiers: widget.fichiers!,
        piece: piece,
        // 19 octobre 2026 : le titre était l'identifiant technique de la pièce.
        titre: 'Pièce envoyée',
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
    final choisi = _choisi;
    // ⚠️ 19 octobre 2026 : le retour d'Android fermait l'application depuis n'importe
    // quel onglet. Il ramène d'abord à l'accueil ; de l'accueil, il quitte.
    return PopScope(
      canPop: _onglet == 0,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte) setState(() => _onglet = 0);
      },
      child: Scaffold(
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
                if (dossiers == null && _injoignable)
                  _Injoignable(titre: 'Accueil', reessayer: _lireLesDossiers)
                else if (dossiers == null)
                  const _EnAttenteDeDossier(titre: 'Accueil')
                else if (choisi == null)
                  const _SansDossier(titre: 'Accueil')
                else
                  EcranTableauDeBord(
                    key: _tableauDeBord,
                    session: widget.session,
                    tableau: widget.tableau,
                    dossier: choisi,
                    dossiers: dossiers,
                    noms: _noms,
                    choisirLeDossier: _choisirLeDossier,
                    quandNomConnu: (d, nom) {
                      if (_noms[d] != nom) setState(() => _noms[d] = nom);
                    },
                    apresLecture: (e) =>
                        widget.rappels?.retenirLesEcheances(choisi, e),
                    deposerPourLaDemande: _deposerAuChoix,
                    quandSessionExpire: widget.quandDeconnecte,
                    // « Déposer une pièce » depuis l'accueil ouvre l'appareil photo.
                    allerALOnglet: (i) => i == EcranTableauDeBord.ongletDeposer
                        ? _deposer()
                        : setState(() => _onglet = i),
                    deposerAuChoix: _deposerAuChoix,
                    ouvrirMesPieces: () => _ouvrirMesPieces(choisi),
                    ouvrirPiece: widget.fichiers == null ? null : _ouvrirPiece,
                    honorairesDus: _honorairesDus,
                    ouvrirHonoraires: () => _ouvrirLesHonoraires(choisi),
                    ouvrirMonEntreprise: () => _ouvrirMonEntreprise(choisi),
                    seDeconnecter: () async {
                      await widget.session.fermerLaSession();
                      widget.quandDeconnecte();
                    },
                  ),
                // ── 1. Échéances ───────────────────────────────────────────────
                if (dossiers == null && _injoignable)
                  _Injoignable(
                    titre: 'Mes échéances',
                    reessayer: _lireLesDossiers,
                  )
                else if (dossiers == null)
                  const _EnAttenteDeDossier(titre: 'Mes échéances')
                else if (choisi == null)
                  const _SansDossier(titre: 'Mes échéances')
                else
                  EcranEcheances(
                    session: widget.session,
                    dossier: choisi,
                    quandSessionExpire: widget.quandDeconnecte,
                    priseDeVue: widget.priseDeVue,
                    espace: widget.espace,
                    apresLecture: (e) =>
                        widget.rappels?.retenirLesEcheances(choisi, e),
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
                  // ⚠️ 20 octobre 2026 : le dossier CHOISI, seul. L'écran demandait
                  // « Pour quelle entreprise ? » à chaque photo ; le choix de
                  // l'en-tête vaut ici comme ailleurs.
                  dossiers: choisi == null ? const [] : [choisi],
                  // ⚠️ Tant que les dossiers ne sont pas lus, pas de porte : elle
                  // ouvrirait sur un écran qui ne saurait pas quoi demander.
                  ouvrirLHistorique: choisi == null
                      ? null
                      : () => _ouvrirMesPieces(choisi),
                  compteurEnAttente: _enAttente,
                ),
                // ── 3. Documents ───────────────────────────────────────────────
                if (dossiers == null && _injoignable)
                  _Injoignable(
                    titre: 'Mes documents',
                    reessayer: _lireLesDossiers,
                  )
                else if (dossiers == null)
                  const _EnAttenteDeDossier(titre: 'Mes documents')
                else if (choisi == null)
                  const _SansDossier(titre: 'Mes documents')
                else
                  EcranDocuments(
                    session: widget.session,
                    dossier: choisi,
                    quandSessionExpire: widget.quandDeconnecte,
                    // ⚠️ « Documents » est l'onglet où l'on cherche un document,
                    // quel qu'en soit le sens. Les accusés déposés PAR le cabinet
                    // y étaient seuls ; les pièces remises AU cabinet vivaient
                    // sur un écran auquel rien ne menait depuis ici.
                    ouvrirLHistorique: () => _ouvrirMesPieces(choisi),
                    // 18 octobre 2026 : chaque accusé a son reçu PDF, qui s'ouvre ici.
                    ouvrirLeRecu: (dossier, numero) => _ouvrirDocument(
                      '/obligations/dossiers/${Uri.encodeComponent(dossier)}'
                          '/mes-documents/${Uri.encodeComponent(numero)}/recu',
                      'Reçu de dépôt',
                    ),
                  ),
                // ── 4. Plus ────────────────────────────────────────────────────
                // 18 octobre 2026 : honoraires, DSF, paie, entreprise et pièces
                // envoyées, à un toucher. « Entreprise » y descend : on la consulte
                // rarement, et la barre ne tient pas un sixième onglet.
                if (dossiers == null && _injoignable)
                  _Injoignable(titre: 'Mon espace', reessayer: _lireLesDossiers)
                else if (dossiers == null)
                  const _EnAttenteDeDossier(titre: 'Mon espace')
                else if (choisi == null)
                  const _SansDossier(titre: 'Mon espace')
                else
                  EcranPlus(
                    key: _plus,
                    espace: widget.espace,
                    dossier: choisi,
                    dossiers: dossiers,
                    noms: _noms,
                    choisirLeDossier: _choisirLeDossier,
                    rappels: widget.rappels,
                    version: widget.version,
                    demanderUnLien: widget.demanderUnLien,
                    ouvrirHonoraires: () => _ouvrirLesHonoraires(choisi),
                    ouvrirMaDsf: () => _ouvrir(
                      () => EcranMaDsf(
                        espace: widget.espace,
                        dossier: choisi,
                        priseDeVue: widget.priseDeVue,
                        quandSessionExpire: widget.quandDeconnecte,
                        ouvrirDocument: _ouvrirDocument,
                      ),
                    ),
                    ouvrirMaPaie: () => _ouvrir(
                      () => EcranMaPaie(
                        espace: widget.espace,
                        dossier: choisi,
                        quandSessionExpire: widget.quandDeconnecte,
                        ouvrirDocument: _ouvrirDocument,
                        reglerLaCnps: _allerAuxEcheances,
                      ),
                    ),
                    ouvrirMonEntreprise: () => _ouvrirMonEntreprise(choisi),
                    ouvrirMesPieces: () => _ouvrirMesPieces(choisi),
                    seDeconnecter: () async {
                      await widget.session.fermerLaSession();
                      widget.quandDeconnecte();
                    },
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
            // ⚠️ 20 octobre 2026 : seulement si la dernière lecture a plus de
            // cinq minutes. Voir `Fraicheur`.
            if (i == 4) _plus.currentState?.relire(siPerime: true);
            if (i == 0) {
              _tableauDeBord.currentState?.relire();
              _lireLesHonoraires(siPerime: true);
            }
          },
          surDeposer: _deposer,
        ),
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
/// Le serveur n'a pas répondu, et aucune liste de dossiers n'est connue.
class _Injoignable extends StatelessWidget {
  const _Injoignable({required this.titre, required this.reessayer});

  final String titre;
  final Future<void> Function() reessayer;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: RefreshIndicator(
        onRefresh: reessayer,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(32, 90, 32, 32),
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 44,
              color: couleurs.onSurfaceVariant,
            ),
            const SizedBox(height: 18),
            Text(
              'Pas de réseau',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: couleurs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Le cabinet ne répond pas pour l\'instant. Vérifiez votre connexion, '
              'puis réessayez.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: couleurs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: FilledButton.icon(
                key: const Key('reessayer-dossiers'),
                onPressed: reessayer,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                  // 19 octobre 2026 : un seul geste, d'où qu'on vienne. Le bouton ne
                  // faisait que changer d'onglet ; il fallait appuyer une seconde fois
                  // pour ouvrir l'appareil photo.
                  surAppui: surDeposer,
                ),
                _Onglet(
                  cle: 'onglet-documents',
                  icone: Icons.description_outlined,
                  iconeChoisie: Icons.description,
                  libelle: 'Documents',
                  choisi: onglet == 3,
                  surAppui: () => surChoix(3),
                ),
                // 18 octobre 2026 : « Plus » remplace « Entreprise », qui y
                // descend avec les honoraires, la DSF et la paie.
                //
                // ⚠️ 20 octobre 2026 : l'onglet dit ce qu'il ouvre, « Espace » (l'écran
                // s'intitule « Mon espace »). « Plus » ne disait rien ; « Mon espace »
                // en entier se coupait en « Mon espa… » sur un écran de 360 points.
                _Onglet(
                  cle: 'onglet-plus',
                  icone: Icons.grid_view_outlined,
                  iconeChoisie: Icons.grid_view_rounded,
                  libelle: 'Espace',
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
