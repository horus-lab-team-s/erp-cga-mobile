import 'package:flutter/material.dart';

/// Les jetons de la marque, traduits du système du web.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ CE FICHIER NE DÉCIDE RIEN. IL TRADUIT.
///
/// La source est `app/styles/tokens.css`, dans les dépôts de la console et de la
/// vitrine, lui-même mesuré sur le logo du cabinet. Toute valeur inventée ici
/// ferait une seconde identité : l'adhérent verrait un produit sur son téléphone
/// et un autre sur son écran, pour le même cabinet.
///
/// ⚠️ L'APPLICATION ÉTAIT VERTE, ET C'ÉTAIT UNE ERREUR.
///
/// Le vert ne figure nulle part dans la marque. Il venait d'un choix fait avant
/// d'avoir regardé le logo, et il a tenu trois pas. Les deux teintes sont
/// l'indigo et le magenta, et il n'y en a pas de troisième.
///
/// LES RÈGLES QUI ACCOMPAGNENT CES VALEURS, § 10.7 du dossier de design
///
///   · deux teintes de marque, jamais une troisième ;
///   · pas de dégradé, pas d'animation spectaculaire ;
///   · l'indigo porte l'institution, le magenta porte l'ACTION — une seule
///     action principale par écran ;
///   · la couleur ne porte jamais seule l'information : un état se dit aussi
///     par un mot ou une forme, pour qui ne distingue pas les teintes.
/// ─────────────────────────────────────────────────────────────────────────────
abstract final class Marque {
  // ── Clair ─────────────────────────────────────────────────────────────
  /// Barre latérale, en-têtes sombres, pied de page.
  static const indigo900 = Color(0xFF2E1B4D);

  /// Titres, liens, actions secondaires.
  static const indigo700 = Color(0xFF492F79);

  /// Ligne sélectionnée, en-têtes de colonne.
  static const indigo100 = Color(0xFFEDE9F5);

  /// L'action principale, unique par vue.
  static const magenta600 = Color(0xFF8C2D86);

  /// Survol de ligne, badges d'accent.
  static const magenta100 = Color(0xFFF7E9F6);

