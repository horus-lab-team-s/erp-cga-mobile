// Le banc complet du guide d'utilisation : tous les écrans de l'application, sans
// téléphone (12 novembre 2026).
//
// Il pose la vraie coquille (barre du bas comprise) sur un dossier de démonstration
// fictif, touche les boutons comme l'adhérent, et écrit un PNG par écran du guide.
// Il ne vérifie rien : il montre. Comme les autres bancs, il ne tourne que sur demande :
//
//     APERCUS=/chemin/du/dossier FACTURE=/chemin/facture.jpg RECU=/chemin/recu.png \
//       flutter test test/apercus/guide_complet_test.dart
//
// FACTURE est la facture FICTIVE du guide ; RECU, l'image d'un reçu de dépôt fictif
// (le lecteur de PDF ne tourne pas sous Linux : le reçu est servi en image).
// SOMBRE=1 rend les mêmes écrans en thème sombre.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:cga_mobile/adaptateurs/magasin_memoire.dart';
import 'package:cga_mobile/domaine/depot.dart';
import 'package:cga_mobile/domaine/document_recu.dart';
import 'package:cga_mobile/domaine/echeance.dart';
import 'package:cga_mobile/domaine/file_d_attente.dart';
import 'package:cga_mobile/domaine/fonds_confies.dart';
import 'package:cga_mobile/domaine/honoraires.dart';
import 'package:cga_mobile/domaine/ma_dsf.dart';
import 'package:cga_mobile/domaine/ma_paie.dart';
import 'package:cga_mobile/domaine/mon_entreprise.dart';
import 'package:cga_mobile/domaine/mon_mois.dart';
import 'package:cga_mobile/domaine/piece_remise.dart';
import 'package:cga_mobile/domaine/preuve.dart';
import 'package:cga_mobile/domaine/prise_de_vue.dart';
import 'package:cga_mobile/domaine/rappels.dart';
import 'package:cga_mobile/domaine/vitrine.dart';
import 'package:cga_mobile/ecrans/connexion.dart';
import 'package:cga_mobile/ecrans/coquille.dart';
import 'package:cga_mobile/ecrans/offre.dart';
import 'package:cga_mobile/marque.dart';
import 'package:cga_mobile/ports/appareil_photo.dart';
import 'package:cga_mobile/ports/service_de_session.dart';
import 'package:cga_mobile/ports/service_des_fichiers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../soutien/espace_feint.dart';
import '../soutien/public_feint.dart';
import '../soutien/tableau_feint.dart';

final _sortie = Platform.environment['APERCUS'];
final _facture = Platform.environment['FACTURE'];
final _recu = Platform.environment['RECU'];
const _dossier = 'M081234567890P';

class _SansPhoto implements AppareilPhoto {
  @override
  Future<String?> photographier() async => null;
}

class _SansRappels implements PlanificateurDeRappels {
  @override
  Future<bool> demanderLaPermission() async => true;
  @override
  Future<void> programmer(List<Rappel> rappels) async {}
}

class _Fichiers implements ServiceDesFichiers {
  @override
  Future<FichierLu> lireLeFichier(String chemin) async => FichierLu(
    octets: File(_recu ?? _facture!).readAsBytesSync(),
    type: 'image/png',
  );
}

/// L'espace de démonstration : il sert aussi le reçu de dépôt en image.
class _Espace extends EspaceFeint {
  _Espace({super.honoraires, super.dsf, super.paie, super.fonds});

  @override
  Future<FichierLu> lireUnDocument(String chemin) async => FichierLu(
    octets: Uint8List.fromList(File(_recu!).readAsBytesSync()),
    type: 'image/png',
  );
}

