import 'package:flutter/material.dart';

import '../../composants/carte.dart';
import '../../domaine/offre.dart';

/// La photo d'un service : la même que sur la vitrine, pour le même service.
///
/// ⚠️ Rattachée au CODE du barème et non au libellé : le libellé change (« Suivi
/// comptable et fiscal — adhésion au centre agréé »), le code ne change pas.
/// Un service nouveau, sans photo, s'affiche sans : `null` plutôt qu'une image
/// qui ne serait pas la sienne.
String? photoDuService(String code) => switch (code) {
  'ADHESION' => 'assets/photos/service-suivi-comptable.jpg',
  'DOMICILIATION' => 'assets/photos/service-domiciliation.jpg',
  'FORMATION' => 'assets/photos/service-formations.jpg',
  'CREATION' => 'assets/photos/service-creation-entreprise.jpg',
  'PONCTUEL' => 'assets/photos/service-prestations-ponctuelles.jpg',
  _ => null,
};

/// Une prestation : son prix d'abord, le reste ensuite.
///
/// ⚠️ LA PHOTO EST EN TÊTE, ET BASSE : 132 points. Elle dit en un coup d'œil
/// de quoi parle la carte — une devanture pour la domiciliation, une salle
/// pour la formation — avant qu'on lise le titre. Plus haute, elle pousserait
/// le prix sous la ligne de flottaison, et le prix est ce qu'on vient chercher.
class CarteService extends StatelessWidget {
  const CarteService({
    super.key,
    required this.service,
    required this.surSouscrire,
  });

  final Service service;

  /// `null` quand la prestation ne se souscrit pas en ligne.
  final VoidCallback? surSouscrire;