  static const encre900 = Color(0xFF1A1523);
  static const encre700 = Color(0xFF433C52);
  static const encre500 = Color(0xFF6B6480);
  static const encre300 = Color(0xFF9A94A8);
  static const filet300 = Color(0xFFC9C4D6);
  static const filet200 = Color(0xFFE5E1EC);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF7F5FB);

  /// ⚠️ ASSOMBRI DE #FAF9FC À #F4F2F9, et ce n'est pas un détail de goût.
  ///
  /// À #FAF9FC, le fond de page et la carte blanche ne différaient que d'un
  /// pour cent : la carte ne se détachait pas, et il fallait un filet dur tout
  /// autour pour qu'on la voie. C'est ce filet qui donnait à l'application son
  /// air de formulaire administratif.
  ///
  /// À #F4F2F9, l'écart suffit pour que le blanc paraisse posé dessus. Le
  /// filet peut alors disparaître au profit d'une ombre très basse. Le fond
  /// reste assez clair pour que l'encre 900 y garde 15,2:1.
  static const fond = Color(0xFFF4F2F9);

  /// ⚠️ Gravité. Ces trois teintes ne disent jamais seules ce qu'elles disent :
  /// un mot les accompagne toujours.
  static const reussite = Color(0xFF1E7A4C);
  static const reussite100 = Color(0xFFE6F2EC);
  static const alerte = Color(0xFFB4690E);
  static const alerte100 = Color(0xFFFBF0E2);
  static const danger = Color(0xFFB3261E);
  static const danger100 = Color(0xFFF9E7E5);

  // ── Sombre ────────────────────────────────────────────────────────────
  //
  // ⚠️ Ce ne sont pas les mêmes valeurs éclaircies au hasard. L'indigo profond
  // cesse d'être une surface haute pour devenir le socle, et le magenta est
  // remonté en clarté : tel quel, il ne tient pas le contraste sur le fond.
  static const indigo900Sombre = Color(0xFF0F0B16);
  static const indigo700Sombre = Color(0xFFC0A6E0);
  static const indigo100Sombre = Color(0xFF2A2340);
  static const magenta600Sombre = Color(0xFFC05FB8);
  static const magenta100Sombre = Color(0xFF37223D);

  static const encre900Sombre = Color(0xFFF4F1F8);
  static const encre700Sombre = Color(0xFFD3CDE0);
  static const encre500Sombre = Color(0xFFA79FB8);
  static const encre300Sombre = Color(0xFF6F6684);
  static const filet300Sombre = Color(0xFF453B5C);
  static const filet200Sombre = Color(0xFF332B46);
  static const surfaceSombre = Color(0xFF221C30);
  static const surface2Sombre = Color(0xFF2B2439);
  static const fondSombre = Color(0xFF14101C);

  static const reussiteSombre = Color(0xFF4CC38A);
  static const reussite100Sombre = Color(0xFF14312A);
  static const alerteSombre = Color(0xFFE0A458);
  static const alerte100Sombre = Color(0xFF3A2A16);
  static const dangerSombre = Color(0xFFF2726A);
  static const danger100Sombre = Color(0xFF3D1B1C);

  // ── Le relief ─────────────────────────────────────────────────────────
  //
  // ─────────────────────────────────────────────────────────────────────────
  // ⚠️ POURQUOI L'APPLICATION A DES OMBRES ALORS QUE LA CONSOLE N'EN A PAS
  //
  // La console sépare ses lignes de tableau PAR UN FILET ET JAMAIS PAR UNE
  // OMBRE : une ombre sous chaque ligne d'un tableau de quarante lignes fait
  // vibrer l'écran et ralentit le rendu. Cette règle vise le tableau dense du
  // poste de travail.
  //
  // Un téléphone ne montre pas de tableau dense : il montre cinq ou six
  // cartes, une par chose à faire. Là, le filet dur est ce qui rend l'écran
  // sec — chaque carte encadrée comme un formulaire administratif. Une ombre
  // très basse fait le même travail de séparation en laissant l'œil respirer.
  //
  // Les valeurs sont TEINTÉES D'INDIGO et non noires : une ombre noire sur un
  // fond légèrement violet donne un gris sale. 4 % près de la carte pour
  // l'asseoir, 6 % plus loin pour la détacher du fond.
  // ─────────────────────────────────────────────────────────────────────────
  // ⚠️ ADOUCIE : la seconde ombre passe de 15 % sur 18 points à 11 % sur 24. La
  // carte se détache autant, mais le bord de l'ombre cesse de se voir comme un
  // trait gris sous la carte — c'est ce trait qui durcissait l'écran.
  static const ombreCarte = [
    BoxShadow(color: Color(0x0A2E1B4D), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0B2E1B4D), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// L'ombre d'un élément qui flotte réellement au-dessus du contenu : barre
  /// basse, feuille qui remonte. Plus large, jamais plus foncée.
  static const ombreFlottante = [
    BoxShadow(color: Color(0x142E1B4D), blurRadius: 24, offset: Offset(0, -2)),
  ];

  /// L'ombre d'un élément RÉPÉTÉ dans une liste : presque rien.
  ///
  /// ⚠️ VU SUR L'APPAREIL. Sur l'écran des échéances, huit cartes portant
  /// chacune l'ombre pleine faisaient vibrer la page : autant de reliefs que de
  /// lignes, et l'œil ne savait plus ce qui comptait. Une carte posée seule
  /// garde `ombreCarte` ; les éléments d'une liste reçoivent celle-ci, qui les
  /// décolle du fond sans les faire flotter.
  static const ombreListe = [
    BoxShadow(color: Color(0x082E1B4D), blurRadius: 10, offset: Offset(0, 2)),
  ];

  // ── Le rythme ─────────────────────────────────────────────────────────
  //
  // ⚠️ SIX VALEURS, ET PLUS AUCUN NOMBRE CHOISI AU CAS PAR CAS. Les écrans
  // écrivaient 6, 10, 14, 18, 26 selon l'humeur : deux blocs voisins
  // respiraient différemment sans raison, et l'ensemble paraissait approximatif.
  // Tout se pose désormais sur une grille de quatre points.
  static const espace1 = 4.0;
  static const espace2 = 8.0;
  static const espace3 = 12.0;
  static const espace4 = 16.0;
  static const espace5 = 20.0;
  static const espace6 = 24.0;
  static const espace8 = 32.0;

  /// Ce qu'une page défilante doit laisser libre en bas.
  ///
  /// ⚠️ La barre du bas FLOTTE : elle est détachée des bords, et le contenu
  /// passe dessous. Sans cette marge, la dernière carte de chaque écran finit
  /// cachée derrière elle, et l'on croit la page finie là.
  static const espaceSousLaBarre = 104.0;

  /// L'espace à laisser sous une liste défilante, barre du bas comprise.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// ⚠️ NE PAS RÉSERVER LA CONSTANTE : DEMANDER LA VALEUR AU CADRE.
  ///
  /// La coquille pose la barre en `bottomNavigationBar` d'un `Scaffold` en
  /// `extendBody`. Dans ce montage, Flutter annonce lui-même au contenu la
  /// hauteur que la barre lui prend, dans `MediaQuery.paddingOf(...).bottom`.
  /// Cette valeur est complète : la barre, sa marge, ET l'encart du système —
  /// la bande de gestes en bas de l'écran.
  ///
  /// Mesuré le 27 septembre sur un TECNO KM5 à navigation gestuelle :
  ///
  ///     hauteur=800  padding.bottom=114  viewPadding.bottom=0
  ///
  /// soit 86 (la barre) + 12 (sa marge) + 16 (l'encart). La constante écrite à
  /// la main en réservait 104 : il en manquait dix, et la dernière section de
  /// l'accueil — les raccourcis — restait coupée.
  ///
  /// Deux pièges, tous deux vérifiés sur l'appareil :
  ///
  ///   · `viewPadding` vaut **zéro** ici, et non l'encart. La coquille pose la
  ///     barre dans une `SafeArea` ; `MediaQuery.removePadding` retranche de
  ///     `viewPadding` ce qu'elle a consommé. Y ajouter `viewPadding` n'ajoute
  ///     donc rien du tout.
  ///   · la hauteur de la barre GRANDIT avec la taille de texte du système.
  ///     Une constante ne peut pas suivre ; `padding.bottom`, si.
  ///
  /// La constante reste comme plancher, pour un écran monté hors de la
  /// coquille, où le cadre n'a rien à annoncer.
  /// ─────────────────────────────────────────────────────────────────────────
  static double espaceSousLaBarreDe(BuildContext context) {
    final annoncee = MediaQuery.paddingOf(context).bottom;
    // `espace3` d'air : sans lui, la dernière ligne touche la barre.
    return (annoncee > 0 ? annoncee : espaceSousLaBarre) + espace3;
  }

  // ── Les rayons ────────────────────────────────────────────────────────
  //
  // ⚠️ TROIS VALEURS, PAS DIX. Elles étaient dispersées dans les écrans : 10,
  // 12, 14, 18, 999, choisies au cas par cas. Deux cartes voisines n'avaient
  // pas le même arrondi et l'ensemble paraissait bricolé.
  //
  // ⚠️ RESSERRÉES À LA DEMANDE DU CABINET, ET ALIGNÉES SUR LA CONSOLE. 18 et
  // 12 donnaient à l'application un air de jouet : des cartes molles, des
  // boutons presque en pilule. Un cabinet comptable se lit mieux avec des
  // angles nets. Les valeurs sont maintenant EXACTEMENT celles de la console
  // (`tokens.css`) : `--rayon: 8px` pour les cartes, panneaux et boutons,
  // `--rayon-petit: 4px` pour les petits éléments. Le même cabinet, sur le
  // poste de travail et sur le téléphone, avec les mêmes angles.
  /// Une carte, une feuille, un bouton, un champ de saisie.
  ///
  /// ⚠️ **SEIZE, ET PLUS HUIT — DÉCISION DU CABINET DU 23 SEPTEMBRE 2026.**
  ///
  /// Les angles avaient été resserrés à 8 pour s'aligner sur la console
  /// (`--rayon: 8px`) : un cabinet comptable se lit mieux avec des angles nets.
  /// Le cabinet a ensuite demandé, pour le TÉLÉPHONE seulement, un rendu de
  /// facture plus contemporaine. Seize points sont ce que les systèmes mobiles
  /// emploient aujourd'hui pour une carte tenue à la main.
  ///
  /// ⚠️ La console, elle, NE BOUGE PAS : un tableau de quarante lignes aux
  /// angles de seize points devient mou. Les deux surfaces n'ont ni le même
  /// usage ni la même distance de lecture ; c'est la seule divergence assumée
  /// entre le poste de travail et le téléphone.
  static const rayonCarte = 16.0;

  /// Un bloc posé DANS une carte, un élément de moins de 28 points de haut.
  /// ⚠️ La moitié du rayon de la carte : un bloc intérieur au même rayon que
  /// son contenant donne l'impression d'un cadre qui flotte.
  static const rayonBloc = 8.0;

  /// Une pastille, une étiquette, un bouton en forme de gélule.
  static const rayonPastille = 999.0;

  // ── Les polices (18 octobre 2026) ─────────────────────────────────────
  /// Le texte courant, les montants, les champs : Inter, celle de la console.
  static const policeTexte = 'Inter';

  /// Les titres et les grands chiffres : Poppins, celle de la console.
  static const policeTitre = 'Poppins';

  // ── Le dégradé de marque ──────────────────────────────────────────────
  //
  // ─────────────────────────────────────────────────────────────────────────
  // ⚠️ AUTORISÉ PAR LE CABINET LE 23 SEPTEMBRE 2026, ET SEULEMENT ICI.
  //
  // Le § 10.7 du dossier de design disait « pas de dégradé ». La règle visait
  // les dégradés décoratifs, qui font du bruit et vieillissent mal. Le cabinet
  // a demandé un rendu plus contemporain sur le téléphone : le dégradé est donc
  // admis, sous trois conditions qui le gardent honnête.
  //
  //   · il ne relie que LES DEUX TEINTES DE LA MARQUE, jamais une troisième ;
  //   · il ne porte que DEUX SURFACES : l'en-tête de l'espace adhérent et la
  //     grande action. Une liste, une carte, une étiquette restent plates ;
  //   · le texte posé dessus est mesuré sur l'EXTRÉMITÉ LA PLUS CLAIRE, jamais
  //     sur la moyenne — sans quoi le contraste tient d'un côté et pas de
  //     l'autre. Blanc sur magenta 600 : 7,41:1 ; blanc sur indigo 900 : 14,8:1.
  // ─────────────────────────────────────────────────────────────────────────
  static const degradeMarque = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo900, Color(0xFF5B2A6F), magenta600],
  );

  /// Le même, pour le mode sombre : il part du socle et ne monte qu'à mi-chemin.
  /// ⚠️ Un dégradé aussi clair qu'en mode clair rallumerait l'écran la nuit.
  static const degradeMarqueSombre = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo900Sombre, Color(0xFF2A1B3A), Color(0xFF5B2A6F)],
  );

  /// Le logo en couleur, sur fond clair.
  static const logoCouleur = 'assets/marque/cga-logo-couleur.jpg';

  /// Le logo en blanc, pour les fonds indigo et le mode sombre.
  static const logoBlanc = 'assets/marque/cga-logo-blanc.png';
}

