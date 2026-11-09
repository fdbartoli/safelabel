import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class BdConocimiento {
  BdConocimiento._();

  static const nombreArchivo = 'safelabel-knowledge.sqlite';
  static const rutaAsset = 'assets/knowledge/safelabel.sqlite';

  static Future<Database> abrir(DatabaseFactory fabrica) async {
    final ruta = p.join(await fabrica.getDatabasesPath(), nombreArchivo);
    // La base es un artefacto de solo lectura incluido en cada versión de la
    // app. Se reemplaza al arrancar para que una actualización de la app no
    // siga consultando la copia de una versión anterior.
    final bytes = await rootBundle.load(rutaAsset);
    await File(ruta).parent.create(recursive: true);
    await File(ruta).writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    return fabrica.openDatabase(
      ruta,
      options: OpenDatabaseOptions(readOnly: true),
    );
  }
}
