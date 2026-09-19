import 'dart:io';

import '../domaine/depot.dart';
import '../domaine/file_d_attente.dart';
import 'client_api.dart';

/// Remettre un justificatif au serveur, en deux temps.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// LE PROTOCOLE EST CELUI DU SERVEUR, PAS CELUI QU'ON AURAIT IMAGINÉ
///
/// 1. `POST /collecte/fichiers?entreprise=NIU` envoie les octets et rend une
///    **empreinte**, calculée par le serveur sur ce qu'il a reçu.
/// 2. `POST /collecte/pieces` crée la pièce en citant cette empreinte. Le
///    serveur la **revérifie** : il relit le fichier et recalcule. Une clé
///    inventée est refusée, et une divergence signalerait une corruption de son
///    magasin.
///
/// ⚠️ C'EST DE LÀ QUE VIENT L'IDEMPOTENCE, ET PAS DE L'IDENTIFIANT DE L'APPAREIL.
///
/// L'identifiant posé sur le téléphone ne quitte jamais le téléphone. Deux
/// envois des mêmes octets sur le même dossier produisent la même empreinte,
/// donc la même clé de pièce, et le second rend la pièce **inchangée** en 200
/// avec `rejeu: true`. Un envoi dont la réponse s'est perdue peut donc être
/// rejoué sans faire entrer deux fois la même facture en comptabilité.
///
/// Mieux vaut cette propriété-là : elle ne dépend pas d'un numéro que le client
/// pourrait se tromper de recopier.
/// ─────────────────────────────────────────────────────────────────────────────
class Remise {
  const Remise(this.client);

  final ClientApi client;

  /// Tente une remise, et traduit ce que le serveur répond.
  ///
  /// ⚠️ **TOUTE LA VALEUR DE CETTE MÉTHODE EST DANS LA TRADUCTION.** Se tromper
  /// de catégorie, c'est soit jeter une pièce valable, soit tourner en boucle
  /// contre un serveur qui dira toujours non, soit, pour le 401, déclarer
  /// irrécupérables les pièces d'un adhérent qui avait seulement besoin de se
  /// reconnecter.
  Future<Reponse> remettre(Depot depot) async {
    final fichier = File(depot.cheminDuFichier);
    if (!await fichier.exists()) {
      // Le fichier a disparu de l'appareil : la galerie a été vidée, ou le
      // système a repris la place. Réessayer n'y changera rien.
      return Reponse.refuse;
    }
    try {
      final depose = await client.envoyerLeFichier(
        entreprise: depot.dossier,
        fichier: fichier,
      );
      if (depose.reponse != Reponse.accepte) {
        return depose.reponse;
      }
      return await client.creerLaPiece(
        entreprise: depot.dossier,
        empreinte: depose.empreinte!,
        prisLe: depot.prisLe,
      );
    } on SocketException {
      return Reponse.indisponible;
    } on HttpException {
      return Reponse.indisponible;
    } on FormatException {
      // Le serveur a répondu autre chose que du JSON : un portail captif de
      // réseau public, le plus souvent. Ce n'est pas un refus.
      return Reponse.indisponible;
    } on Object {
      return Reponse.indisponible;
    }
  }
}

/// Le résultat de l'envoi des octets : l'empreinte, ou la raison de l'échec.
class FichierDepose {
  const FichierDepose({required this.reponse, this.empreinte});

  final Reponse reponse;
  final String? empreinte;
}

/// La traduction d'un code HTTP en sort pour la file.
///
/// ⚠️ Écrite une seule fois, et employée par les deux appels. Deux tables de
/// correspondance divergent : l'une apprend un code que l'autre ignore, et le
/// même serveur finit par produire deux comportements selon l'étape.
Reponse sortDuCode(int code) {
  if (code >= 200 && code < 300) {
    return Reponse.accepte;
  }
  switch (code) {
    // ⚠️ 200 sur la création d'une pièce : c'est un REJEU, pas une erreur. Il
    // tombe déjà dans la plage ci-dessus ; la ligne est ici pour qu'on ne
    // l'attrape pas par mégarde en ajoutant un cas.
    case HttpStatus.unauthorized:
      return Reponse.sessionExpiree;
    case HttpStatus.forbidden:
    case HttpStatus.notFound:
    case HttpStatus.conflict:
    case HttpStatus.requestEntityTooLarge:
    case HttpStatus.unsupportedMediaType:
    case HttpStatus.unprocessableEntity:
      return Reponse.refuse;
    default:
      // 5xx, 429, et tout ce qu'on n'a pas prévu : on réessaiera.
      //
      // ⚠️ Le défaut penche du côté de « réessayer », et c'est délibéré. Se
      // tromper dans ce sens coûte une tentative de plus ; se tromper dans
      // l'autre jette la pièce d'un adhérent pour un code qu'on n'avait pas
      // anticipé.
      return Reponse.indisponible;
  }
}