Future<void> _chargerLesPolices() async {
  Future<void> famille(String nom, List<String> fichiers) async {
    final chargeur = FontLoader(nom);
    for (final f in fichiers) {
      chargeur.addFont(rootBundle.load('assets/polices/$f'));
    }
    await chargeur.load();
  }

  await famille('Inter', [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]);
  await famille('Poppins', [
    'Poppins-Regular.ttf',
    'Poppins-Medium.ttf',
    'Poppins-SemiBold.ttf',
    'Poppins-Bold.ttf',
  ]);
  final racine =
      Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/flutter';
  final icones = File(
    '$racine/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icones.existsSync()) {
    final chargeur = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icones.readAsBytesSync())));
    await chargeur.load();
  }
}

ThemeData _theme() {
  final theme = (Platform.environment['SOMBRE'] == '1'
      ? themeSombre()
      : themeClair());
  return theme.copyWith(
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: theme.chipTheme.labelStyle?.copyWith(
        fontFamily: Marque.policeTexte,
      ),
    ),
  );
}

final _cle = GlobalKey();

/// Laisse les lectures feintes aboutir et les images se décoder.
Future<void> _laisser(WidgetTester t, {int tours = 6}) async {
  for (var i = 0; i < tours; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await t.pump(const Duration(milliseconds: 120));
  }
  await t.pump(const Duration(seconds: 1));
}

Future<void> _poser(WidgetTester t, Widget ecran) async {
  t.view.physicalSize = const Size(390 * 2, 844 * 2);
  t.view.devicePixelRatio = 2;
  await t.pumpWidget(
    RepaintBoundary(
      key: _cle,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ecran,
      ),
    ),
  );
  await _laisser(t);
}

Future<void> _photo(WidgetTester t, String nom) async {
  await _laisser(t, tours: 3);
  await t.runAsync(() async {
    final limite =
        _cle.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await limite.toImage(pixelRatio: 2);
    final octets = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_sortie/$nom.png').writeAsBytesSync(octets!.buffer.asUint8List());
  });
}

Future<void> _toucher(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.first);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f.first, warnIfMissed: false);
  await _laisser(t);
}

/// Fait défiler la liste visible de [dy] points (positif : vers le bas).
Future<void> _defiler(WidgetTester t, double dy) async {
  final liste = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  await t.drag(liste.hitTestable().first, Offset(0, -dy));
  await _laisser(t, tours: 2);
}

// ─── Le dossier de démonstration (tout est fictif) ───────────────────────────

Echeance _echeance(
  String code,
  String titre,
  String etat, {
  String periode = 'septembre 2026',
  String debut = '2026-09-01',
  String fin = '2026-09-30',
  String echeance = '2026-10-15',
  int jours = 28,
  int autres = 0,
  String? deQuoi,
}) => Echeance.depuisJson({
  'code_obligation': code,
  'titre': titre,
  'periode': periode,
  'periode_debut': debut,
  'periode_fin': fin,
  'echeance': echeance,
  'etat': etat,
  'jours': jours,
  'autres_periodes_en_retard': autres,
  'de_quoi_s_agit_il': deQuoi,
});

DocumentRecu _document(
  String numero,
  String titre,
  String periode,
  String guichet,
  String deposeLe,
  String montant,
) => DocumentRecu.depuisJson({
  'numero': numero,
  'titre': titre,
  'periode': periode,
  'depose_le': deposeLe,
  'guichet': guichet,
  'montant_constate': montant,
  'verifiable': true,
});

PieceRemise _piece(
  String id,
  String le,
  String etat, {
  String canal = 'MOBILE',
  String? emetteur,
  num? montant,
  String? reference,
}) => PieceRemise.depuisJson({
  'identifiant': id,
  'depose_le': le,
  'etat': etat,
  'canal': canal,
  'emetteur': emetteur,
  'montant_ttc': montant,
  'reference_document': reference,
});

