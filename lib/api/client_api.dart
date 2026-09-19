import 'dart:convert';
import 'dart:io';

/// Le lien avec le serveur.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI `dart:io` ET PAS UNE BIBLIOTHÈQUE HTTP
///
/// Le client HTTP de la plateforme suffit à ce que fait cette application :
/// quelques routes, un cookie de session, un envoi de fichier. Une dépendance de
/// plus, c'est une chaîne d'approvisionnement de plus à surveiller, et sur un
/// produit qui manipule la comptabilité d'un tiers, ce n'est pas un détail. Le
/// jour où le besoin dépassera ce fichier, il sera temps.
///
/// ⚠️ LE LOCATAIRE SE DIT PAR LE SOUS-DOMAINE, COMME PARTOUT
///
/// Le serveur résout le locataire à l'entrée, une fois, depuis le nom d'hôte.
/// L'application ne l'envoie donc pas dans un en-tête à elle : elle parle à
/// `https://<cabinet>.cga-brcg.cm`, et c'est tout. Poser le locataire ailleurs
/// ouvrirait deux vérités sur la même requête, et c'est exactement le défaut que
/// le socle multi-locataire du serveur a été construit pour rendre impossible.
/// ─────────────────────────────────────────────────────────────────────────────
class ClientApi {
  ClientApi({required this.base});

  /// L'adresse du serveur, sous-domaine du cabinet compris.
  ///
  /// Se règle à la compilation, pour qu'une version de démonstration ne puisse
  /// pas se retrouver branchée sur la production par un fichier de réglage
  /// oublié :
  ///
  /// ```
  /// flutter run --dart-define=CGA_API=http://10.0.2.2:8010
  /// ```
  ///
  /// ⚠️ `10.0.2.2` et non `localhost` : dans l'émulateur Android, `localhost`
  /// désigne l'émulateur lui-même, et l'appel ne sort jamais de l'appareil.
  static const String adresseParDefaut = String.fromEnvironment(
    'CGA_API',
    defaultValue: 'http://10.0.2.2:8010',
  );

  final Uri base;

  /// Le cookie de session, tel que le serveur l'a posé. ⚠️ Gardé en mémoire
  /// seulement : l'écrire sur le disque demanderait le magasin protégé du
  /// système, et le faire à moitié vaut moins que ne pas le faire.
  String? _session;

  bool get connecte => _session != null;

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  /// Ouvre une session. Rend vrai si le serveur a reconnu le compte.
  Future<bool> ouvrirUneSession(String courriel, String motDePasse) async {
    final requete = await _client.postUrl(base.resolve('/transverse/session'));
    requete.headers.contentType = ContentType.json;
    requete.write(jsonEncode({
      'courriel': courriel,
      'mot_de_passe': motDePasse,
    }));
    final reponse = await requete.close();
    await reponse.drain<void>();
    if (reponse.statusCode != HttpStatus.ok) {
      return false;
    }
    final cookies = reponse.cookies;
    if (cookies.isEmpty) {
      return false;
    }
    _session = '${cookies.first.name}=${cookies.first.value}';
    return true;
  }

  /// Ferme la session côté serveur, puis l'oublie ici.
  ///
  /// ⚠️ Dans cet ordre, et l'oubli a lieu même si l'appel échoue. Garder un
  /// jeton dont on ne sait plus s'il vaut encore ne sert à rien et laisse
  /// l'application dans un état qu'aucun écran ne sait montrer.
  Future<void> fermerLaSession() async {
    try {
      final requete =
          await _client.deleteUrl(base.resolve('/transverse/session'));
      _poserLaSession(requete);
      final reponse = await requete.close();
      await reponse.drain<void>();
    } on Object {
      // Sans réseau, la session expirera d'elle-même côté serveur.
    } finally {
      _session = null;
    }
  }

  /// Lit une route et rend son corps décodé, ou rien si le serveur n'a pas
  /// répondu 200.
  Future<Object?> lire(String chemin) async {
    final requete = await _client.getUrl(base.resolve(chemin));
    _poserLaSession(requete);
    final reponse = await requete.close();
    final corps = await reponse.transform(utf8.decoder).join();
    if (reponse.statusCode != HttpStatus.ok) {
      return null;
    }
    return jsonDecode(corps);
  }

  void _poserLaSession(HttpClientRequest requete) {
    final session = _session;
    if (session != null) {
      requete.headers.add(HttpHeaders.cookieHeader, session);
    }
  }

  void fermer() => _client.close(force: true);
}
