import 'package:clock/clock.dart';

import '../ports/memoire_des_lectures.dart';
import 'echeance.dart';
import 'honoraires.dart';

/// Un rappel posé sur le téléphone, à une heure de Douala.
class Rappel {
  const Rappel({required this.le, required this.titre, required this.texte});

  /// L'heure du rappel, À DOUALA : une heure « murale », sans fuseau. C'est
  /// l'adaptateur du système qui la pose dans le fuseau du Cameroun (UTC+1).
  final DateTime le;
  final String titre;
  final String texte;
}

/// Où les rappels se posent : les notifications du système, ou rien en essai.
abstract class PlanificateurDeRappels {
  /// Demande à Android 13 et suivants la permission d'afficher des notifications.
  /// Vrai : accordée (ou inutile sur un système plus ancien).
  Future<bool> demanderLaPermission();

  /// Remplace TOUS les rappels posés par ceux-ci. Une liste vide les retire.
  Future<void> programmer(List<Rappel> rappels);
}

/// Les rappels des échéances, posés sur le téléphone (20 octobre 2026).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ DES RAPPELS LOCAUX, ET NON DES NOTIFICATIONS DU SERVEUR.
///
/// Il n'y a pas de service de messagerie poussée derrière cette application, et
/// il n'en faut pas : ce qu'il y a à rappeler, l'application le LIT déjà. À chaque
/// lecture des échéances ou des honoraires, elle pose un rappel trois jours avant
/// et la veille de chaque échéance à payer, à 9 h, heure de Douala. Sans réseau,
/// les rappels déjà posés restent : c'est précisément le jour où l'on n'ouvre pas
/// l'application qu'ils servent.
///
/// ⚠️ ARRÊTÉS PAR DÉFAUT, ET LA PERMISSION SE DEMANDE AU GESTE. Une boîte « Autoriser
/// les notifications ? » surgie à l'ouverture se refuse par réflexe, et Android ne
/// la repose plus. Elle se demande quand l'adhérent active les rappels, dans
/// « Mon espace », avec la phrase qui dit à quoi ils servent.
///
/// ⚠️ ET ILS PARTENT À LA DÉCONNEXION, avec le réglage : les échéances d'un
/// adhérent n'ont pas à sonner sur le téléphone que la boutique prête à un autre.
/// ─────────────────────────────────────────────────────────────────────────────
class Rappels {
  Rappels({required this.planificateur, this.memoire});

  final PlanificateurDeRappels planificateur;

  /// Où le réglage survit : la mémoire des lectures, qui se vide à la déconnexion.
  final MemoireDesLectures? memoire;

  static const _cleDuReglage = 'reglage/rappels';

  /// L'heure des rappels : 9 h, la boutique est ouverte et le téléphone en main.
  static const heure = 9;

  /// Au-delà, Android refuse de poser d'autres alarmes pour l'application.
  static const plafond = 48;

  bool? _actifs;
  final _echeances = <String, List<Echeance>>{};
  final _honoraires = <String, MesHonoraires>{};

  /// Le réglage tel qu'il est gardé. Arrêtés tant que l'adhérent n'a rien dit.
  Future<bool> actifs() async {
    final connu = _actifs;
    if (connu != null) return connu;
    final lu = await memoire?.lire(_cleDuReglage);
    return _actifs = lu?.corps == 'oui';
  }

  /// Active les rappels, après la permission du système. Faux : refusée.
  Future<bool> activer() async {
    if (!await planificateur.demanderLaPermission()) return false;
    _actifs = true;
    await memoire?.retenir(_cleDuReglage, 'oui', clock.now());
    await _reprogrammer();
    return true;
  }

  Future<void> desactiver() async {
    _actifs = false;
    await memoire?.retenir(_cleDuReglage, 'non', clock.now());
    await planificateur.programmer(const []);
  }

  /// La déconnexion : plus rien ne sonne, et le prochain compte repart arrêté.
  Future<void> oublier() async {
    _actifs = null;
    _echeances.clear();
    _honoraires.clear();
    await planificateur.programmer(const []);
  }

  /// Une lecture des échéances vient d'aboutir : les rappels se recalculent.
  Future<void> retenirLesEcheances(String dossier, Echeancier lue) async {
    if (!lue.serveurJoignable || lue.sessionAExpire) return;
    _echeances[dossier] = lue.echeances;
    await _reprogrammer();
  }

  Future<void> retenirLesHonoraires(String dossier, MesHonoraires lus) async {
    _honoraires[dossier] = lus;
    await _reprogrammer();
  }

  Future<void> _reprogrammer() async {
    if (!await actifs()) return;
    await planificateur.programmer(
      rappelsAPoser(
        echeances: [for (final l in _echeances.values) ...l],
        honoraires: _honoraires.values.toList(),
        maintenant: clock.now(),
      ),
    );
  }
}

/// Les rappels à poser : J-3 et J-1 de chaque échéance à payer, à 9 h.
///
/// ⚠️ « À PAYER » : une échéance À VENIR, et une période d'honoraires à régler ou à
/// venir. Une échéance déjà en retard n'a plus de veille, et l'écran la crie déjà ;
/// une preuve envoyée, des fonds reçus ou un dépôt fait n'attendent plus rien de
/// l'adhérent.
List<Rappel> rappelsAPoser({
  required List<Echeance> echeances,
  required List<MesHonoraires> honoraires,
  required DateTime maintenant,
}) {
  final rappels = <Rappel>[];
  void poser(DateTime limite, String objet) {
    for (final avant in const [3, 1]) {
      final jour = limite.subtract(Duration(days: avant));
      final le = DateTime(jour.year, jour.month, jour.day, Rappels.heure);
      if (!le.isAfter(maintenant)) continue;
      rappels.add(
        Rappel(
          le: le,
          titre: avant == 1 ? 'Échéance demain' : 'Échéance dans $avant jours',
          texte: '$objet : à payer avant le ${_jour(limite)}.',
        ),
      );
    }
  }

  for (final e in echeances) {
    if (e.etat != EtatPourLAdherent.aVenir) continue;
    poser(e.echeanceLe, '${e.titre} · ${e.periode}');
  }
  for (final h in honoraires) {
    for (final p in h.periodes) {
      if (p.etat != EtatDHonoraires.aRegler &&
          p.etat != EtatDHonoraires.aVenir) {
        continue;
      }
      poser(p.exigibleLe, 'Honoraires du cabinet · ${_mois(p.debut)}');
    }
  }
  rappels.sort((a, b) => a.le.compareTo(b.le));
  return rappels.take(Rappels.plafond).toList();
}

const _mots = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String _jour(DateTime d) =>
    '${d.day == 1 ? '1er' : d.day} ${_mots[d.month - 1]} ${d.year}';

String _mois(DateTime d) => '${_mots[d.month - 1]} ${d.year}';
