import 'package:clock/clock.dart';

/// L'âge de la dernière lecture d'un écran (20 octobre 2026).
///
/// ─────────────────────────────────────────────────────────────────────────────
/// ⚠️ POURQUOI : CHAQUE RETOUR AU PREMIER PLAN RELISAIT TOUT.
///
/// Les échéances, les documents, l'entreprise et l'historique se relisaient à
/// chaque retour dans l'application, et l'accueil à chaque passage sur son
/// onglet. Un adhérent qui bascule dix fois vers WhatsApp dans l'heure payait dix
/// fois les mêmes lectures, sur un forfait compté, pour des chiffres que le
/// cabinet ne change pas à la minute.
///
/// La règle : on relit au retour seulement si la dernière lecture a plus de CINQ
/// MINUTES. Tirer vers le bas relit toujours : c'est une demande explicite. Et
/// après un geste (une preuve envoyée, un paiement), l'écran relit de lui-même.
///
/// ⚠️ `clock` et non `DateTime.now` : les essais avancent le temps sans attendre.
/// ─────────────────────────────────────────────────────────────────────────────
class Fraicheur {
  Fraicheur({this.duree = const Duration(minutes: 5)});

  /// Au-delà, une lecture est trop vieille pour qu'on s'en contente au retour.
  final Duration duree;

  DateTime? _lueLe;

  /// La lecture vient d'aboutir.
  void marquer() => _lueLe = clock.now();

  /// Oublie la dernière lecture : le prochain retour relira (dossier changé).
  void oublier() => _lueLe = null;

  /// Vrai quand il faut relire : jamais lu, ou lu il y a trop longtemps.
  bool get perimee {
    final lue = _lueLe;
    return lue == null || clock.now().difference(lue) >= duree;
  }
}