  @override
  Widget build(BuildContext context) {
    final s = service;
    final couleurs = Theme.of(context).colorScheme;
    final prix = s.aPartirDe(DateTime.now());
    final aFormules = s.formules.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Carte(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photoDuService(s.code) case final photo?)
              SizedBox(
                height: 132,
                width: double.infinity,
                child: Image.asset(
                  photo,
                  fit: BoxFit.cover,
                  // Décorative : le titre dit la même chose, en mots.
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: couleurs.secondaryContainer),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.libelle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: couleurs.onSurface,
                    ),
                  ),
                  if (s.resume != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      s.resume!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: couleurs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Le prix, en grand ────────────────────────────────────
                  // ⚠️ QUAND IL N'Y A PAS DE PRIX, ON LE DIT — MAIS UNE SEULE
                  // FOIS.
                  //
                  // La version d'avant n'affichait rien : la carte passait du
                  // résumé au bouton sans un mot sur le montant, et le
                  // prospect ne savait pas s'il manquait une information.
                  //
                  // La correction a d'abord fait pire. Sur le téléphone, la
                  // carte de la création d'entreprise disait coup sur coup
                  // « Montant établi après étude de votre dossier » puis « Le
                  // cabinet vous adresse une proposition après examen de votre
                  // dossier ». Deux phrases pour une seule idée : le lecteur
                  // relit la seconde en cherchant ce qu'elle ajoute.
                  //
                  // Ici, on dit le FAIT MONÉTAIRE, et rien d'autre. Le
                  // chemin — « le cabinet examine, puis vous adresse une
                  // proposition » — est écrit une seule fois, sous le titre de
                  // la section qui rassemble ces prestations.
                  if (prix == null)
                    Row(
                      children: [
                        Icon(
                          Icons.calculate_outlined,
                          size: 18,
                          color: couleurs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Montant établi après étude de votre dossier.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: couleurs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      ],
                    ),
                  // ⚠️ UN `Wrap`, ET NON UNE `Row`.
                  //
                  // La `Row` débordait de 62 px à 360 px de large : « dès »,
                  // le montant en 28 px et son rythme ne tiennent pas sur une
                  // ligne dès que le montant passe à six chiffres — « 180 000 F
                  // par an » pour la domiciliation. Le téléphone d'essai ne l'a
                  // pas montré parce que la carte fautive était sous la ligne
                  // de flottaison, et parce que le montant affiché était alors
                  // « 0 F », c'est-à-dire l'autre défaut.
                  //
                  // Avec un `Wrap`, le rythme passe à la ligne au lieu de se
                  // faire couper. On perd l'alignement sur la ligne de base des
                  // lettres, remplacé par un alignement sur le bas : à l'œil,
                  // sur deux tailles de police aussi éloignées, la différence
                  // ne se voit pas, et un prix coupé se voit.
                  if (prix != null)
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        // « À partir de » seulement quand il y a des formules :
                        // le prix dépend alors du chiffre d'affaires, et
                        // annoncer celui d'une tranche ferait croire à un
                        // forfait.
                        if (aFormules)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'dès',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: couleurs.onSurfaceVariant),
                            ),
                          ),
                        Text(
                          enFrancs(prix.montant),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: couleurs.primary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            s.rythme,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: couleurs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),

                  // ⚠️ UN PRIX QUE LE GÉRANT N'A PAS FIXÉ SE DIT INDICATIF.
                  //
                  // Le prix est une décision humaine. Tant que la direction du
                  // cabinet ne l'a pas arrêté, le montant vient du catalogue de
                  // démonstration : il renseigne, il n'engage pas, et le
                  // serveur refuse de l'encaisser.
                  //
                  // On affichait à la place le motif brut du serveur — « ⚠️
                  // Tarif reconstitué — voir l'en-tête du module » —, une note
                  // de développeur qu'aucun prospect ne peut comprendre.
                  if (prix != null && !prix.fixe) ...[
                    const SizedBox(height: 8),
                    // Empilés et non côte à côte : en gros caractères, l'étiquette
                    // et la phrase débordaient de 63 points sur la même ligne.
                    Column(
                      key: Key('indicatif-${s.code}'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Etiquette('Tarif indicatif'),
                        const SizedBox(height: 4),
                        Text(
                          'Le cabinet confirme ce prix avant tout paiement.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],

                  // ⚠️ UN BARÈME, ET NON DES PASTILLES.
                  //
                  // Les tranches s'affichaient en pastilles portant leur seul
                  // libellé : « Impôt libératoire », « Réel simplifié »,
                  // « Régime du réel ». Elles ne disaient ni à quel chiffre
                  // d'affaires elles s'adressent, ni combien elles coûtent —
                  // or c'est exactement ce que le commerçant vient chercher.
                  // Il lui fallait appeler le cabinet pour savoir laquelle est
                  // la sienne.
                  //
                  // Le serveur porte les deux : les bornes de chiffre
                  // d'affaires et le tarif de chaque tranche. On les met en
                  // face l'un de l'autre.
                  if (aFormules) ...[
                    const SizedBox(height: 16),
                    _Bareme(service: s),
                  ],
                ],
              ),
            ),

            // ⚠️ PAS DE BOUTON GRISÉ, ET PAS DE PHRASE DE REMPLACEMENT NON
            // PLUS.
            //
            // Un bouton inerte invite à appuyer et laisse croire à une panne :
            // ces prestations ne sont pas indisponibles, elles suivent un
            // autre chemin. On y mettait donc une phrase — « le cabinet vous
            // adresse une proposition après examen de votre dossier ». Sur le
            // téléphone, cette phrase se lisait juste après l'intertitre
            // « Sur étude », qui dit déjà la même chose, et juste après la
            // ligne « Montant établi après étude ». Trois fois la même idée
            // sur un demi-écran : le lecteur relit en cherchant la différence.
            //
            // La carte ne garde donc que le fait monétaire, et le chemin reste
            // écrit une seule fois, sous le titre de la section.
            if (surSouscrire != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: Key('souscrire-${s.code}'),
                    onPressed: surSouscrire,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Souscrire'),
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

/// Les tranches d'un service, en face de leur prix.
class _Bareme extends StatelessWidget {
  const _Bareme({required this.service});
  final Service service;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final aujourdHui = DateTime.now();
    // ⚠️ Un `Bloc` et non une seconde carte : un barème est posé DANS la carte
    // du service. Une ombre dans une ombre donne un empilement sale.
    return Bloc(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, f) in service.formules.indexed)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                border: Border(
                  top: i == 0
                      ? BorderSide.none
                      : BorderSide(color: couleurs.outlineVariant),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.libelle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: couleurs.onSurface,
                                height: 1.3,
                              ),
                        ),
                        if (f.bornes.isNotEmpty)
                          Text(
                            f.bornes,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: couleurs.onSurfaceVariant,
                                  height: 1.35,
                                ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ⚠️ La tranche sans montant écrit « sur étude ». Elle ne
                  // laisse pas la colonne vide : un blanc se lirait comme une
                  // donnée manquante.
                  Builder(
                    builder: (_) {
                      final t = f.prixLe(aujourdHui);
                      if (t == null) {
                        return Text(
                          'sur étude',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: couleurs.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                        );
                      }
                      return Text(
                        enFrancs(t.montant!),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: couleurs.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// « 12 500 F » : tranches de trois, séparées par une espace.
String enFrancs(double v) {
  final entier = v.round().toString();
  final tranches = <String>[];
  for (var fin = entier.length; fin > 0; fin -= 3) {
    tranches.insert(0, entier.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
  }
  return '${tranches.join(' ')} F';
}
