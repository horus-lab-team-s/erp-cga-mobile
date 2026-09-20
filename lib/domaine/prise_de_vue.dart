import 'dart:io';

import '../ports/appareil_photo.dart';
import 'depot.dart';
import 'file_d_attente.dart';

/// Ce qui se passe entre le déclencheur et la file.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ LA PHOTO DOIT ÊTRE RECOPIÉE, ET C'EST LE CŒUR DE CE FICHIER
///
/// L'appareil photo du système range son résultat dans un **cache**. Le système
/// vide les caches quand la place manque, sans prévenir et sans demander. Si la
/// file gardait ce chemin-là, voici ce qui arriverait :
///
///   · l'adhérent photographie six factures un samedi, sans réseau ;
///   · le téléphone se remplit, le système reprend la place du cache ;
///   · le lundi, le réseau revient, la file tente ses six remises et ne trouve
///     plus aucun fichier. Les six dépôts sortent de la file comme **refusés**.
///
/// Le pire n'est pas la perte : c'est qu'elle ressemble à un refus du cabinet.
/// L'adhérent croit que ses pièces ont été rejetées.
///
/// On recopie donc les octets à côté de la file, dans le dossier des documents
/// de l'application, que le système ne reprend jamais. Le fichier de cache peut
/// alors disparaître : il ne sert plus à rien.
///
/// ⚠️ ET ON EFFACE APRÈS REMISE, JAMAIS AVANT
///
/// Une copie qui reste après la remise remplit le téléphone en quelques
/// semaines. Une copie effacée avant l'accusé de réception perd la pièce si la
/// réponse se perd en route. L'ordre n'est donc pas négociable.
/// ─────────────────────────────────────────────────────────────────────────────
class PriseDeVue {
  const PriseDeVue({
    required this.appareil,
    required this.file,
    required this.photos,
  });

  final AppareilPhoto appareil;
  final FileDAttente file;

  /// Où vivent les copies durables. Voisin du fichier de la file, et pour la
  /// même raison : le système ne reprend pas le dossier des documents.
  final Directory photos;

  /// Photographie une pièce et la met en file. Rend le dépôt créé, ou `null` si
  /// la personne a renoncé.
  Future<Depot?> pour(String dossier) async {
    final provisoire = await appareil.photographier();
    if (provisoire == null) {
      return null;
    }
    // ⚠️ L'instant de la PRISE DE VUE, pris ici et non à la remise. C'est cette
    // date que la comptabilité retient : celle de la remise ferait glisser au
    // mois suivant toute pièce photographiée le 31 au soir sans réseau.
    final prisLe = DateTime.now();
    final identifiant = 'D-${prisLe.microsecondsSinceEpoch}';

    await photos.create(recursive: true);
    final durable = File('${photos.path}/$identifiant.jpg');
    await File(provisoire).copy(durable.path);

    final depot = Depot(
      identifiant: identifiant,
      dossier: dossier,
      cheminDuFichier: durable.path,
      prisLe: prisLe,
    );
    await file.ajouter(depot);
    return depot;
  }

  /// Photographie une pièce et en garde une copie durable, SANS la mettre en
  /// file. Rend le chemin de la copie, ou `null` si l'adhérent a renoncé.
  ///
  /// ─────────────────────────────────────────────────────────────────────────
  /// ⚠️ POURQUOI UNE QUITTANCE NE PASSE PAS PAR LA FILE
  ///
  /// La file dépose des pièces au fil de l'eau : chacune part seule, et le
  /// cabinet l'identifie ensuite. Une quittance, elle, ne vaut que rattachée à
  /// l'obligation qu'elle acquitte, et ce rattachement se fait dans le même
  /// geste que le dépôt.
  ///
  /// La faire passer par la file la déposerait **deux fois** : une fois par la
  /// file, une fois par l'envoi de la preuve. Le cabinet recevrait deux
  /// quittances identiques, dont une muette.
  ///
  /// ⚠️ LA COPIE DURABLE RESTE INDISPENSABLE, elle. L'appareil photo du système
  /// range son résultat dans un cache que le système vide quand la place
  /// manque, sans prévenir. Entre la prise de vue et la fin de l'envoi, il y a
  /// un aller-retour réseau : de quoi perdre le fichier sur un téléphone plein.
  /// ─────────────────────────────────────────────────────────────────────────
  Future<String?> copieDurable() async {
    final provisoire = await appareil.photographier();
    if (provisoire == null) {
      return null;
    }
    await photos.create(recursive: true);
    final durable = File(
      '${photos.path}/Q-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await File(provisoire).copy(durable.path);
    return durable.path;
  }

  /// Efface les copies des dépôts qui ne sont plus dans la file.
  ///
  /// ⚠️ **Appelé APRÈS un vidage, jamais pendant.** Un dépôt quitte la file
  /// quand le serveur l'a accusé ; c'est à ce moment seulement que sa copie ne
  /// sert plus. Effacer plus tôt perdrait la pièce si la réponse s'égarait.
  ///
  /// ⚠️ Les dépôts **refusés** gardent leur copie. L'adhérent doit pouvoir
  /// regarder ce que le cabinet n'a pas pris : effacer une pièce refusée en même
  /// temps qu'une pièce reçue reviendrait à traiter les deux comme réglées.
  Future<int> effacerLesCopiesDevenuesInutiles() async {
    if (!await photos.exists()) {
      return 0;
    }
    final vivants = {
      for (final depot in await file.tous()) depot.cheminDuFichier,
    };
    var effacees = 0;
    await for (final entree in photos.list()) {
      if (entree is File && !vivants.contains(entree.path)) {
        try {
          await entree.delete();
          effacees++;
        } on Object {
          // Un fichier qu'on n'arrive pas à effacer n'est pas une panne : il
          // sera repris au prochain passage.
        }
      }
    }
    return effacees;
  }
}
