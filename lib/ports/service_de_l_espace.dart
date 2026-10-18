import '../domaine/fonds_confies.dart';
import '../domaine/honoraires.dart';
import '../domaine/ma_dsf.dart';
import '../domaine/ma_paie.dart';
import 'service_des_fichiers.dart';

/// Ce qu'il faut savoir d'une lecture : la valeur, ou pourquoi elle manque.
///
/// ⚠️ « Pas de réseau » et « session expirée » ne se disent pas pareil à
/// l'adhérent : l'un appelle « réessayer », l'autre « se reconnecter ».
class Lecture<T> {
  const Lecture.lue(T this.valeur)
    : sessionAExpire = false,
      serveurJoignable = true;
  const Lecture.sessionExpiree()
    : valeur = null,
      sessionAExpire = true,
      serveurJoignable = true;
  const Lecture.injoignable()
    : valeur = null,
      sessionAExpire = false,
      serveurJoignable = false;

  final T? valeur;
  final bool sessionAExpire;
  final bool serveurJoignable;
}

/// Le sort d'une pièce versée à la DSF.
enum SortDuVersement {
  recue,
  refusee,
  tropLourde,
  formatRefuse,
  sessionExpiree,
  indisponible,
}

/// Les écrans de l'espace adhérent ajoutés le 18 octobre 2026 : honoraires, DSF,
/// paie, et la lecture d'un document servi par une route.
///
/// ⚠️ UN PORT À PART, et non trois méthodes de plus sur `ServiceDeSession` : les
/// doublures de test existantes n'ont pas à les connaître pour compiler.
abstract class ServiceDeLEspace {
  Future<Lecture<MesHonoraires>> mesHonoraires(String dossier);

  /// Demande le débit mobile money d'une période. Rien n'est réglé ici.
  Future<DemandeDeDebit> demanderLeDebit({
    required String dossier,
    required String periode,
    required String telephone,
  });

  Future<Lecture<MaDsf>> maDsf(String dossier);

  Future<SortDuVersement> verserUnePieceDsf({
    required String dossier,
    required String exercice,
    required int numero,
    required String cheminDuFichier,
  });

  Future<Lecture<MaPaie>> maPaie(
    String dossier, {
    required int annee,
    required int mois,
  });

  /// Les échéances que le cabinet paie pour l'adhérent, et leurs appels de fonds.
  Future<Lecture<FondsConfies>> mesFondsConfies(String dossier);

  /// Remettre ses fonds au cabinet par mobile money, pour un appel. Rien n'est
  /// payé ici : la notification de l'opérateur constate les fonds.
  Future<DemandeDeDebit> confierSesFonds({
    required String dossier,
    required String appel,
    required String telephone,
  });

  /// Un PDF servi par une route : note, reçu, facture, DSF déposée.
  Future<FichierLu> lireUnDocument(String chemin);
}

/// Ce que la visionneuse attend, branché sur un document servi par une route.
///
/// ⚠️ La visionneuse demande « un fichier » par une clé ; ici la clé est le
/// chemin de la route. Elle n'a pas à savoir d'où vient le PDF.
class DocumentsDeLEspace implements ServiceDesFichiers {
  const DocumentsDeLEspace(this.espace);

  final ServiceDeLEspace espace;

  @override
  Future<FichierLu> lireLeFichier(String chemin) =>
      espace.lireUnDocument(chemin);
}
