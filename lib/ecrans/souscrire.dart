import 'package:flutter/material.dart';

import '../marque.dart';
import 'package:flutter/services.dart';

import '../composants/carte.dart';
import '../composants/joindre.dart';
import '../contenu/cabinet.dart';
import '../domaine/offre.dart';
import '../domaine/souscription.dart';
import '../ports/service_public.dart';
import 'suivi.dart';

/// Souscrire : qui vous êtes, ce que cela coûte, et le paiement.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ TROIS TEMPS SUR UN SEUL ÉCRAN, ET NON TROIS ÉCRANS
///
/// Un tunnel à trois pages sur un téléphone perd une personne sur deux : on
/// revient en arrière, on perd la saisie, on abandonne. Les trois temps —
/// se nommer, voir le prix, payer — tiennent ici, et l'on ne descend d'un
/// cran que lorsque le précédent est acquis.
///
/// ⚠️ ET RIEN N'EST ACQUIS AVANT LA VALIDATION DU CODE. Le serveur ne fait
/// qu'ENVOYER une demande de paiement sur le téléphone. Écrire « c'est fait »
/// au retour de cet appel laisserait quelqu'un se croire client d'un cabinet
/// qui ne le connaît pas.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranSouscrire extends StatefulWidget {
  const EcranSouscrire({
    super.key,
    required this.servicePublic,
    required this.service,
  });

  final ServicePublic servicePublic;
  final Service service;

  @override
  State<EcranSouscrire> createState() => _EtatDeLaSouscription();
}

class _EtatDeLaSouscription extends State<EcranSouscrire> {
  final _formulaire = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _courriel = TextEditingController();
  final _telephone = TextEditingController();
  final _denomination = TextEditingController();
  final _niu = TextEditingController();
  final _chiffreAffaires = TextEditingController();

  Devis? _devis;
  Engagement? _engagement;
  bool _enCours = false;
  String? _motif;

