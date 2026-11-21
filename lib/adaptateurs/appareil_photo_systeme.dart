import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../ports/appareil_photo.dart';

/// L'appareil photo du téléphone, tel que le système le propose.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ L'APPAREIL DU SYSTÈME, ET NON UN VISEUR ÉCRIT ICI
///
/// Écrire son propre viseur, c'est refaire la mise au point, le flash, le
/// cadrage et l'orientation, moins bien que le constructeur et différemment sur
/// chaque téléphone. L'adhérent connaît déjà l'appareil de son propre appareil :
/// il l'emploie tous les jours.
///
/// ⚠️ ET LA RÉDUCTION N'EST PAS UNE OPTIMISATION
///
/// Un téléphone récent produit des images de plusieurs dizaines de mégaoctets.
/// Le serveur refuse au-delà de vingt, avec un 413 que la file traduit en
/// « refusé, rien ne changera » — ce qui est exact et désastreux : l'adhérent
/// verrait ses factures rejetées sans comprendre, alors que le cabinet n'a rien
/// refusé du tout.
///
/// Deux mille pixels de large suffisent largement à relire le numéro et le
/// montant d'une facture ; la qualité 85 est le point où la compression cesse
/// de se voir. On reste ainsi à quelques centaines de kilooctets, ce qui fait
/// aussi partir la pièce sur un réseau médiocre.
/// ─────────────────────────────────────────────────────────────────────────────
class AppareilPhotoDuSysteme implements AppareilPhoto {
  AppareilPhotoDuSysteme({ImagePicker? choix})
    : _choix = choix ?? ImagePicker();

  final ImagePicker _choix;

  @override
  Future<String?> photographier() async {
    final pris = await _choix.pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      imageQuality: 85,
      // La caméra arrière : on photographie une facture posée sur un comptoir.
      preferredCameraDevice: CameraDevice.rear,
    );
    return pris?.path;
  }
}

/// La galerie du téléphone : la facture déjà reçue en photo, par WhatsApp ou par
/// courriel, et qu'il serait absurde de rephotographier sur l'écran d'un autre
/// appareil (18 octobre 2026).
///
/// ⚠️ La même réduction que l'appareil photo, pour la même raison : une image de
/// la galerie peut peser autant qu'une photo prise à l'instant.
class GalerieDuSysteme implements AppareilPhoto {
  GalerieDuSysteme({ImagePicker? choix}) : _choix = choix ?? ImagePicker();

  final ImagePicker _choix;

  @override
  Future<String?> photographier() async {
    final pris = await _choix.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    return pris?.path;
  }
}

/// Les fichiers du téléphone : un scan déjà fait, souvent un PDF reçu par
/// courriel ou sorti du scanner du bureau (19 octobre 2026).
///
/// ⚠️ Pas de réduction ici : on ne recompresse pas un PDF. Le poids est contrôlé
/// avant l'aperçu, contre la limite du serveur.
class FichiersDuSysteme implements AppareilPhoto {
  const FichiersDuSysteme();

  @override
  Future<String?> photographier() async {
    final choisi = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    return choisi?.path;
  }
}
