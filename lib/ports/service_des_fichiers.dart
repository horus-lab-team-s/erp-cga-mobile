import 'dart:typed_data';

/// Ce que le serveur rend quand on lui demande le fichier d'une pièce.
class FichierLu {
  const FichierLu({
    this.octets,
    this.type,
    this.serveurJoignable = true,
    this.sessionAExpire = false,
    this.introuvable = false,
  });

  final Uint8List? octets;

  /// Le type annoncé par le serveur (« application/pdf », « image/jpeg »).
  /// ⚠️ C'est lui qui décide du rendu, pas l'extension du nom de fichier :
  /// une photo nommée « scan.pdf » par un vieux téléphone existe.
  final String? type;
  final bool serveurJoignable;
  final bool sessionAExpire;

  /// 404 : la pièce n'existe pas, ou n'est pas dans le dossier de l'adhérent.
  final bool introuvable;

  bool get estUnPdf => type?.startsWith('application/pdf') ?? false;
  bool get estUneImage => type?.startsWith('image/') ?? false;
}

/// La lecture du fichier d'une pièce déjà déposée.
///
/// ⚠️ UN PORT À PART, pour la même raison que celui de l'accueil : le port de
/// session a sept doublures de test, et un seul écran lit des fichiers.
abstract class ServiceDesFichiers {
  Future<FichierLu> lireLeFichier(String piece);
}