MonEntreprise _entreprise() => MonEntreprise.depuisJson({
  'niu': _dossier,
  'denomination': 'SARL BATIMENT PLUS',
  'forme': 'Société à responsabilité limitée',
  'activite': 'Construction de bâtiments résidentiels et non résidentiels',
  'rccm': 'RC/DLA/2021/B/0977',
  'siege': 'Bonabéri, Douala IV',
  'centre': 'Centre divisionnaire des impôts de Douala IV',
  'regime': {
    'code': 'REEL',
    'titre': 'Régime du réel',
    'explication':
        'Vous tenez une comptabilité complète ; le cabinet déclare chaque mois pour vous.',
    'depuis': '2022-06-01',
  },
  'assujettie_tva': true,
  'adhesion_numero': 'ADH-2022-014',
  'adherente_depuis': '2022-06-01',
  'dirigeants': [
    {'nom': 'NKOA Jean-Pierre', 'qualite': 'Gérant'},
  ],
  'interlocuteur': {
    'nom': 'Patricia MOUKOURI',
    'role': 'CHARGE_CLIENTELE',
    'courriel': 'p.moukouri@cga-brcgroup.com',
    'telephone': '699000000',
  },
  'natures': [
    {
      'nature': 'ADRESSE',
      'libelle': 'Adresse',
      'aide':
          'Une nouvelle adresse peut changer votre centre des impôts, donc vos dates limites : le cabinet vérifie.',
    },
    {
      'nature': 'DIRIGEANT',
      'libelle': 'Gérant ou dirigeant',
      'aide': 'Le cabinet vous demandera le procès-verbal de nomination.',
    },
    {
      'nature': 'ACTIVITE',
      'libelle': 'Activité',
      'aide':
          'Une nouvelle activité peut changer vos impôts : le cabinet vous rappelle avant toute démarche.',
    },
    {
      'nature': 'TELEPHONE',
      'libelle': 'Numéro de téléphone',
      'aide':
          'Écrivez le nouveau numéro : le cabinet met votre dossier à jour.',
    },
    {
      'nature': 'AUTRE',
      'libelle': 'Autre changement',
      'aide': 'Décrivez le changement : le cabinet vous contacte.',
    },
  ],
  'signalements': [],
});

class _Session implements ServiceDeSession {
  @override
  Future<bool> ouvrirUneSession(String c, String m) async => true;
  @override
  Future<void> fermerLaSession() async {}
  @override
  Future<List<String>> mesDossiers() async => const [_dossier];

  @override
  Future<Historique> mesPieces(String dossier) async => Historique(
    pieces: [
      _piece('PJ-9', '2026-11-10T09:42:00', 'RECUE'),
      _piece(
        'PJ-8',
        '2026-11-06T15:10:00',
        'LUE',
        emetteur: 'QUINCAILLERIE DU WOURI',
        montant: 184838,
        reference: 'FA-2026-0815',
      ),
      _piece(
        'PJ-7',
        '2026-10-28T11:00:00',
        'RAPPROCHEE',
        canal: 'COURRIEL',
        emetteur: 'SÉCURITÉ CHANTIER PLUS',
        montant: 906300,
        reference: 'F-2026-0435',
      ),
      _piece(
        'PJ-6',
        '2026-10-18T10:20:00',
        'COMPTABILISEE',
        emetteur: 'MENUISERIE BAFOUSSAM',
        montant: 1958085,
        reference: 'F-2026-0430',
      ),
      _piece(
        'PJ-5',
        '2026-10-09T08:30:00',
        'ARCHIVEE',
        canal: 'PORTAIL',
        emetteur: 'TRANSPORT SAWA EXPRESS',
        montant: 1431000,
        reference: 'F-2026-0412',
      ),
    ],
  );

  @override
  Future<Echeancier> mesEcheances(String dossier) async => Echeancier(
    echeances: [
      _echeance(
        'CNPS',
        'Cotisations sociales CNPS',
        'EN_RETARD',
        deQuoi:
            'Les cotisations sociales de vos salariés, versées chaque mois à la CNPS.',
      ),
      _echeance(
        'TVA',
        'TVA du mois',
        'EN_RETARD',
        autres: 1,
        deQuoi:
            'La TVA que vous avez facturée à vos clients, moins celle que vous avez payée.',
      ),
      _echeance(
        'ACOMPTE_IR',
        'Acompte d\'impôt sur le revenu',
        'A_VENIR',
        periode: 'octobre 2026',
        debut: '2026-10-01',
        fin: '2026-10-31',
        echeance: '2026-11-15',
        jours: 3,
      ),
    ],
  );