/// Le thème clair.
///
/// ⚠️ Les rayons, les épaisseurs et les hauteurs sont posés ici et nulle part
/// ailleurs. Un bouton dessiné au cas par cas dans un écran produit une
/// application où deux boutons voisins n'ont ni la même hauteur ni le même
/// arrondi, et personne ne sait dire lequel est le bon.
ThemeData themeClair() => _theme(
  brightness: Brightness.light,
  primaire: Marque.magenta600,
  surPrimaire: Colors.white,
  institution: Marque.indigo900,
  titre: Marque.indigo700,
  fond: Marque.fond,
  surface: Marque.surface,
  surfaceHaute: Marque.surface2,
  encre: Marque.encre900,
  encreDouce: Marque.encre500,
  filet: Marque.filet200,
  filetFort: Marque.filet300,
  danger: Marque.danger,
  dangerDoux: Marque.danger100,
);

/// Le thème sombre. Autorisé par dérogation du cabinet du 10 août 2026.
ThemeData themeSombre() => _theme(
  brightness: Brightness.dark,
  primaire: Marque.magenta600Sombre,
  // ⚠️ Texte SOMBRE sur le magenta éclairci : du blanc dessus tomberait sous le
  // seuil de lisibilité, et c'est le bouton le plus important de l'écran.
  surPrimaire: Marque.indigo900Sombre,
  institution: Marque.indigo900Sombre,
  titre: Marque.indigo700Sombre,
  fond: Marque.fondSombre,
  surface: Marque.surfaceSombre,
  surfaceHaute: Marque.surface2Sombre,
  encre: Marque.encre900Sombre,
  encreDouce: Marque.encre500Sombre,
  filet: Marque.filet200Sombre,
  filetFort: Marque.filet300Sombre,
  danger: Marque.dangerSombre,
  dangerDoux: Marque.danger100Sombre,
);

