import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../marque.dart';
import '../ports/service_des_fichiers.dart';

/// Le document d'une pièce déjà déposée : la photo, ou le PDF, tel que le
/// cabinet l'a reçu.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ LE FICHIER DU SERVEUR, PAS CELUI DU TÉLÉPHONE.
///
/// La copie locale d'une photo disparaît dès qu'elle est partie : le
/// téléphone ne garde pas ce que le cabinet a déjà. Et une pièce déposée par
/// le site ou par le cabinet n'a jamais été sur ce téléphone. On montre donc
/// ce que le serveur conserve — c'est aussi ce que le comptable regarde quand
/// il écrit « facture illisible ».
///
/// ⚠️ ET CE QU'IL NE PEUT PAS MONTRER, IL LE DIT. Un format inconnu, une pièce
/// hors du dossier, un réseau coupé : trois messages, pas un écran blanc.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranVisionneuse extends StatefulWidget {
  const EcranVisionneuse({
    super.key,
    required this.fichiers,
    required this.piece,
    required this.titre,
    required this.quandSessionExpire,
  });

  final ServiceDesFichiers fichiers;

  /// L'identifiant de la pièce (« PJ-2026-0013 »).
  final String piece;

  /// Ce que la barre affiche : le nom du fichier, ou à défaut l'identifiant.
  final String titre;
  final VoidCallback quandSessionExpire;

  @override
  State<EcranVisionneuse> createState() => _EtatDeLaVisionneuse();
}

/// Les systèmes sur lesquels le lecteur de PDF sait ouvrir un document.
///
/// ⚠️ Le téléphone de l'adhérent est un Android : il y est toujours. La liste
/// sert à ne pas figer l'écran ailleurs — sur la machine d'essai en
/// particulier, qui tourne sous Linux.
bool get _leSystemeLitLesPdf =>
    kIsWeb ||
    Platform.isAndroid ||
    Platform.isIOS ||
    Platform.isMacOS ||
    Platform.isWindows;

class _EtatDeLaVisionneuse extends State<EcranVisionneuse> {
  FichierLu? _fichier;
  PdfControllerPinch? _pdf;

  @override
  void initState() {
    super.initState();
    _lire();
  }

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  Future<void> _lire() async {
    setState(() => _fichier = null);
    final lu = await widget.fichiers.lireLeFichier(widget.piece);
    if (!mounted) return;
    if (lu.sessionAExpire) {
      Navigator.of(context).pop();
      widget.quandSessionExpire();
      return;
    }
    _pdf?.dispose();
    _pdf = null;
    if (lu.estUnPdf && lu.octets != null) {
      // ⚠️ L'OUVERTURE EST ATTENDUE ICI, DANS LE `try`, ET NON CONFIÉE AU
      // LECTEUR. Le lecteur s'appuie sur le moteur PDF du système ; un système
      // qui n'en a pas refuse, et un fichier abîmé aussi. Confiée telle quelle
      // au lecteur, la promesse d'ouverture échouait sans que personne ne
      // l'attende : une erreur non traitée, l'écran figé sur son rond
      // d'attente. Attendue ici, elle mène au message qui dit que le PDF ne
      // s'affiche pas sur ce téléphone, et que le cabinet l'a bien.
      //
      // ⚠️ DEUX GARDE-FOUS DE PLUS, trouvés en essai. Sur un système que le
      // lecteur ne prend pas en charge, l'erreur naît dans une tâche interne
      // que ce `try` ne voit pas, et l'ouverture ne rend JAMAIS la main :
      // l'écran restait figé sur son rond d'attente. On vérifie donc AVANT
      // d'ouvrir, et l'on borne l'ouverture dans le temps.
      try {
        if (!_leSystemeLitLesPdf) throw const FormatException('pas de lecteur');
        final document = await PdfDocument.openData(
          lu.octets!,
        ).timeout(const Duration(seconds: 15));
        if (!mounted) {
          await document.close();
          return;
        }
        _pdf = PdfControllerPinch(document: Future.value(document));
      } on Object {
        _pdf = null;
      }
    }
    if (!mounted) return;
    setState(() => _fichier = lu);
  }

  @override
  Widget build(BuildContext context) {
    final f = _fichier;
    return Scaffold(
      // ⚠️ Fond sombre : un document blanc sur fond blanc n'a plus de bords,
      // et l'on ne voit pas où finit la page.
      backgroundColor: Marque.indigo900,
      appBar: AppBar(
        title: Text(widget.titre, overflow: TextOverflow.ellipsis),
      ),
      body: switch (f) {
        null => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        FichierLu(serveurJoignable: false) => _Message(
          cle: 'visionneuse-hors-ligne',
          icone: Icons.wifi_off_outlined,
          texte:
              "Le document n'a pas pu être téléchargé. Vérifiez votre "
              'connexion.',
          surReessayer: _lire,
        ),
        FichierLu(introuvable: true) => const _Message(
          cle: 'visionneuse-introuvable',
          icone: Icons.search_off,
          texte:
              "Le cabinet ne trouve pas ce document dans votre dossier. Il a "
              'pu être retiré après vérification.',
        ),
        FichierLu(estUneImage: true, :final octets?) => InteractiveViewer(
          key: const Key('visionneuse-image'),
          // ⚠️ Jusqu'à cinq fois : un montant sur une facture photographiée
          // de loin ne se lit qu'en agrandissant beaucoup.
          maxScale: 5,
          child: Center(
            child: Image.memory(
              octets,
              fit: BoxFit.contain,
              semanticLabel: 'Document ${widget.titre}',
            ),
          ),
        ),
        FichierLu(estUnPdf: true) when _pdf != null => PdfViewPinch(
          key: const Key('visionneuse-pdf'),
          controller: _pdf!,
          builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(),
            documentLoaderBuilder: (_) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            pageLoaderBuilder: (_) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorBuilder: (_, _) => const _Message(
              cle: 'visionneuse-pdf-illisible',
              icone: Icons.broken_image_outlined,
              texte:
                  'Ce PDF ne peut pas être affiché sur ce téléphone. Le '
                  'cabinet, lui, le lit : il est bien arrivé.',
            ),
          ),
        ),
        FichierLu(estUnPdf: true) => const _Message(
          cle: 'visionneuse-pdf-illisible',
          icone: Icons.broken_image_outlined,
          texte:
              'Ce PDF ne peut pas être affiché sur ce téléphone. Le cabinet, '
              'lui, le lit : il est bien arrivé.',
        ),
        _ => const _Message(
          cle: 'visionneuse-format',
          icone: Icons.insert_drive_file_outlined,
          texte:
              "Ce format ne s'affiche pas dans l'application. Le cabinet, "
              'lui, a bien reçu le fichier.',
        ),
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.cle,
    required this.icone,
    required this.texte,
    this.surReessayer,
  });

  final String cle;
  final IconData icone;
  final String texte;
  final VoidCallback? surReessayer;

  @override
  Widget build(BuildContext context) => Center(
    key: Key(cle),
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 44, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            texte,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          if (surReessayer != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: surReessayer,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                minimumSize: const Size(160, 46),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    ),
  );
}