  @override
  Future<Preuve> envoyerLaPreuve({
    required String dossier,
    required Echeance echeance,
    required String cheminDeLaPhoto,
  }) async => Preuve.recue;

  @override
  Future<Fiche> monEntreprise(String dossier) async =>
      Fiche(entreprise: _entreprise());

  @override
  Future<SortDuSignalement> signalerUnChangement({
    required String dossier,
    required String nature,
    required String message,
  }) async => SortDuSignalement.transmis;

  @override
  Future<Documents> mesDocuments(String dossier) async => Documents(
    documents: [
      _document(
        'CNPS-2026-09-118941',
        'Cotisations sociales CNPS',
        'septembre 2026',
        'CNPS',
        '2026-10-13T09:00:00',
        '412500',
      ),
      _document(
        'DGI-2026-09-268557',
        'Acompte d\'impôt sur le revenu',
        'septembre 2026',
        'Impôts (DGI)',
        '2026-10-13T08:40:00',
        '185000',
      ),
      _document(
        'DGI-2026-08-619373',
        'TVA du mois',
        'août 2026',
        'Impôts (DGI)',
        '2026-09-14T10:15:00',
        '1340000',
      ),
    ],
  );
}

MonMois _mois() => MonMois.depuisJson({
  'denomination': 'SARL BATIMENT PLUS',
  'nom_du_mois': 'octobre 2026',
  'justificatifs_du_mois': 1,
  'bandeau': {
    'etat': 'A_ENVOYER',
    'titre': 'Il manque 3 justificatifs',
    'detail':
        'La date prévue est passée : envoyez-les dès que possible, le cabinet vous attend.',
  },
  'attendues': [
    {
      'demande': 'DP-2026-021',
      'libelle':
          'Facture rectificative F-2026-0430, MENUISERIE BAFOUSSAM : le détail des lignes dépasse le total hors taxes de 12 400 F',
      'attendue_pour': '2026-11-05',
      'en_retard': true,
      'bloquante': false,
      'a_corriger': true,
      'piece_a_rectifier': 'PJ-6',
      'reponse': null,
    },
    {
      'demande': 'DP-2026-022',
      'libelle': 'Relevé bancaire d\'octobre 2026',
      'attendue_pour': '2026-11-05',
      'en_retard': true,
      'bloquante': true,
      'a_corriger': false,
      'reponse': null,
    },
    {
      'demande': 'DP-2026-023',
      'libelle': 'Relevé mobile money d\'octobre 2026',
      'attendue_pour': '2026-11-05',
      'en_retard': true,
      'bloquante': false,
      'a_corriger': false,
      'reponse': 'Je l\'aurai la semaine prochaine',
      'reponse_le': '2026-11-09T10:00:00',
    },
  ],
});

/// Les honoraires : août réglée, septembre et octobre dues, novembre à venir.
MesHonoraires _honoraires({String acces = 'OUVERT', String? suspenduLe}) =>
    MesHonoraires.depuis({
      'contrat': {'montant': '45000', 'periodicite': 'MENSUELLE'},
      'echeances': [
        {
          'debut': '2026-08-01',
          'fin': '2026-08-31',
          'exigible_le': '2026-08-13',
          'montant': '45000',
          'etat': acces == 'OUVERT' ? 'REGLEE' : 'EN_RETARD',
          if (acces == 'OUVERT')
            'reglement': {
              'identifiant': 'RH-1',
              'constate_le': '2026-08-13T10:00:00',
              'canal': 'GUICHET',
              'reference_externe': 'Reçu de caisse 2026-0105',
            },
        },
        {
          'debut': '2026-09-01',
          'fin': '2026-09-30',
          'exigible_le': '2026-09-13',
          'montant': '45000',
          'etat': 'EN_RETARD',
        },
        {
          'debut': '2026-10-01',
          'fin': '2026-10-31',
          'exigible_le': '2026-10-13',
          'montant': '45000',
          'etat': 'EN_RETARD',
        },
        {
          'debut': '2026-11-01',
          'fin': '2026-11-30',
          'exigible_le': '2026-11-13',
          'montant': '45000',
          'etat': 'A_VENIR',
        },
      ],
      'du': acces == 'OUVERT' ? '90000' : '135000',
      'en_retard': acces == 'OUVERT' ? 2 : 3,
      'reglable_en_ligne': true,
      'situation': {
        'etat': 'EN_RETARD',
        'acces_client': acces,
        'acces_suspendu_le': suspenduLe,
      },
      'facture_disponible': true,
    });