  @override
  void dispose() {
    for (final c in [
      _nom,
      _prenom,
      _courriel,
      _telephone,
      _denomination,
      _niu,
      _chiffreAffaires,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _aFormules => widget.service.formules.isNotEmpty;

  /// La prestation ouvre un dossier au cabinet : il faut l'entreprise.
  bool get _ouvreUnDossier => widget.service.ouvreUnDossier;

  Future<void> _chiffrer() async {
    if (!_formulaire.currentState!.validate()) return;
    setState(() {
      _enCours = true;
      _motif = null;
    });
    final r = await widget.servicePublic.etablirUnDevis(
      prospect: Prospect(
        nom: _nom.text.trim(),
        prenom: _prenom.text.trim(),
        courriel: _courriel.text.trim(),
        telephone: _telephone.text.trim(),
        denomination: _denomination.text.trim(),
        niu: _ouvreUnDossier
            ? _niu.text.trim().toUpperCase().replaceAll(' ', '')
            : null,
        chiffreAffaires: double.tryParse(
          _chiffreAffaires.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ),
      ),
      services: [widget.service.code],
    );
    if (!mounted) return;
    setState(() {
      _enCours = false;
      _devis = r.valeur;
      _motif = switch (r.sort) {
        SortDeLaDemarche.fait => null,
        SortDeLaDemarche.refuse =>
          r.motif ?? 'Le cabinet n\'a pas pu chiffrer cette demande.',
        SortDeLaDemarche.indisponible =>
          'Pas de réseau : le devis n\'a pas pu être établi.',
      };
    });
  }

  Future<void> _payer() async {
    final d = _devis;
    if (d == null) return;
    setState(() {
      _enCours = true;
      _motif = null;
    });
    final r = await widget.servicePublic.reglerLeDevis(d.reference);
    if (!mounted) return;
    setState(() {
      _enCours = false;
      _engagement = r.valeur;
      _motif = switch (r.sort) {
        SortDeLaDemarche.fait => null,
        SortDeLaDemarche.refuse =>
          r.motif ?? 'Le règlement n\'a pas pu être demandé.',
        SortDeLaDemarche.indisponible =>
          'Pas de réseau : la demande de paiement n\'est pas partie.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.service.libelle, maxLines: 2)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          if (_engagement != null)
            _Confirmation(
              engagement: _engagement!,
              surSuivre: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EcranSuivi(
                    servicePublic: widget.servicePublic,
                    reference: _engagement!.souscription,
                  ),
                ),
              ),
            )
          else ...[
            Form(
              key: _formulaire,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Qui souscrit ?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Champ(clef: 'nom', etiquette: 'Nom', controleur: _nom),
                  _Champ(
                    clef: 'prenom',
                    etiquette: 'Prénom',
                    controleur: _prenom,
                  ),
                  _Champ(
                    clef: 'courriel',
                    etiquette: 'Adresse électronique',
                    controleur: _courriel,
                    clavier: TextInputType.emailAddress,
                    // ⚠️ C'est à cette adresse que partira le lien d'accès une
                    // fois le paiement validé. Une faute ici et le client
                    // n'entre jamais.
                    //
                    // ⚠️ Mais seulement quand la prestation OUVRE un espace. Vu
                    // sur le téléphone : une formation, qui n'en ouvre aucun,
                    // promettait un « lien d'accès » que personne n'enverrait.
                    // L'adresse sert alors à la proposition du cabinet.
                    aide: _ouvreUnDossier
                        ? 'Votre lien d\'accès y sera envoyé.'
                        : 'Votre proposition et votre reçu y seront envoyés.',
                  ),
                  _Champ(
                    clef: 'telephone',
                    etiquette: 'Téléphone',
                    controleur: _telephone,
                    clavier: TextInputType.phone,
                    // ⚠️ C'est sur ce numéro que part la demande de paiement.
                    aide: 'La demande de paiement y sera envoyée.',
                    validation: (v) => (v == null || v.trim().length < 9)
                        ? 'Neuf chiffres au moins'
                        : null,
                  ),
                  _Champ(
                    clef: 'denomination',
                    etiquette: 'Dénomination de l\'entreprise',
                    controleur: _denomination,
                    obligatoire: _ouvreUnDossier,
                  ),
                  if (_ouvreUnDossier) ...[
                    _Champ(
                      clef: 'niu',
                      etiquette: 'NIU de l\'entreprise',
                      controleur: _niu,
                      majuscules: true,
                      aide:
                          'Il figure sur votre carte de contribuable et sur '
                          'vos factures.',
                      // ⚠️ On vérifie la FORME, pas l'existence : un NIU se
                      // lit sur chaque facture, et c'est le cabinet qui
                      // vérifie ensuite que vous représentez l'entreprise.
                      // Refuser ici un NIU bien formé mais inconnu ne
                      // protégerait rien et bloquerait un vrai client.
                      validation: (v) {
                        final n = (v ?? '').trim().replaceAll(' ', '');
                        if (n.isEmpty) {
                          return 'Le NIU est nécessaire pour ouvrir votre '
                              'dossier';
                        }
                        if (n.length < 10 ||
                            !RegExp(r'^[A-Za-z0-9]+$').hasMatch(n)) {
                          return 'Un NIU compte au moins dix lettres et '
                              'chiffres';
                        }
                        return null;
                      },
                    ),
                    // ⚠️ La même phrase que la vitrine : payer RÉSERVE
                    // l'adhésion, l'accès s'ouvre après vérification. Promettre
                    // un accès immédiat serait faux.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        'Votre paiement réserve votre adhésion. L\'accès au '
                        'dossier de l\'entreprise s\'ouvre après vérification '
                        'de votre identité par le cabinet, qui vous contactera '
                        ': un NIU se lit sur chaque facture, et il ne suffit '
                        'pas à prouver que vous représentez l\'entreprise.',
                        key: const Key('avertissement-verification'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                  if (_aFormules)
                    _Champ(
                      clef: 'chiffre-affaires',
                      etiquette: 'Chiffre d\'affaires annuel, en FCFA',
                      controleur: _chiffreAffaires,
                      clavier: TextInputType.number,
                      formateurs: [FilteringTextInputFormatter.digitsOnly],
                      // ⚠️ C'est lui qui décide du prix : le serveur en déduit
                      // la tranche. Sans lui, il refuse le devis.
                      aide: 'Il détermine votre formule, donc votre tarif.',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // ⚠️ UNE SEULE ACTION PLEINE PAR ÉCRAN — § 10.7. Une fois le prix
            // affiché, l'action est de RÉGLER ; recalculer devient secondaire.
            // Sur le téléphone, les deux boutons pleins magenta se suivaient,
            // et « Voir mon prix » avait l'air aussi important que « Régler ».
            if (_devis == null)
              FilledButton(
                key: const Key('chiffrer'),
                onPressed: _enCours ? null : _chiffrer,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(_enCours ? 'Un instant…' : 'Voir mon prix'),
              )
            else
              OutlinedButton(
                key: const Key('chiffrer'),
                onPressed: _enCours ? null : _chiffrer,
                child: Text(
                  _enCours ? 'Un instant…' : 'Recalculer après modification',
                ),
              ),

            if (_devis != null) ...[
              const SizedBox(height: 26),
              _Chiffrage(devis: _devis!),
              const SizedBox(height: 16),
              // ⚠️ PAS DE BOUTON DE PAIEMENT SUR UN PRIX QUE LE GÉRANT N'A PAS
              // FIXÉ. Le serveur le refuserait : montrer le bouton, c'est
              // promettre ce qui échouera au moment où le visiteur a décidé de
              // payer. On lui dit plutôt ce qui va se passer, et comment
              // joindre le cabinet.
              if (_devis!.prixArretes)
                FilledButton.icon(
                  key: const Key('payer'),
                  onPressed: _enCours ? null : _payer,
                  icon: const Icon(Icons.phone_iphone, size: 19),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  label: const Text('Régler par paiement mobile'),
                )
              else
                _PrixAConfirmer(
                  servicePublic: widget.servicePublic,
                  devis: _devis!.reference,
                  telephone: _telephone.text.trim(),
                ),
            ],
          ],

          if (_motif != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: couleurs.errorContainer,
                borderRadius: BorderRadius.circular(Marque.rayonBloc),
              ),
              child: Text(
                _motif!,
                key: const Key('motif-du-refus'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: couleurs.onErrorContainer,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Le chiffrage : ce qu'on paie maintenant, et ce qui suivra.
class _Chiffrage extends StatelessWidget {
  const _Chiffrage({required this.devis});

  final Devis devis;

  @override
  Widget build(BuildContext context) {
    final d = devis;
    final couleurs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // ⚠️ INDIGO, ET NON MAGENTA : le devis est un résumé, pas une action.
        // Vu sur le téléphone, le bloc magenta posé au-dessus du bouton
        // magenta « Régler » faisait deux taches de la même couleur, et l'œil
        // ne savait plus laquelle toucher.
        color: couleurs.secondaryContainer,
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in d.lignes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l.libelle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: couleurs.onSecondaryContainer,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _montant(l.montant),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: couleurs.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          Divider(color: couleurs.onSecondaryContainer.withValues(alpha: 0.2)),
          const SizedBox(height: 6),

          // ⚠️ CE QU'ON PAIE MAINTENANT, EN GRAND — et c'est rarement le total.
          // Un abonnement mensuel se prélève ensuite : confondre les deux
          // ferait annoncer 192 500 F à quelqu'un à qui l'on en demande 180 000.
          // ⚠️ « À RÉGLER MAINTENANT » SEULEMENT SI L'ON PEUT RÉGLER. Vu sur le
          // téléphone : un tarif que le gérant n'a pas fixé s'annonçait « à
          // régler maintenant » et « garanti », juste au-dessus du bloc qui
          // disait qu'il était indicatif et ne se réglait pas.
          Text(
            d.prixArretes ? 'À régler maintenant' : 'Tarif indicatif',
            key: const Key('libelle-du-montant'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: couleurs.onSecondaryContainer.withValues(alpha: 0.8),
            ),
          ),
          Text(
            _montant(d.montantARegler),
            key: const Key('montant-a-regler'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: couleurs.onSecondaryContainer,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (d.abonnementMensuel != null && d.abonnementMensuel! > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Puis ${_montant(d.abonnementMensuel!)} par mois, prélevés par le '
              'cabinet.',
              key: const Key('abonnement-mensuel'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: couleurs.onSecondaryContainer,
                height: 1.4,
              ),
            ),
          ],
          if (d.valideJusquAu != null) ...[
            const SizedBox(height: 8),
            Text(
              d.prixArretes
                  ? 'Ce prix est garanti jusqu\'au ${_jour(d.valideJusquAu!)}.'
                  : 'Devis valable jusqu\'au ${_jour(d.valideJusquAu!)}, '
                        'prix à confirmer par le cabinet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: couleurs.onSecondaryContainer.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ce qui reste à faire : entrer son code. ⚠️ Jamais « c'est réglé ».
/// Le prix n'est pas encore arrêté : ce qui va se passer, et qui joindre.
/// Le devis dont le prix reste à arrêter : le client demande au cabinet de le
/// faire.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ UN BOUTON, ET NON UNE PROMESSE
///
/// L'écran disait « un responsable vous rappelle », et rien ne prévenait
/// personne : le devis dormait sur le serveur. « Faire confirmer mon prix »
/// dépose une vraie demande dans la file du responsable. Il arrête le prix avec
/// le client, puis la proposition part par courriel ou sur WhatsApp, avec le
/// lien pour l'accepter.
///
/// ⚠️ LE BOUTON PLEIN EST ICI LE SEUL DE L'ÉCRAN : sans paiement possible,
/// c'est l'action qui fait avancer. « Voir mon prix » est déjà repassé en
/// bouton secondaire (§ 10.7).
///
/// Deux appuis ne font pas deux dossiers : le serveur rattache la seconde
/// demande au dossier déjà ouvert pour ce numéro. Le bouton se retire quand
/// même après succès : le client doit voir que c'est fait, pas recommencer.
/// ─────────────────────────────────────────────────────────────────────────────
class _PrixAConfirmer extends StatefulWidget {
  const _PrixAConfirmer({
    required this.servicePublic,
    required this.devis,
    required this.telephone,
  });

  final ServicePublic servicePublic;
  final String devis;
  final String telephone;

  @override
  State<_PrixAConfirmer> createState() => _EtatDuPrixAConfirmer();
}

class _EtatDuPrixAConfirmer extends State<_PrixAConfirmer> {
  bool _enCours = false;

  /// Le message du serveur après succès : il remplace le bouton.
  String? _transmis;
  String? _motif;

  Future<void> _demander() async {
    setState(() {
      _enCours = true;
      _motif = null;
    });
    final r = await widget.servicePublic.demanderLeRappelDuDevis(widget.devis);
    if (!mounted) return;
    setState(() {
      _enCours = false;
      switch (r.sort) {
        case SortDeLaDemarche.fait:
          _transmis = r.valeur ?? 'Votre demande est transmise au cabinet.';
        case SortDeLaDemarche.refuse:
          _motif = r.motif ?? 'Le cabinet ne peut pas recevoir cette demande.';
        case SortDeLaDemarche.indisponible:
          _motif =
              'Le serveur ne répond pas. Vérifiez votre connexion, ou écrivez '
              'au cabinet sur WhatsApp.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    final texte = Theme.of(context).textTheme;
    final telephone = widget.telephone;
    return Container(
      key: const Key('prix-a-confirmer'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: couleurs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Marque.rayonCarte),
        border: Border.all(color: couleurs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Un prix à confirmer', style: texte.titleSmall),
          const SizedBox(height: 6),
          Text(
            'Ce tarif est indicatif : le cabinet le confirme avant tout '
            'paiement. Un responsable arrête votre prix avec vous'
            '${telephone.isEmpty ? '' : ' au $telephone'}, puis vous envoie '
            'votre proposition par courriel ou sur WhatsApp.',
            style: texte.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (_transmis != null)
            Row(
              key: const Key('rappel-transmis'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline, color: couleurs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _transmis!,
                    style: texte.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else
            FilledButton(
              key: const Key('faire-confirmer'),
              onPressed: _enCours ? null : _demander,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: Text(_enCours ? 'Envoi…' : 'Faire confirmer mon prix'),
            ),
          if (_motif != null) ...[
            const SizedBox(height: 10),
            Text(
              _motif!,
              key: const Key('rappel-motif'),
              style: texte.bodyMedium?.copyWith(color: couleurs.error),
            ),
          ],
          const SizedBox(height: 6),
          TextButton.icon(
            key: const Key('prix-joindre'),
            onPressed: () => joindre(
              context,
              Cabinet.whatsappLien,
              aCopier: Cabinet.whatsapp,
            ),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Ou écrire au cabinet sur WhatsApp'),
          ),
        ],
      ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.engagement, required this.surSuivre});

  final Engagement engagement;

  /// Ouvre le suivi : l'argent est-il arrivé, qu'attend-on encore.
  final VoidCallback surSuivre;

  @override
  Widget build(BuildContext context) {
    final e = engagement;
    final couleurs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.phone_iphone, size: 40, color: couleurs.primary),
        const SizedBox(height: 16),
        Text(
          'Validez sur votre téléphone',
          key: const Key('titre-confirmation'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        // La phrase du serveur, telle quelle : c'est lui qui sait ce que
        // l'opérateur vient d'envoyer.
        Text(
          e.message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 22),
        Carte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.telephone != null)
                _Detail(intitule: 'Numéro', valeur: e.telephone!),
              if (e.montant != null)
                _Detail(intitule: 'Montant', valeur: _montant(e.montant!)),
              // ⚠️ La référence est ce qui permet de suivre la souscription et
              // de la citer au cabinet. Elle se copie.
              _Detail(
                intitule: 'Référence',
                valeur: e.souscription,
                copiable: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Tant que vous n\'avez pas entré votre code, rien n\'est réglé et '
          'votre accès n\'est pas ouvert. Gardez la référence ci-dessus : elle '
          'sert à suivre votre souscription.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: couleurs.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        // ⚠️ Le geste qui manquait : l'écran s'arrêtait sur « validez sur votre
        // téléphone », et le souscripteur ne savait jamais si c'était fait.
        FilledButton.icon(
          key: const Key('suivre-la-souscription'),
          onPressed: surSuivre,
          icon: const Icon(Icons.track_changes),
          label: const Text("J'ai validé : suivre ma souscription"),
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.intitule,
    required this.valeur,
    this.copiable = false,
  });

  final String intitule;
  final String valeur;
  final bool copiable;

  @override
  Widget build(BuildContext context) {
    final couleurs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              intitule,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: couleurs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              valeur,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (copiable)
            IconButton(
              key: const Key('copier-reference'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded, size: 17),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: valeur));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Référence $valeur copiée')),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Champ extends StatelessWidget {
  const _Champ({
    required this.clef,
    required this.etiquette,
    required this.controleur,
    this.clavier,
    this.obligatoire = true,
    this.aide,
    this.validation,
    this.formateurs,
    this.majuscules = false,
  });

  final String clef;
  final String etiquette;
  final TextEditingController controleur;
  final TextInputType? clavier;
  final bool obligatoire;
  final String? aide;
  final String? Function(String?)? validation;
  final List<TextInputFormatter>? formateurs;

  /// Le clavier s'ouvre en capitales : un NIU s'écrit ainsi, et le taper en
  /// minuscules oblige à tout corriger à la main.
  final bool majuscules;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: Key('champ-$clef'),
      controller: controleur,
      keyboardType: clavier,
      inputFormatters: formateurs,
      textCapitalization: majuscules
          ? TextCapitalization.characters
          : TextCapitalization.none,
      // ⚠️ Pas de bordure écrite ici : le thème pose des champs remplis et
      // arrondis. Une `OutlineInputBorder` locale faisait de ce formulaire le
      // seul de l'application à garder des cadres gris.
      decoration: InputDecoration(
        labelText: etiquette,
        helperText: aide,
        helperMaxLines: 2,
      ),
      validator:
          validation ??
          (v) => obligatoire && (v == null || v.trim().isEmpty)
              ? 'À renseigner'
              : null,
    ),
  );
}

const _moisEnFrancais = [
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
    '${d.day} ${_moisEnFrancais[d.month - 1]} ${d.year}';

String _montant(double v) {
  final entier = v.round().toString();
  final tranches = <String>[];
  for (var fin = entier.length; fin > 0; fin -= 3) {
    tranches.insert(0, entier.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
  }
  return '${tranches.join(' ')} F';
}
