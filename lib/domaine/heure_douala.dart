/// L'heure du cabinet, pour ce que le serveur horodate.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ LA DISTINCTION QUI COMMANDE TOUT : UNE DATE N'EST PAS UN INSTANT.
///
/// `2026-08-15` est une **date de calendrier** — une échéance, une période
/// déclarative. Elle ne se convertit pas : le 15 août est le 15 août partout, et
/// lui appliquer un décalage la ferait glisser d'un jour.
///
/// `2026-08-15T23:30:00` est un **instant**, horodaté en UTC par le serveur.
/// `app/partage/horloge.py` le dit : « tout est horodaté en UTC, et la
/// conversion à l'affichage est l'affaire de l'interface ». Cet instant-là est
/// déjà le **16 août** à Douala.
///
/// ⚠️ `DateTime.parse` NE FAIT PAS CE TRAVAIL, ET FAIT PIRE QUE RIEN.
///
/// Sans `Z` final, il interprète la chaîne dans le fuseau de **l'appareil**. Sur
/// un téléphone réglé à Douala, `2026-08-15T23:30:00` devient 23 h 30 heure
/// locale — soit une heure de moins que la réalité, et le jour de la veille pour
/// tout ce qui s'est passé entre minuit et une heure du matin.
///
/// Conséquence concrète sur l'historique de l'adhérent : une pièce déposée à
/// 00 h 30 apparaît **la veille**, et bascule dans le mois précédent le premier
/// du mois. Sur un dépôt de justificatif, le mois de rattachement n'est pas un
/// détail de présentation.
///
/// ⚠️ Le Cameroun est à UTC+1 toute l'année, sans heure d'été. Le décalage est
/// une constante, écrite ici une fois — miroir de `app/lib/heure-douala.ts` des
/// deux interfaces web.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// Le décalage du Cameroun, constant.
const Duration decalageDouala = Duration(hours: 1);

/// Lit un instant horodaté en UTC par le serveur, rendu à l'heure de Douala.
///
/// ⚠️ Une valeur qui ne porte PAS d'heure est une date de calendrier : elle est
/// rendue telle quelle, sans décalage.
DateTime instantDeDouala(String valeur) {
  final porteUneHeure = RegExp(
    r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}',
  ).hasMatch(valeur);
  if (!porteUneHeure) return DateTime.parse(valeur.substring(0, 10));
  // ⚠️ `isUtc: true` posé explicitement : sans lui le fuseau de l'appareil
  // s'applique, et le décalage s'ajoute deux fois — ou pas du tout, selon le
  // téléphone. On repasse ensuite en heure locale nominale pour que `.day`,
  // `.month` et `.year` se lisent directement à l'écran.
  final utc = DateTime.parse('${valeur.replaceFirst(' ', 'T')}Z');
  final douala = utc.add(decalageDouala);
  return DateTime(
    douala.year,
    douala.month,
    douala.day,
    douala.hour,
    douala.minute,
    douala.second,
  );
}