MaDsf _dsf({bool deposee = false}) => MaDsf.depuis({
  'exercices': [
    if (!deposee)
      {
        'exercice': '2025',
        'cloture': '2025-12-31',
        'etat': 'EN_PREPARATION',
        'a_fournir': 2,
        'document': false,
        'pieces': [
          {
            'numero': 1,
            'libelle': 'Attestation de visa',
            'etat': 'JOINTE',
            'nom_du_fichier': 'visa.pdf',
            'versable': true,
          },
          {
            'numero': 4,
            'libelle': 'Déclaration des dépenses fiscales',
            'etat': 'A_FOURNIR',
            'versable': true,
          },
          {
            'numero': 6,
            'libelle': 'DIPE (personnel employé)',
            'etat': 'A_FOURNIR',
            'versable': true,
          },
        ],
      },
    if (deposee)
      {
        'exercice': '2025',
        'cloture': '2025-12-31',
        'etat': 'DEPOSEE',
        'a_fournir': 0,
        'document': true,
        'numero_accuse': 'DGI-2026-DSF-563648',
        'deposee_le': '2026-05-13T10:00:00',
        'pieces': [],
      },
    {
      'exercice': '2024',
      'cloture': '2024-12-31',
      'etat': 'DEPOSEE',
      'a_fournir': 0,
      'document': true,
      'numero_accuse': 'DGI-2025-DSF-0412',
      'deposee_le': '2025-03-10T10:00:00',
      'pieces': [],
    },
  ],
});

MaPaie _paie() => MaPaie.depuis(
  annee: 2026,
  mois: 10,
  personnel: [
    {'matricule': 'S-1', 'nom': 'NKOULOU', 'prenom': 'Alphonse'},
    {'matricule': 'S-2', 'nom': 'TSANGA', 'prenom': 'Marie'},
  ],
  declaration: {
    'effectif': 2,
    'masse_salariale_brute': '645000',
    'total_a_verser': '191962',
    'cotisations_cnps': '110618',
    'a_deposer_avant': '2026-11-15',
    'en_retard': false,
    'bulletins': [
      {
        'salarie': 'S-1',
        'brut_taxable': '495000',
        'net_a_payer': '374715',
        'cout_employeur': '560000',
      },
      {
        'salarie': 'S-2',
        'brut_taxable': '150000',
        'net_a_payer': '132976',
        'cout_employeur': '170000',
      },
    ],
  },
);

FondsConfies _fonds({bool arrete = false}) => FondsConfies.depuis({
  'obligations_mandatees': ['CNPS'],
  'appels': [
    if (arrete)
      {
        'identifiant': 'AF-1',
        'code_obligation': 'CNPS',
        'libelle': 'Cotisations sociales CNPS',
        'periode_debut': '2026-09-01',
        'montant': '110618',
        'etat': 'A_REGLER',
      },
  ],
});

Future<FileDAttente> _file({int enAttente = 0}) async {
  final file = FileDAttente(MagasinEnMemoire());
  for (var i = 0; i < enAttente; i++) {
    await file.ajouter(
      Depot(
        identifiant: 'D$i',
        dossier: _dossier,
        cheminDuFichier: _facture!,
        prisLe: DateTime(2026, 11, 12, 9, 42 + 3 * i),
      ),
    );
  }
  return file;
}

