import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ver `fabrica_bd.dart`.
DatabaseFactory? fabricaBdPlataforma() {
  final String carpeta;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
      carpeta = p.join(Platform.environment['APPDATA']!, 'SafeLabel');
    case TargetPlatform.linux:
      final datos =
          Platform.environment['XDG_DATA_HOME'] ??
          p.join(Platform.environment['HOME']!, '.local', 'share');
      carpeta = p.join(datos, 'safelabel');
    default:
      return null;
  }
  sqfliteFfiInit();
  // Por defecto sqflite_common_ffi guarda en una carpeta relativa al
  // directorio desde donde se lanzó la app: abrirla desde otro lado usaría
  // otra base y los perfiles parecerían perdidos.
  Directory(carpeta).createSync(recursive: true);
  databaseFactoryFfi.setDatabasesPath(carpeta);
  return databaseFactoryFfi;
}
