import '../domaine/depot.dart';
import '../ports/magasin.dart';

/// Un magasin qui ne survit pas à la fermeture de l'application.
///
/// ⚠️ **Pour les tests et la première maquette, jamais pour l'appareil.** Une
/// file qui disparaît au redémarrage perd exactement ce que cette application
/// existe pour ne pas perdre. Le magasin durable est ce qui reste à écrire, et
/// c'est le premier point de la feuille de route du README.
class MagasinEnMemoire implements MagasinDeDepots {
  final Map<String, Depot> _depots = {};

  @override
  Future<List<Depot>> tous() async {
    final liste = _depots.values.toList()
      ..sort((a, b) => a.prisLe.compareTo(b.prisLe));
    return liste;
  }

  @override
  Future<void> ranger(Depot depot) async {
    _depots[depot.identifiant] = depot;
  }

  @override
  Future<void> oublier(String identifiant) async {
    _depots.remove(identifiant);
  }
}