Future<void> _coquille(
  WidgetTester t, {
  MesHonoraires? honoraires,
  bool fondsArretes = false,
  bool dsfDeposee = false,
  int enAttente = 0,
}) async {
  late FileDAttente file;
  await t.runAsync(() async => file = await _file(enAttente: enAttente));
  final prise = PriseDeVue(
    appareil: _SansPhoto(),
    galerie: _SansPhoto(),
    fichiers: _SansPhoto(),
    file: file,
    photos: Directory.systemTemp,
  );
  await _poser(
    t,
    Coquille(
      session: _Session(),
      file: file,
      priseDeVue: prise,
      remettre: (_) async => Reponse.indisponible,
      quandDeconnecte: () {},
      tableau: TableauFeint(nom: 'Jean-Pierre NKOA', mois: _mois()),
      espace: _Espace(
        honoraires: honoraires ?? _honoraires(),
        dsf: _dsf(deposee: dsfDeposee),
        paie: _paie(),
        fonds: _fonds(arrete: fondsArretes),
      ),
      fichiers: _Fichiers(),
      rappels: Rappels(planificateur: _SansRappels()),
      version: '1.0.1 (2)',
      demanderUnLien: (_) async => true,
    ),
  );
}

Future<void> _onglet(WidgetTester t, String cle) =>
    _toucher(t, find.byKey(Key(cle)));

Future<void> _vider(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(minutes: 5));
}

