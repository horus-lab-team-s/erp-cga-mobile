import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../composants/actions.dart';
import '../domaine/connaissance_de_la_piece.dart';
import '../marque.dart';

/// Ce que l'adhérent décide devant l'aperçu.
sealed class DecisionDApercu {
  const DecisionDApercu();
}

/// Envoyer la pièce, avec ce qu'il en a dit (peut-être rien).
class EnvoyerLaPiece extends DecisionDApercu {
  const EnvoyerLaPiece(this.connaissance);
  final ConnaissanceDeLaPiece connaissance;
}

/// La photo est floue, coupée : on la reprend.
class ReprendreLaPhoto extends DecisionDApercu {
  const ReprendreLaPhoto();
}

/// L'aperçu d'une pièce AVANT qu'elle parte, et ce que l'adhérent peut en dire
/// (19 octobre 2026).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// POURQUOI UN APERÇU, ET POURQUOI RIEN N'Y EST OBLIGATOIRE
///
/// La photo partait sitôt prise : une facture coupée, floue ou à l'envers arrivait au
/// cabinet, qui la redemandait trois jours plus tard. On la revoit donc, en grand,
/// avant de l'envoyer.
///
/// Et puisque l'adhérent a la facture en main, il peut dire ce que le comptable
/// cherchera : la nature, l'émetteur, le numéro, la date, le montant. Chaque champ
/// est facultatif. « Envoyer » marche avec un formulaire vide : une pièce sans
/// précisions vaut mieux qu'une pièce jamais envoyée.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranApercuDuDepot extends StatefulWidget {
  const EcranApercuDuDepot({super.key, required this.chemin});

  final String chemin;

  @override
  State<EcranApercuDuDepot> createState() => _EtatDeLApercu();
}

class _EtatDeLApercu extends State<EcranApercuDuDepot> {
  NatureDeLaPiece? _nature;
  DateTime? _date;
  final _emetteur = TextEditingController();
  final _reference = TextEditingController();
  final _montant = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _emetteur.dispose();
    _reference.dispose();
    _montant.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _libelleEmetteur => switch (_nature) {
    NatureDeLaPiece.factureVente => 'Client',
    NatureDeLaPiece.releveBancaire => 'Banque',
    NatureDeLaPiece.releveMobileMoney => 'Opérateur',
    _ => 'Fournisseur',
  };

  Future<void> _choisirLaDate() async {
    final aujourdhui = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: _date ?? aujourdhui,
      firstDate: DateTime(aujourdhui.year - 2),
      lastDate: aujourdhui,
      helpText: 'Date du document',
    );
    if (choisie != null) setState(() => _date = choisie);
  }

  void _envoyer() {
    final chiffres = _montant.text.replaceAll(RegExp(r'[^0-9]'), '');
    Navigator.of(context).pop(
      EnvoyerLaPiece(
        ConnaissanceDeLaPiece(
          nature: _nature,
          emetteur: _emetteur.text,
          reference: _reference.text,
          dateDuDocument: _date,
          montantTtc: chiffres.isEmpty ? null : int.parse(chiffres),
          note: _note.text,
        ),
      ),
    );
  }

  void _agrandir() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.file(File(widget.chemin))),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleurs = theme.colorScheme;
    return Scaffold(
      backgroundColor: Marque.indigo900,
      appBar: AppBar(
        backgroundColor: Marque.indigo900,
        foregroundColor: Colors.white,
        title: const Text('Vérifier la pièce'),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── L'image, en grand : c'est elle qu'on vérifie d'abord ────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
            child: GestureDetector(
              onTap: _agrandir,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Image.file(
                        File(widget.chemin),
                        fit: BoxFit.cover,
                        cacheWidth: 1000,
                        errorBuilder: (_, _, _) => Container(
                          color: Marque.indigo700,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Agrandir',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Ce que l'adhérent peut en dire ───────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: couleurs.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ce que vous savez de cette pièce',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tout est facultatif. Ce que vous direz ici, le comptable '
                  'n\'aura pas à le relire.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: couleurs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final n in NatureDeLaPiece.values)
                      ChoiceChip(
                        key: Key('nature-${n.code}'),
                        label: Text(n.libelle),
                        selected: _nature == n,
                        onSelected: (oui) =>
                            setState(() => _nature = oui ? n : null),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('apercu-emetteur'),
                  controller: _emetteur,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _libelleEmetteur,
                    prefixIcon: const Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('apercu-reference'),
                        controller: _reference,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Numéro',
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        key: const Key('apercu-date'),
                        onTap: _choisirLaDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.event_outlined),
                          ),
                          child: Text(
                            _date == null ? '—' : jourLong(_date!),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('apercu-montant'),
                  controller: _montant,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Montant TTC',
                    suffixText: 'F CFA',
                    prefixIcon: Icon(Icons.payments_outlined),
                    helperText:
                        'Le total en bas de la facture, taxes comprises.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('apercu-note'),
                  controller: _note,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Un mot pour le comptable',
                    hintText: 'Payée en espèces, avoir sur la facture 412…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                BoutonDAction(
                  key: const Key('apercu-envoyer'),
                  libelle: 'Envoyer la pièce',
                  icone: Icons.send_rounded,
                  surAppui: _envoyer,
                ),
                const SizedBox(height: 10),
                BoutonDAction(
                  key: const Key('apercu-reprendre'),
                  libelle: 'Reprendre la photo',
                  icone: Icons.replay,
                  secondaire: true,
                  surAppui: () =>
                      Navigator.of(context).pop(const ReprendreLaPhoto()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
