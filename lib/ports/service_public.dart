import '../domaine/offre.dart';
import '../domaine/souscription.dart';
import '../domaine/suivi.dart';
import '../domaine/vitrine.dart';

/// Ce que l'application demande au serveur SANS session.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ UN PORT À PART, ET NON TROIS MÉTHODES DE PLUS SUR CELUI DE LA SESSION
///
/// La distinction n'est pas cosmétique : elle dit dans le type ce qui est
/// public. Un écran qui ne dépend que de ce port ne peut pas, par construction,
/// réclamer une connexion ni traiter un 401 — et c'est exactement la faute
/// qu'on veut rendre impossible. L'application s'ouvrait sur un mur de
/// connexion alors que le catalogue, le devis et le paiement sont publics ; le
/// jour où quelqu'un rebranchera un de ces écrans sur le port de session, le
/// compilateur le lui dira.
///
/// ⚠️ Et le sens métier suit : **le compte naît de la souscription réglée**. Le
/// cabinet envoie le lien d'accès une fois le paiement validé. Exiger un compte
/// pour voir l'offre demanderait d'avoir acheté pour savoir ce qu'on achète.
/// ─────────────────────────────────────────────────────────────────────────────
abstract class ServicePublic {
  /// Le catalogue, au barème du jour.
  Future<Offre> offreDuJour();

  /// Chiffre ce que le prospect a coché, au barème du jour.
  Future<Demarche<Devis>> etablirUnDevis({
    required Prospect prospect,
    required List<String> services,
  });

  /// Demande le paiement mobile d'un devis.
  ///
  /// ⚠️ Le paiement n'est pas fait au retour de cet appel : le serveur a
  /// seulement envoyé une demande sur le téléphone du prospect. L'écran doit
  /// dire « validez avec votre code », jamais « c'est réglé ».
  Future<Demarche<Engagement>> reglerLeDevis(String reference);

  /// Demande au cabinet d'arrêter le prix d'un devis qui ne se règle pas en
  /// ligne (prix pas encore fixé par le gérant, ou ligne sur étude).
  ///
  /// ⚠️ Seule la RÉFÉRENCE part : le serveur reprend le nom, le numéro et le
  /// courriel du devis. La valeur rendue est le message du serveur, à afficher
  /// tel quel : il dit à quel numéro le client sera rappelé.
  Future<Demarche<String>> demanderLeRappelDuDevis(String reference);

  /// Où en est une souscription. Publique : la référence est longue et non
  /// devinable, et le souscripteur n'a pas encore de compte — il n'en aura un
  /// que si tout aboutit.
  Future<LectureDuSuivi> suivreUneSouscription(String reference);

  /// Les mensualités d'un abonnement, jusqu'à une date. `null` : le serveur
  /// n'a pas répondu. Vide : l'abonnement n'a pas encore pris effet.
  Future<List<Mensualite>?> mensualites(String reference, DateTime jusquAu);

  /// Demande un lien de réinitialisation du mot de passe.
  ///
  /// ⚠️ VRAI NE VEUT PAS DIRE « UN LIEN EST PARTI ». Le serveur répond 202
  /// dans tous les cas, y compris pour une adresse inconnue : répondre
  /// autrement offrirait un moyen d'énumérer les clients du cabinet. Vrai veut
  /// dire « la demande est prise » ; faux, « le serveur ne l'a pas reçue » —
  /// pas de réseau, ou adresse mal formée. L'écran doit parler en conséquence.
  Future<bool> demanderUnLienDeReinitialisation(String courriel);

  // ── Ce que publie la vitrine ──────────────────────────────────────────────

  /// L'offre que le cabinet met en avant aujourd'hui. `null` s'il n'y en a
  /// pas, ou si le serveur ne répond pas.
  ///
  /// ⚠️ Les deux cas se confondent VOLONTAIREMENT : un bandeau promotionnel
  /// est un bonus. Afficher « pas de réseau » à sa place ferait crier l'écran
  /// pour une information dont personne n'a besoin pour agir.
  Future<Annonce?> annonceDuJour();

  /// Le sommaire du blog. `null` : le serveur n'a pas répondu, et l'écran
  /// doit le distinguer d'un blog vide.
  Future<List<Article>?> articles();

  /// Un article et ses voisins de lecture. `null` : introuvable ou pas de
  /// réseau.
  Future<ArticleComplet?> article(String slug);

  /// Les institutions dans le cadre desquelles le cabinet exerce. Vide si le
  /// serveur ne répond pas : la section se tait plutôt que d'afficher une
  /// erreur au milieu de la page d'accueil.
  Future<List<Institution>> institutions();

  /// L'adresse d'une image publiée par la vitrine, à partir de son chemin.
  ///
  /// ⚠️ Les articles portent « /images/pages/cabinet-a.jpg », un chemin du
  /// SITE. Seul l'adaptateur sait où le site est servi — sur le téléphone de
  /// démonstration, en production — ; l'écran ne doit pas l'écrire en dur.
  Uri imageDeLaVitrine(String chemin);
}