ThemeData _theme({
  required Brightness brightness,
  required Color primaire,
  required Color surPrimaire,
  required Color institution,
  required Color titre,
  required Color fond,
  required Color surface,
  required Color surfaceHaute,
  required Color encre,
  required Color encreDouce,
  required Color filet,
  required Color filetFort,
  required Color danger,
  required Color dangerDoux,
}) {
  final schema = ColorScheme(
    brightness: brightness,
    primary: primaire,
    onPrimary: surPrimaire,
    primaryContainer: brightness == Brightness.light
        ? Marque.magenta100
        : Marque.magenta100Sombre,
    onPrimaryContainer: titre,
    secondary: titre,
    onSecondary: Colors.white,
    secondaryContainer: brightness == Brightness.light
        ? Marque.indigo100
        : Marque.indigo100Sombre,
    onSecondaryContainer: titre,
    surface: surface,
    onSurface: encre,
    // ⚠️ LA GAMME ENTIÈRE EST DÉCLARÉE, et c'est une correction.
    //
    // Seuls `surfaceContainerLowest` et `surfaceContainer` l'étaient. Les
    // écrans, eux, dessinaient leurs cartes sur `surfaceContainerLow`, que
    // personne n'avait posé : le cadre le calculait alors tout seul, à partir
    // du blanc, et rendait un blanc. Carte blanche sur fond quasi blanc, d'où
    // le filet dur indispensable pour la voir.
    //
    // L'échelle va maintenant du fond de page au relief :
    //   lowest  le fond de page, le plus sombre des clairs ;
    //   low     LA CARTE — blanche, elle se détache du fond ;
    //   normal  un bloc posé dans une carte ;
    //   high    un bloc posé sur un bloc.
    surfaceContainerLowest: fond,
    surfaceContainerLow: surface,
    surfaceContainer: surfaceHaute,
    surfaceContainerHigh: surfaceHaute,
    surfaceContainerHighest: surfaceHaute,
    onSurfaceVariant: encreDouce,
    outline: filetFort,
    outlineVariant: filet,
    error: danger,
    onError: Colors.white,
    errorContainer: dangerDoux,
    onErrorContainer: danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: schema,
    scaffoldBackgroundColor: fond,
    // ⚠️ L'ÉCHELLE TYPOGRAPHIQUE EST POSÉE ICI, et elle ne l'était pas.
    //
    // L'application prenait l'échelle par défaut du cadre. Elle est faite pour
    // l'anglais : interlignes serrés, aucune approche négative sur les gros
    // titres, corps de texte à 14. En français, où les mots sont plus longs,
    // cela donne des titres qui paraissent écartés et des paragraphes qui
    // collent.
    //
    //   · les gros titres se resserrent (approche négative) : au-delà de
    //     20 px, l'espacement par défaut fait flotter les lettres ;
    //   · les textes courants s'aèrent (interligne 1,5) : on les lit sur un
    //     téléphone, souvent debout, souvent dehors ;
    //   · rien ne descend sous 13 px. En dessous, un texte devient un décor.
    // 18 octobre 2026 (point 10) : Inter pour le texte, Poppins pour les titres, comme sur
    // la console et la vitrine. Jointes à l'application (`pubspec.yaml`).
    fontFamily: Marque.policeTexte,
    textTheme: _echelle(encre, encreDouce),
    // ⚠️ Pas de vaguelette qui s'étale sur toute la largeur d'une ligne : le
    // § 10.7 proscrit l'animation spectaculaire, et sur un téléphone d'entrée
    // de gamme elle saccade.
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: institution,
      foregroundColor: brightness == Brightness.light
          ? Colors.white
          : Marque.encre900Sombre,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: brightness == Brightness.light
            ? Colors.white
            : Marque.encre900Sombre,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // 52 points : une facture se photographie debout, une main occupée. La
        // cible recommandée est de 48 ; on prend au-dessus.
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Marque.rayonCarte),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: titre,
        side: BorderSide(color: filetFort),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Marque.rayonCarte),
        ),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: titre,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    // ⚠️ DES CHAMPS REMPLIS, ET NON CERCLÉS.
    //
    // Les champs portaient un contour gris sur fond blanc : quatre rectangles
    // dessinés les uns sous les autres, c'est l'apparence d'un formulaire de
    // déclaration. Un champ rempli d'un gris très pâle se lit comme un creux
    // où l'on écrit, et le contour ne reparaît qu'au moment où le champ prend
    // le curseur — là où il sert vraiment.
    // ─────────────────────────────────────────────────────────────────────
    // LES CHAMPS DE SAISIE, REPRIS LE 23 SEPTEMBRE 2026
    //
    // ⚠️ Ils avaient l'allure d'un formulaire administratif : un filet gris
    // tout autour, au repos comme à la saisie, et l'étiquette en gris pâle. Sur
    // un téléphone, un champ se reconnaît à sa SURFACE, pas à son cadre.
    //
    //   · au repos   une surface teintée, sans aucun filet ;
    //   · au survol  la surface s'assombrit d'un cran ;
    //   · à la saisie un filet de DEUX points dans la teinte d'action, et la
    //     surface redevient blanche : le champ actif est le plus clair de
    //     l'écran, celui où l'œil tombe ;
    //   · en erreur  le filet passe au rouge, et le message porte le mot.
    //
    // ⚠️ La hauteur monte à 56 points : c'est la cible tactile confortable, et
    // ce que prennent les champs des applications bancaires d'aujourd'hui.
    // ─────────────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceHaute,
      hoverColor: brightness == Brightness.light
          ? Marque.indigo100.withValues(alpha: 0.5)
          : Marque.indigo100Sombre,
      // ⚠️ ASYMÉTRIQUE, ET C'EST LA CORRECTION D'UN DÉFAUT VU AU RENDU.
      //
      // À vingt points en haut comme en bas, l'étiquette qui remonte à la
      // saisie — « Adresse électronique » — se posait SUR le texte tapé : les
      // deux se lisaient l'un par-dessus l'autre. Il lui faut sa place en haut
      // du champ, et le texte se cale en dessous.
      contentPadding: const EdgeInsets.fromLTRB(
        Marque.espace4,
        24,
        Marque.espace4,
        10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
        borderSide: BorderSide(color: primaire, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
        borderSide: BorderSide(color: danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
        borderSide: BorderSide(color: danger, width: 2),
      ),
      prefixIconColor: WidgetStateColor.resolveWith(
        (etats) => etats.contains(WidgetState.focused) ? primaire : encreDouce,
      ),
      // ⚠️ L'ÉTIQUETTE RESTE EN HAUT, TOUJOURS.
      //
      // Laissée « flottante », elle se posait SUR le texte tapé : les deux se
      // lisaient l'un par-dessus l'autre (vu au rendu). Et une étiquette qui
      // disparaît à la saisie laisse l'adhérent sans rappel de ce qu'il écrit,
      // trois champs plus bas. En haut, elle nomme le champ en permanence.
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(color: encreDouce, fontSize: 15),
      floatingLabelStyle: TextStyle(
        color: primaire,
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
      ),
      hintStyle: TextStyle(color: encreDouce.withValues(alpha: 0.75)),
      errorStyle: TextStyle(color: danger, fontWeight: FontWeight.w500),
    ),
    // ⚠️ La barre basse porte l'application entière : elle doit paraître
    // POSÉE SUR le contenu, pas collée au bord. Une ombre remontante et un
    // fond de surface, plutôt que la teinte calculée du cadre qui tirait vers
    // le gris-violet.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: brightness == Brightness.light
          ? Marque.magenta100
          : Marque.magenta100Sombre,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Marque.rayonCarte)),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (etats) => TextStyle(
          fontSize: 11.5,
          height: 1.2,
          fontWeight: etats.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: etats.contains(WidgetState.selected) ? primaire : encreDouce,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (etats) => IconThemeData(
          size: 23,
          color: etats.contains(WidgetState.selected) ? primaire : encreDouce,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceHaute,
      side: BorderSide.none,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Marque.rayonCarte)),
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: encre,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: institution,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14.5,
        height: 1.4,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Marque.rayonCarte + 6),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primaire,
      linearTrackColor: surfaceHaute,
      circularTrackColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(color: filet, space: 1, thickness: 1),
  );
}

