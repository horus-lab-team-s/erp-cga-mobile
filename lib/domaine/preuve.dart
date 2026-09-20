/// L'envoi d'une quittance, et ce qu'elle acquitte.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ CE QUE CE GESTE N'EST PAS
///
/// Ce n'est pas un paiement. L'application ne sait pas encaisser, et le serveur
/// non plus pour un adhérent : il n'existe ni permission ni route pour cela, et
/// le code du serveur le note lui-même comme une question ouverte.
///
/// C'est l'adhérent qui a payé, ailleurs — au guichet, par Mobile Money, par
/// virement — et qui en apporte la preuve. Le cabinet la vérifie, puis consigne
/// le dépôt s'il y a lieu. Dire « payer » ici serait promettre ce qu'on ne fait
/// pas.
///
/// ⚠️ ET CE N'EST PAS NON PLUS UN DÉPÔT D'OBLIGATION. Consigner un dépôt reste
/// l'acte d'un collaborateur habilité, qui lit la quittance et la joint à
/// l'accusé. Une quittance illisible, ou d'un autre trimestre, ne règle rien.
/// L'adhérent lit « le cabinet la vérifie », jamais « réglé ».
/// ─────────────────────────────────────────────────────────────────────────────
library;

/// Ce que l'envoi d'une preuve a produit.
enum Preuve {
  /// Le cabinet l'a reçue, et la vérifiera.
  recue,

  /// Le serveur a refusé, et il ne changera pas d'avis : obligation absente de
  /// l'échéancier, obligation déjà déposée, ou preuve déjà envoyée pour cette
  /// période. ⚠️ Réessayer ne sert à rien, et l'écran doit le dire.
  refusee,

  /// La session n'est plus valable : il faut se reconnecter.
  sessionExpiree,

  /// Rien n'a abouti : pas de réseau, serveur injoignable, délai dépassé.
  ///
  /// ⚠️ **LA QUITTANCE N'EST PAS PERDUE POUR AUTANT.** Elle a été déposée comme
  /// pièce ordinaire avant qu'on dise ce qu'elle acquitte ; elle est donc chez
  /// le cabinet, sans son rattachement. C'est ce que l'écran doit expliquer,
  /// faute de quoi l'adhérent photographie une seconde fois.
  indisponible,
}
