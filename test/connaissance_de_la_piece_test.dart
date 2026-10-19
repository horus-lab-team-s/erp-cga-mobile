import 'package:cga_mobile/domaine/connaissance_de_la_piece.dart';
import 'package:cga_mobile/domaine/depot.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que l'adhérent dit de sa pièce (19 octobre 2026) : facultatif, gardé dans la
/// file hors ligne, et remis avec les noms que le serveur attend.
void main() {
  final connaissance = ConnaissanceDeLaPiece(
    nature: NatureDeLaPiece.factureAchat,
    emetteur: ' QUINCAILLERIE DU WOURI ',
    reference: 'FA-2026-0815',
    dateDuDocument: DateTime(2026, 9, 12),
    montantTtc: 178875,
    note: '',
  );

  test('survit à la file : un redémarrage du téléphone ne la perd pas', () {
    final depot = Depot(
      identifiant: 'D-1',
      dossier: 'M081234567890P',
      cheminDuFichier: '/tmp/d.jpg',
      prisLe: DateTime(2026, 10, 19, 9),
      connaissance: connaissance,
    );

    final relu = Depot.depuisJson(depot.versJson()).connaissance!;

    expect(relu.nature, NatureDeLaPiece.factureAchat);
    expect(relu.montantTtc, 178875);
    expect(relu.dateDuDocument, DateTime(2026, 9, 12));
  });

  test('part avec les noms du serveur, sans rien de vide', () {
    expect(connaissance.versLaRemise(), {
      'type': 'FACTURE_ACHAT',
      'emetteur': 'QUINCAILLERIE DU WOURI',
      'reference_document': 'FA-2026-0815',
      'date_document': '2026-09-12',
      'montant_ttc': 178875,
    });
  });

  test('un formulaire laissé vide ne dit rien', () {
    expect(const ConnaissanceDeLaPiece(emetteur: '', note: '').vide, isTrue);
    expect(const ConnaissanceDeLaPiece().versLaRemise(), isEmpty);
  });
}
