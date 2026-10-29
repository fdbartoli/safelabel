import 'package:sqflite/sqflite.dart';

import 'fabrica_bd_sin_ffi.dart'
    if (dart.library.ffi) 'fabrica_bd_ffi.dart'
    as plataforma;

/// La fábrica de SQLite que corresponde a la plataforma, para pasarle a
/// `BdLocal.abrir`.
///
/// `null` en Android, iOS y macOS: ahí sqflite usa el SQLite del sistema por
/// plugin. En Windows y Linux sqflite no tiene plugin, así que se usa
/// `sqflite_common_ffi`, que carga una librería SQLite empaquetada. Sirve para
/// probar perfiles y el análisis de texto pegado en la PC; la cámara y el OCR
/// siguen siendo solo de móvil.
DatabaseFactory? fabricaBdPlataforma() => plataforma.fabricaBdPlataforma();