void main() {
  setUpAll(() async {
    final sortie = _sortie;
    if (sortie != null) {
      Directory(sortie).createSync(recursive: true);
      await _chargerLesPolices();
    }
  });

  final passer = _sortie == null || _facture == null || _recu == null
      ? 'APERCUS, FACTURE ou RECU non défini : banc du guide non joué'
      : null;

  testWidgets('Vitrine, connexion, mot de passe oublié', skip: passer != null, (
    t,
  ) async {
    await _poser(
      t,
      EcranOffre(
        servicePublic: PublicFeint(
          annonce: Annonce.depuisJson({
            'etiquette': 'Offre',
            'texte':
                'Votre SARL immatriculée, statuts et attestations compris, pour 275 000 FCFA, sans notaire et sans file d\'attente.',
            'lien': '/creer-mon-entreprise',
            'libelle_lien': 'Voir l\'offre',
          }),
        ),
        quandSeConnecter: () {},
        quandSouscrire: (_) {},
      ),
    );
    // ⚠️ Le bouton « Se connecter » n'a pas de famille de police : le banc le
    // dessine en rectangles. La capture du guide vient du téléphone.
    await _photo(t, 'vitrine');
    await _vider(t);

    await _poser(
      t,
      EcranDeConnexion(
        session: _Session(),
        quandConnecte: () {},
        quandRetour: () {},
        demanderUnLien: (_) async => true,
      ),
    );
    await _photo(t, 'connexion');
    await _toucher(t, find.text('Mot de passe oublié ?'));
    await _photo(t, 'mot-de-passe-oublie');
    await _vider(t);
  });

  testWidgets('Accueil', skip: passer != null, (t) async {
    await _coquille(t);
    await _photo(t, 'accueil-haut');
    await _defiler(t, 560);
    await _photo(t, 'accueil-demandes');
    await _defiler(t, 520);
    await _photo(t, 'accueil-piece-demandee');
    await _defiler(t, 2000);
    await _photo(t, 'accueil-bas');
    await _vider(t);
  });

  testWidgets('Déposer : les trois choix', skip: passer != null, (t) async {
    await _coquille(t);
    await _toucher(t, find.byKey(const Key('grande-action-deposer')));
    await _photo(t, 'feuille-trois-choix');
    await _vider(t);
  });

  testWidgets(
    'Mes justificatifs, deux pièces en attente',
    skip: passer != null,
    (t) async {
      await _coquille(t, enAttente: 2);
      // L'onglet du milieu, sans déclencher l'appareil photo : on passe par
      // l'état de la coquille comme le ferait un retour d'appareil vide.
      await _toucher(t, find.byKey(const Key('onglet-deposer')));
      await _photo(t, 'justificatifs-en-attente');
      await _vider(t);
    },
  );

  testWidgets('Espace, mon compte, déconnexion', skip: passer != null, (
    t,
  ) async {
    await _coquille(t);
    await _onglet(t, 'onglet-plus');
    await _photo(t, 'plus');
    await _defiler(t, 2000);
    await _photo(t, 'mon-compte');
    await _toucher(t, find.text('Se déconnecter'));
    await _photo(t, 'deconnexion');
    await _vider(t);
  });

  testWidgets('Mes pièces envoyées', skip: passer != null, (t) async {
    await _coquille(t);
    await _onglet(t, 'onglet-plus');
    await _toucher(t, find.text('Mes pièces envoyées'));
    await _photo(t, 'pieces-envoyees');
    await _vider(t);
  });

  testWidgets('Échéances', skip: passer != null, (t) async {
    await _coquille(t);
    await _onglet(t, 'onglet-echeances');
    await _photo(t, 'echeances');
    await _toucher(t, find.byKey(const Key('voies-CNPS')));
    await _photo(t, 'echeances-comment-regler');
    await _vider(t);

    await _coquille(t, fondsArretes: true);
    await _onglet(t, 'onglet-echeances');
    await _photo(t, 'echeances-mobile-money');
    await _toucher(t, find.byKey(const Key('regler-CNPS')));
    await _photo(t, 'paiement-mobile-money');
    await _vider(t);
  });

  testWidgets('Documents et reçu', skip: passer != null, (t) async {
    await _coquille(t);
    await _onglet(t, 'onglet-documents');
    await _photo(t, 'documents-carte');
    await _toucher(t, find.text('Voir le reçu'));
    await _photo(t, 'document-recu');
    await _vider(t);
  });

  testWidgets('Honoraires : ouvert, préavis, suspendu', skip: passer != null, (
    t,
  ) async {
    await _coquille(t);
    await _onglet(t, 'onglet-plus');
    await _toucher(t, find.text('Mes honoraires'));
    await _photo(t, 'honoraires');
    await _vider(t);

    await _coquille(
      t,
      honoraires: _honoraires(acces: 'AVERTI', suspenduLe: '2026-11-13'),
    );
    await _onglet(t, 'onglet-plus');
    await _toucher(t, find.text('Mes honoraires'));
    await _photo(t, 'honoraires-preavis');
    await _vider(t);

    await _coquille(
      t,
      honoraires: _honoraires(acces: 'SUSPENDU', suspenduLe: '2026-11-13'),
    );
    await _onglet(t, 'onglet-plus');
    await _toucher(t, find.text('Mes honoraires'));
    await _photo(t, 'honoraires-suspendu');
    await _vider(t);
  });

  testWidgets('DSF', skip: passer != null, (t) async {
    await _coquille(t);
    await _onglet(t, 'onglet-plus');
    await _toucher(t, find.text('Ma déclaration annuelle (DSF)'));
    await _photo(t, 'dsf-a-fournir');
    await _vider(t);

    await _coquille(t, dsfDeposee: true);
    await _onglet(t, 'onglet-plus');
    await _toucher(t, find.text('Ma déclaration annuelle (DSF)'));
    await _photo(t, 'dsf');
    await _vider(t);
  });

  testWidgets('Paie', skip: passer != null, (t) async {
    await _coquille(t);
    await _onglet(t, 'onglet-plus');
    await _toucher(t, find.text('Ma paie'));
    await _photo(t, 'paie');
    await _vider(t);
  });

  testWidgets('Mon entreprise', skip: passer != null, (t) async {
    await _coquille(t);
    await _onglet(t, 'onglet-plus');
    await _toucher(t, find.text('Mon entreprise').last);
    await _defiler(t, 420);
    await _photo(t, 'entreprise-interlocuteur');
    await _toucher(t, find.text('Signaler un changement'));
    await _photo(t, 'entreprise-signaler');
    await _vider(t);
  });
}
