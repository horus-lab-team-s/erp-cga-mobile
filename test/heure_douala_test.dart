import 'package:cga_mobile/domaine/heure_douala.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'heure du cabinet, éprouvée sur la limite qui coûte.
///
/// ⚠️ CES CAS SONT LE MIROIR DE CEUX DE LA CONSOLE (`formats.test.ts`). Les
/// deux interfaces lisent les mêmes horodatages ; si l'une décale et l'autre
/// non, un adhérent voit son dépôt daté du 15 sur son téléphone et du 16 sur
/// le site. C'est le genre d'écart qui fait douter de tout le reste.
void main() {
  group("Une date de calendrier", () {
    test("ne se décale pas", () {
      // Une échéance, une période déclarative : le 15 août est le 15 août
      // partout. Lui appliquer un décalage la ferait glisser d'un jour.
      final d = instantDeDouala('2026-08-15');
      expect(d.year, 2026);
      expect(d.month, 8);
      expect(d.day, 15);
    });
  });

  group("Un instant horodaté par le serveur", () {
    test("gagne l'heure de décalage du Cameroun", () {
      final d = instantDeDouala('2026-08-15T09:00:00');
      expect(d.hour, 10);
      expect(d.day, 15);
    });

    test("bascule au lendemain après 23 h UTC", () {
      // ⚠️ LE DÉFAUT. Une pièce déposée à 00 h 30 à Douala apparaissait LA
      // VEILLE dans l'historique — et le premier du mois, elle basculait dans
      // le mois précédent. Sur un dépôt de justificatif, le mois de
      // rattachement n'est pas un détail de présentation.
      final d = instantDeDouala('2026-08-15T23:30:00');
      expect(d.day, 16);
      expect(d.hour, 0);
      expect(d.minute, 30);
    });

    test("franchit le mois", () {
      final d = instantDeDouala('2026-08-31T23:45:00');
      expect(d.month, 9);
      expect(d.day, 1);
    });

    test("franchit l'année", () {
      final d = instantDeDouala('2026-12-31T23:59:00');
      expect(d.year, 2027);
      expect(d.month, 1);
      expect(d.day, 1);
    });

    test("tient à la seconde où le jour bascule", () {
      expect(instantDeDouala('2026-08-15T22:59:59').day, 15);
      expect(instantDeDouala('2026-08-15T23:00:00').day, 16);
    });

    test("accepte l'espace que PostgreSQL met à la place du T", () {
      final d = instantDeDouala('2024-02-14 10:30:00');
      expect(d.hour, 11);
      expect(d.day, 14);
    });

    test("accepte les fractions de seconde du journal d'audit", () {
      final d = instantDeDouala('2026-09-19T20:09:43.214397');
      expect(d.hour, 21);
      expect(d.day, 19);
    });

    test("rend une heure LOCALE nominale, lisible telle quelle", () {
      // ⚠️ Pas un `DateTime` en UTC : l'écran lit `.day` et `.hour`
      // directement. Un instant marqué UTC ferait relire les composantes dans
      // le fuseau de l'appareil, et le décalage s'appliquerait deux fois.
      expect(instantDeDouala('2026-08-15T23:30:00').isUtc, isFalse);
    });
  });
}
