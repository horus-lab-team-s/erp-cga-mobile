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
  static const fond = Color(0xFFFAF9FC);

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
    surfaceContainerLowest: fond,
    surfaceContainer: surfaceHaute,
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: filet),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // 52 points : une facture se photographie debout, une main occupée. La
        // cible recommandée est de 48 ; on prend au-dessus.
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: filetFort),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: filetFort),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: primaire, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: danger),
      ),
      labelStyle: TextStyle(color: encreDouce),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: institution,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dividerTheme: DividerThemeData(color: filet, space: 1, thickness: 1),
  );
}
