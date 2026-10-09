import 'package:cga_mobile/domaine/offre.dart';
import 'package:cga_mobile/domaine/souscription.dart';
import 'package:cga_mobile/domaine/suivi.dart';
import 'package:cga_mobile/domaine/vitrine.dart';
import 'package:cga_mobile/ports/service_public.dart';

/// Un serveur public de test, partagé par tous les cas.
///
/// ⚠️ UN SEUL, ET NON UN PAR FICHIER DE TEST. Chaque fichier avait le sien :
/// ajouter une méthode au port en cassait autant qu'il y avait de copies, et
/// l'une finissait toujours par se comporter autrement que les autres.
///
/// Chaque réponse se règle à la construction ; ce qui n'est pas réglé rend le
/// cas « le serveur ne répond pas » de la méthode.
class PublicFeint implements ServicePublic {
  PublicFeint({
    this.offre = const Offre(),
    this.annonce,
    this.lesArticles,
    this.articlesComplets = const {},
    this.lesInstitutions = const [],
    this.lienAccepte = true,
    this.suivi = const LectureDuSuivi(SortDuSuivi.introuvable),
    this.lesMensualites = const [],
  });

  LectureDuSuivi suivi;
  List<Mensualite>? lesMensualites;
  final suivisDemandes = <String>[];

  @override
  Future<LectureDuSuivi> suivreUneSouscription(String reference) async {
    suivisDemandes.add(reference);
    return suivi;
  }

  @override
  Future<List<Mensualite>?> mensualites(
    String reference,
    DateTime jusquAu,
  ) async => lesMensualites;

  /// Ce que rend la demande de lien : vrai, la demande est prise.
  bool lienAccepte;

  /// Les adresses pour lesquelles un lien a été demandé.
  final liensDemandes = <String>[];

  @override
  Future<bool> demanderUnLienDeReinitialisation(String courriel) async {
    liensDemandes.add(courriel);
    return lienAccepte;
  }

  Offre offre;
  Annonce? annonce;
  List<Article>? lesArticles;
  Map<String, ArticleComplet> articlesComplets;
  List<Institution> lesInstitutions;

  /// Les slugs demandés, dans l'ordre : pour vérifier qu'un appui ouvre le bon
  /// article.
  final articlesDemandes = <String>[];

  @override
  Future<Offre> offreDuJour() async => offre;

  @override
  Future<Demarche<Devis>> etablirUnDevis({
    required Prospect prospect,
    required List<String> services,
  }) async => const Demarche(sort: SortDeLaDemarche.fait);

  @override
  Future<Demarche<Engagement>> reglerLeDevis(String reference) async =>
      const Demarche(sort: SortDeLaDemarche.fait);

  /// Les devis dont le rappel a été demandé, dans l'ordre.
  final rappelsDemandes = <String>[];

  /// Ce que le faux serveur répond à une demande de rappel.
  Demarche<String> reponseAuRappel = const Demarche(
    sort: SortDeLaDemarche.fait,
    valeur: 'Votre demande est transmise au cabinet.',
  );

  @override
  Future<Demarche<String>> demanderLeRappelDuDevis(String reference) async {
    rappelsDemandes.add(reference);
    return reponseAuRappel;
  }

  @override
  Future<Annonce?> annonceDuJour() async => annonce;

  @override
  Future<List<Article>?> articles() async => lesArticles;

  @override
  Future<ArticleComplet?> article(String slug) async {
    articlesDemandes.add(slug);
    return articlesComplets[slug];
  }

  @override
  Future<List<Institution>> institutions() async => lesInstitutions;

  @override
  Uri imageDeLaVitrine(String chemin) =>
      Uri.parse('http://vitrine.invalid').resolve(chemin);
}
