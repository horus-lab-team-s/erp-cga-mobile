/// La comparaison de texte employée par les recherches de l'application.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ SANS ACCENTS, ET C'EST LA RAISON D'ÊTRE DE CE FICHIER.
///
/// On cherche « fevrier » sur un clavier de téléphone, pas « février » : la
/// touche des accents est en second niveau, et personne ne l'ouvre pour filtrer
/// une liste. Une comparaison brute ne rendrait rien, et l'adhérent en
/// conclurait que le document n'existe pas.
///
/// Le sens marche aussi : taper « février » doit trouver une ligne écrite
/// « Fevrier » par un opérateur pressé. Les deux côtés sont donc normalisés.
///
/// ⚠️ UNE TABLE, ET NON `String.normalize` : Dart ne porte pas la
/// décomposition Unicode dans sa bibliothèque standard, et tirer un paquet pour
/// douze caractères serait payer cher une chose que le français tient en une
/// ligne. Ce sont les lettres accentuées du français, plus le `ç` et les
/// ligatures.
/// ─────────────────────────────────────────────────────────────────────────────
library;

const _accents = {
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'á': 'a',
  'ã': 'a',
  'å': 'a',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'î': 'i',
  'ï': 'i',
  'í': 'i',
  'ô': 'o',
  'ö': 'o',
  'ó': 'o',
  'õ': 'o',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ú': 'u',
  'ÿ': 'y',
  'ñ': 'n',
  'œ': 'oe',
  'æ': 'ae',
};

/// Le texte ramené à ce qui se tape : minuscules, sans accent.
String aplati(String texte) {
  final bas = texte.toLowerCase();
  final tampon = StringBuffer();
  for (final lettre in bas.split('')) {
    tampon.write(_accents[lettre] ?? lettre);
  }
  return tampon.toString();
}

/// Vrai si l'un des [champs] contient [recherche].
///
/// ⚠️ **UNE RECHERCHE VIDE REND VRAI.** C'est le cas le plus fréquent — le champ
/// n'a pas encore été employé —, et il doit laisser passer toute la liste.
/// Rendre faux viderait l'écran à l'ouverture.
///
/// ⚠️ Les mots se cherchent SÉPARÉMENT : « tva fevrier » trouve une ligne
/// « TVA du mois · février 2024 », où les deux mots sont dans deux champs
/// différents et dans l'autre ordre. Exiger la chaîne entière obligerait à
/// deviner la mise en forme de la ligne.
bool correspond(Iterable<String?> champs, String recherche) {
  final mots = aplati(recherche).split(' ').where((m) => m.isNotEmpty);
  if (mots.isEmpty) return true;
  final botte = champs.where((c) => c != null).map((c) => aplati(c!)).join(' ');
  return mots.every(botte.contains);
}
