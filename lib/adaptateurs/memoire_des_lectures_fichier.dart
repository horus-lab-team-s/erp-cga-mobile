import 'dart:convert';
import 'dart:io';

import '../ports/memoire_des_lectures.dart';

/// Les dernières lectures, une par fichier, dans le dossier des documents de
/// l'application (20 octobre 2026). Sur le modèle de `MemoireDesDossiersFichier`.
///
/// ⚠️ UN FICHIER PAR CLÉ, et non un seul fichier pour tout : l'accueil et les
/// échéances se lisent en même temps, et deux écritures du même fichier se
/// marcheraient dessus.
///
/// ⚠️ ÉCRIT À CÔTÉ PUIS RENOMMÉ, comme la file : un fichier tronqué par un arrêt
/// brutal ne se relirait pas, et la copie serait perdue précisément le jour où
/// l'on en a besoin. Le renommage, lui, est atomique.
class MemoireDesLecturesFichier implements MemoireDesLectures {
  MemoireDesLecturesFichier(Directory dossier)
    : _dossier = Directory('${dossier.path}/lectures');

  final Directory _dossier;

  /// La clé (« echeances/M081234567890P ») devient un nom de fichier sans barre
  /// ni caractère que le système refuserait.
  File _fichier(String cle) => File(
    '${_dossier.path}/${base64Url.encode(utf8.encode(cle)).replaceAll('=', '')}.json',
  );

  @override
  Future<LectureGardee?> lire(String cle) async {
    try {
      final fichier = _fichier(cle);
      if (!await fichier.exists()) return null;
      final json = jsonDecode(await fichier.readAsString());
      if (json is! Map<String, dynamic>) return null;
      return LectureGardee(
        corps: json['corps'] as String,
        lueLe: DateTime.parse(json['lue_le'] as String),
      );
    } on Object {
      // Une copie illisible est une copie absente : l'écran dit « pas de réseau ».
      return null;
    }
  }

  @override
  Future<void> retenir(String cle, String corps, DateTime lueLe) async {
    try {
      await _dossier.create(recursive: true);
      final fichier = _fichier(cle);
      final provisoire = File('${fichier.path}.en-cours');
      await provisoire.writeAsString(
        jsonEncode({
          'cle': cle,
          'lue_le': lueLe.toIso8601String(),
          'corps': corps,
        }),
        flush: true,
      );
      await provisoire.rename(fichier.path);
    } on Object {
      // Une mémoire qui n'écrit pas ne doit rien empêcher : elle ne sert qu'hors ligne.
    }
  }

  @override
  Future<void> oublierTout() async {
    try {
      if (await _dossier.exists()) await _dossier.delete(recursive: true);
    } on Object {
      // Rien : au pire, la copie restera illisible pour un autre dossier.
    }
  }
}

/// La même mémoire, sans disque : pour les essais et le banc de rendu.
class MemoireDesLecturesEnMemoire implements MemoireDesLectures {
  final _lectures = <String, LectureGardee>{};

  @override
  Future<LectureGardee?> lire(String cle) async => _lectures[cle];

  @override
  Future<void> retenir(String cle, String corps, DateTime lueLe) async =>
      _lectures[cle] = LectureGardee(corps: corps, lueLe: lueLe);

  @override
  Future<void> oublierTout() async => _lectures.clear();
}
