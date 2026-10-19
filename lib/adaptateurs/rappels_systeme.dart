import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as fuseaux;
import 'package:timezone/timezone.dart' as tz;

import '../domaine/rappels.dart';

/// Les rappels posés dans les notifications d'Android (20 octobre 2026).
///
/// ⚠️ DES ALARMES INEXACTES, ET C'EST VOULU. Une alarme exacte exige depuis
/// Android 14 une permission que le système refuse par défaut et que les
/// boutiques d'applications contrôlent. Un rappel d'échéance à 9 h 07 plutôt qu'à
/// 9 h ne fait de tort à personne ; Android le groupe avec ses autres réveils, et
/// la batterie d'un téléphone d'entrée de gamme s'en porte mieux.
///
/// ⚠️ LE FUSEAU DE DOUALA, ÉCRIT EN TOUTES LETTRES : un téléphone réglé sur une
/// autre heure (acheté ailleurs, jamais réglé) sonnerait sinon à 8 h ou à 10 h.
class RappelsDuSysteme implements PlanificateurDeRappels {
  RappelsDuSysteme();

  final _notifications = FlutterLocalNotificationsPlugin();
  Future<void>? _pret;

  static const _canal = AndroidNotificationDetails(
    'echeances',
    'Rappels des échéances',
    channelDescription:
        'Trois jours avant et la veille de chaque échéance à payer.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> _preparer() => _pret ??= () async {
    fuseaux.initializeTimeZones();
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }();

  AndroidFlutterLocalNotificationsPlugin? get _android => _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> demanderLaPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _preparer();
      final android = _android;
      if (android == null) return false;
      if (await android.areNotificationsEnabled() == true) return true;
      return await android.requestNotificationsPermission() ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> programmer(List<Rappel> rappels) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _preparer();
      await _notifications.cancelAll();
      final douala = tz.getLocation('Africa/Douala');
      for (final (numero, r) in rappels.indexed) {
        await _notifications.zonedSchedule(
          id: numero,
          title: r.titre,
          body: r.texte,
          scheduledDate: tz.TZDateTime(
            douala,
            r.le.year,
            r.le.month,
            r.le.day,
            r.le.hour,
            r.le.minute,
          ),
          notificationDetails: const NotificationDetails(android: _canal),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } on Object {
      // Un rappel qui ne se pose pas ne doit rien empêcher : l'écran dit toujours
      // les échéances, et la prochaine lecture réessaiera.
    }
  }
}