/// L'échelle typographique, en un seul endroit.
///
/// ⚠️ Les tailles sont données en nombres à virgule quand il le faut : 14,5
/// n'est pas une coquetterie, c'est le demi-point qui sépare un texte courant
/// confortable d'un texte qui fatigue sur un écran de six pouces.
TextTheme _echelle(Color encre, Color encreDouce) => TextTheme(
  // Un montant, un chiffre qui est le sujet de l'écran.
  headlineLarge: TextStyle(
    fontFamily: Marque.policeTitre,
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: encre,
  ),
  headlineMedium: TextStyle(
    fontFamily: Marque.policeTitre,
    fontSize: 28,
    height: 1.18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: encre,
  ),
  headlineSmall: TextStyle(
    fontFamily: Marque.policeTitre,
    fontSize: 23,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: encre,
  ),
  // Le titre d'une section d'écran.
  titleLarge: TextStyle(
    fontFamily: Marque.policeTitre,
    fontSize: 20,
    height: 1.28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: encre,
  ),
  // Le titre d'une carte.
  titleMedium: TextStyle(
    fontFamily: Marque.policeTitre,
    fontSize: 16.5,
    height: 1.32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: encre,
  ),
  titleSmall: TextStyle(
    fontSize: 14.5,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: encre,
  ),
  // ⚠️ 1,55 et non 1,5 : sur un téléphone tenu à bout de bras, le demi-dixième
  // d'interligne est ce qui sépare un paragraphe qu'on lit d'un pavé qu'on saute.
  bodyLarge: TextStyle(fontSize: 15.5, height: 1.55, color: encre),
  bodyMedium: TextStyle(fontSize: 14.5, height: 1.55, color: encre),
  // ⚠️ 13 et pas moins : c'est le plancher de ce qui se lit dehors, au soleil,
  // sur un écran qui n'est pas neuf.
  bodySmall: TextStyle(fontSize: 13, height: 1.5, color: encreDouce),
  labelLarge: TextStyle(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: encre,
  ),
  labelMedium: TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: encre,
  ),
  labelSmall: TextStyle(
    fontSize: 11.5,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: encreDouce,
  ),
);
