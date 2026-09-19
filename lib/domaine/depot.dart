/// Un justificatif photographié sur le terrain, et son sort.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// POURQUOI CE FICHIER EST LE PREMIER DU PROJET
///
/// L'application de terrain n'existe que pour une raison : l'adhérent est dans sa
/// boutique, il a une facture en main, et le réseau est mauvais. Tout le reste
/// découle de là. Un dépôt n'est donc PAS un appel réseau qui réussit ou échoue :
/// c'est une chose qui existe sur l'appareil, qui survit à la coupure, à la
/// fermeture de l'application et au redémarrage du téléphone, et qui part quand
/// elle peut.
///
/// ⚠️ C'est la différence entre « l'envoi a échoué, recommencez » et « c'est
/// enregistré, ça partira ». La première phrase fait perdre la pièce, parce que
/// personne ne recommence une photo de facture le soir venu.
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// Où en est un dépôt dans son voyage vers le serveur.
enum EtatDuDepot {
  /// Enregistré sur l'appareil, pas encore parti.
  enAttente,

  /// Parti, le serveur a accusé réception.
  remis,

  /// Le serveur l'a refusé pour une raison qui ne passera pas avec le temps :
  /// type de document non accepté, fichier trop volumineux, doublon certain,
  /// dossier hors du périmètre de l'adhérent.
  ///
  /// ⚠️ Un refus n'est pas une panne de réseau. Le distinguer est ce qui évite
  /// qu'une file se vide en boucle contre un serveur qui dira toujours non.
  refuse,
}

/// Un justificatif en attente de remise.
class Depot {
  const Depot({
    required this.identifiant,
    required this.dossier,
    required this.cheminDuFichier,
    required this.prisLe,
    this.etat = EtatDuDepot.enAttente,
    this.tentatives = 0,
    this.motifDuRefus,
  });

  /// Engendré sur l'appareil. ⚠️ Il ne sert qu'ICI, à retrouver le dépôt dans la
  /// file : **le serveur ne le voit jamais.**
  ///
  /// La charpente de ce dépôt affirmait le contraire — « le serveur reconnaît
  /// l'identifiant et rend le même accusé ». C'était faux, et la confrontation
  /// avec le code du serveur l'a montré : l'idempotence y est acquise autrement,
  /// et mieux. La pièce est identifiée par l'**empreinte de ses octets**, comme
  /// le magasin de fichiers l'est déjà. Redéposer le même fichier sur le même
  /// dossier rend la même pièce, inchangée, en 200 avec `rejeu: true`.
  ///
  /// La propriété qui compte est donc tenue, mais par le contenu et non par un
  /// numéro que le client aurait pu se tromper de recopier. Un identifiant tiré
  /// au sort aurait laissé au seul détecteur de doublons le soin d'attraper un
  /// rejeu, ce que le serveur dit explicitement avoir refusé de faire.
  final String identifiant;

  /// Le dossier comptable auquel la pièce se rattache.
  final String dossier;

  /// Le fichier sur l'appareil. ⚠️ Pas les octets : une file de vingt photos
  /// tiendrait en mémoire un espace que le système reprendra au premier besoin.
  final String cheminDuFichier;

  /// L'instant de la prise de vue, pas celui de la remise.
  ///
  /// ⚠️ C'est cette date que la comptabilité retient. Prendre celle de la remise
  /// ferait glisser au mois suivant toute pièce photographiée le 31 au soir dans
  /// une zone sans réseau.
  final DateTime prisLe;

  final EtatDuDepot etat;

  /// Combien de fois on a déjà essayé. Sert à espacer les tentatives.
  final int tentatives;

  /// Renseigné seulement quand l'état est [EtatDuDepot.refuse]. La phrase vient
  /// du serveur et s'affiche telle quelle : c'est elle qui dit à l'adhérent quoi
  /// reprendre.
  final String? motifDuRefus;

  Depot avec({EtatDuDepot? etat, int? tentatives, String? motifDuRefus}) {
    return Depot(
      identifiant: identifiant,
      dossier: dossier,
      cheminDuFichier: cheminDuFichier,
      prisLe: prisLe,
      etat: etat ?? this.etat,
      tentatives: tentatives ?? this.tentatives,
      motifDuRefus: motifDuRefus ?? this.motifDuRefus,
    );
  }

  Map<String, dynamic> versJson() => {
    'identifiant': identifiant,
    'dossier': dossier,
    'chemin_du_fichier': cheminDuFichier,
    'pris_le': prisLe.toIso8601String(),
    'etat': etat.name,
    'tentatives': tentatives,
    if (motifDuRefus != null) 'motif_du_refus': motifDuRefus,
  };

  static Depot depuisJson(Map<String, dynamic> json) => Depot(
    identifiant: json['identifiant'] as String,
    dossier: json['dossier'] as String,
    cheminDuFichier: json['chemin_du_fichier'] as String,
    prisLe: DateTime.parse(json['pris_le'] as String),
    etat: EtatDuDepot.values.byName(json['etat'] as String),
    tentatives: json['tentatives'] as int? ?? 0,
    motifDuRefus: json['motif_du_refus'] as String?,
  );
}
