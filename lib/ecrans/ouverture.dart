import 'package:flutter/material.dart';

import '../marque.dart';

/// Ce que l'adhérent voit pendant que l'application ouvre sa file.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ C'ÉTAIT UNE ROUE GRISE AU MILIEU DE RIEN.
///
/// Le défaut de Material, sur fond nu. Trois choses le rendaient mauvais :
///
///   · il ne ressemblait à aucun produit, et surtout pas à celui-ci. Entre le
///     fond indigo du démarrage d'Android et le bandeau indigo de la connexion,
///     cette page blanche faisait un éclair ;
///   · il ne disait pas ce qu'on attendait. Une roue qui tourne sans phrase se
///     lit comme une panne dès qu'elle dure plus d'une seconde ;
///   · il n'avait pas de fin visible. Ici l'attente est courte, mais elle peut
///     s'allonger sur un appareil lent à la première ouverture, quand le
///     système monte le dossier des documents.
///
/// La continuité compte plus que l'animation : même fond, même logo, même
/// position que l'écran qui suit. L'adhérent ne doit pas voir de rupture, il
/// doit voir un écran qui se remplit.
/// ─────────────────────────────────────────────────────────────────────────────
class EcranDOuverture extends StatelessWidget {
  const EcranDOuverture({super.key});

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final fond = sombre ? Marque.indigo900Sombre : Marque.indigo900;
    return Scaffold(
      backgroundColor: fond,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                Marque.logoBlanc,
                height: 76,
                fit: BoxFit.contain,
                semanticLabel: 'CGA Broad Range Consulting Group',
              ),
              const SizedBox(height: 40),
              // ⚠️ Un trait, et non une roue. Il occupe la largeur du logo, ce
              // qui l'inscrit dans la composition au lieu de flotter au milieu.
              SizedBox(
                width: 132,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(
                      sombre ? Marque.magenta600Sombre : Marque.magenta100,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Ouverture de vos justificatifs…',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: Color(0xFFBFB5D4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
