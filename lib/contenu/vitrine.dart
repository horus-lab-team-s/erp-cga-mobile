/// Les textes STABLES de la vitrine, repris dans l'application.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ RECOPIÉS MOT POUR MOT. La source est
/// `erp-cga-vitrine/messages/fr/vitrine.json`, clés `heros.slide1`, `chiffres`,
/// `cga`, `etapes`, `services.juridique`, `services.conseil`, `blog`,
/// `partenaires`, `cta`.
///
/// Pourquoi recopier plutôt que lire au serveur : ces textes vivent dans les
/// fichiers de traduction du site, que le serveur ne sert pas. Ils changent
/// rarement. Ce qui change souvent — les articles, l'annonce du mois, les
/// tarifs — est LU au serveur, jamais recopié.
///
/// ⚠️ CE QUI N'EST PAS REPRIS, ET POURQUOI
///
///   · les quatre témoignages : des noms inventés sur des portraits de banque
///     d'images (voir `CREDITS.md` de la vitrine). Des avis présentés comme
///     vrais et qui ne le sont pas n'entrent pas dans l'application ;
///   · les prix écrits dans les textes (« dès 165 000 FCFA ») : le prix vient
///     du barème du serveur, qui est seul à faire foi.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';

abstract final class Promesse {
  static const kicker = 'Centre de gestion agréé au Cameroun · Douala';
  static const titre = 'Créez votre entreprise, nous tenons vos comptes';
  static const detail =
      'De la première idée à la déclaration annuelle : statuts, '
      'immatriculation, comptabilité et fiscalité.';
}

/// Un chiffre, ce qu'il désigne, et le signe qui le rend lisible d'un regard.
///
/// ⚠️ L'icône ne remplace jamais le libellé : elle l'accompagne. Quatre nombres
/// alignés sans signe se lisaient comme un tableau, et l'œil devait lire les
/// quatre légendes pour comprendre lequel l'intéressait.
typedef Chiffre = ({String valeur, String libelle, IconData icone});

const chiffresDuCabinet = <Chiffre>[
  (valeur: '1994', libelle: 'Création du cabinet', icone: Icons.flag_outlined),
  (
    valeur: '500+',
    libelle: 'Entrepreneurs accompagnés',
    icone: Icons.groups_outlined,
  ),
  (
    valeur: '2020',
    libelle: 'Agrément du ministère des Finances',
    icone: Icons.verified_outlined,
  ),
  (
    valeur: 'TPE, PME',
    libelle: 'Notre cœur de métier',
    icone: Icons.storefront_outlined,
  ),
];

/// Un avantage de l'adhésion, avec son icône.
typedef Avantage = ({String titre, String detail});

abstract final class Adhesion {
  static const kicker = 'Comprendre le centre de gestion agréé';
  static const titre = "Ce que l'adhésion change pour votre entreprise";
  static const detail =
      'Un centre agréé est une structure agréée par le ministre chargé des '
      'Finances, qui assiste les petites entreprises adhérentes dans leur '
      'gestion et leurs obligations. Son intervention prévient le risque '
      'fiscal : la déclaration est vérifiée avant d\'être déposée.';

  static const avantages = <Avantage>[
    (
      titre: 'Abattement de 50 % sur le bénéfice déclaré',
      detail:
          'La base de votre impôt sur le résultat est réduite de moitié, dès '
          'votre première déclaration.',
    ),
    (
      titre: 'Exonération de patente deux ans',
      detail: 'Une trésorerie préservée au moment où votre activité démarre.',
    ),
    (
      titre: 'Contrôle de vos pièces avant dépôt',
      detail:
          'Nos experts vérifient votre déclaration avant transmission au '
          'fisc : c\'est ce qui prévient le redressement.',
    ),
    (
      titre: 'Moins de pénalités, un dialogue facilité',
      detail:
          'L\'administration fiscale assiste techniquement les centres '
          'agréés ; votre dossier est instruit dans ce cadre.',
    ),
  ];
}

abstract final class Etapes {
  static const kicker = 'Comment ça se passe';
  static const titre = 'Trois étapes, et vous suivez tout en ligne';
  static const liste = <Avantage>[
    (
      titre: 'Vous remplissez le formulaire',
      detail:
          'Création d\'entreprise, service comptable ou juridique : deux '
          'minutes suffisent, sans créer de compte.',
    ),
    (
      titre: 'Un expert prend votre démarche en charge',
      detail:
          'Nous vous rappelons, établissons votre devis chiffré et ouvrons '
          'votre dossier dès le paiement.',
    ),
    (
      titre: 'Vous suivez l\'avancement en temps réel',
      detail:
          'Chaque étape est visible dans votre espace : pièces reçues, dépôt '
          'au guichet, documents disponibles.',
    ),
  ];
}

/// Les services de la vitrine qui ne sont PAS au barème du serveur : ils se
/// traitent par un appel, pas par une souscription.
const autresServices = <Avantage>[
  (
    titre: 'Assistance juridique',
    detail:
        'Statuts, pactes d\'associés, baux, contrats de travail et suivi du '
        'greffe. Nos juristes sécurisent les actes qui engagent votre société.',
  ),
  (
    titre: 'Conseil et mise en relation',
    detail:
        'Avocats, notaires et experts-comptables partenaires, recherche de '
        'financement, accompagnement bancaire.',
  ),
];

abstract final class Blog {
  static const kicker = 'Le blog du cabinet';
  static const titre = 'Ce qui change, et ce que ça change pour vous';
}

abstract final class Partenaires {
  static const kicker = 'Nos partenaires';
  static const titre = 'Le cadre dans lequel nous travaillons';
  static const detail =
      'Nos dossiers passent par ces institutions : elles reçoivent vos '
      'déclarations, encadrent la profession et fixent le droit comptable '
      'applicable.';
}

abstract final class Joindre {
  static const titre = 'Parlons de votre projet dès aujourd\'hui';
  static const detail =
      'Écrivez-nous sur WhatsApp, appelez-nous, ou passez à notre bureau de '
      'Douala. Nos experts prennent votre demande en charge.';
}
