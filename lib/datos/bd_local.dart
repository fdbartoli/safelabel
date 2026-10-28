import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base SQLite local del dispositivo: perfiles y cuáles están activos
/// (Etapa 3). Sin backend: todo queda en el teléfono.
///
/// No guarda la base de conocimiento: esa sigue saliendo del asset curado
/// (ver `BaseConocimiento`). Por eso `restriccion_perfil.grupo_alergeno_id` no
/// tiene clave foránea: los grupos viven en otro lado.
class BdLocal {
  BdLocal._();

  static const nombreArchivo = 'safelabel.db';
  static const version = 1;

  /// Abre (o crea) la base.
  ///
  /// [fabrica] y [ruta] existen para los tests: ahí se pasa la fábrica de
  /// `sqflite_common_ffi` y una ruta en memoria o temporal, así corren sin
  /// dispositivo. En la app se usan los valores por defecto de sqflite.
  static Future<Database> abrir({
    DatabaseFactory? fabrica,
    String? ruta,
  }) async {
    final f = fabrica ?? databaseFactory;
    final destino = ruta ?? p.join(await f.getDatabasesPath(), nombreArchivo);
    return f.openDatabase(
      destino,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: _configurar,
        onCreate: _crear,
      ),
    );
  }

  /// SQLite trae las claves foráneas apagadas y el ajuste vale por conexión:
  /// sin esto, `ON DELETE CASCADE` no hace nada y borrar un perfil dejaría
  /// sus restricciones huérfanas.
  static Future<void> _configurar(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _crear(Database db, int version) async {
    final lote = db.batch();
    // AUTOINCREMENT evita que SQLite reutilice el id de un perfil borrado: una
    // selección de activos vieja nunca puede terminar apuntando a otro perfil.
    lote.execute('''
      CREATE TABLE perfil (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
      )
    ''');
    lote.execute('''
      CREATE TABLE restriccion_perfil (
        perfil_id INTEGER NOT NULL
          REFERENCES perfil(id) ON DELETE CASCADE,
        grupo_alergeno_id TEXT NOT NULL,
        severidad TEXT NOT NULL
          CHECK (severidad IN ('leve', 'moderada', 'anafilaxia')),
        PRIMARY KEY (perfil_id, grupo_alergeno_id)
      )
    ''');
    lote.execute('''
      CREATE TABLE perfil_activo (
        perfil_id INTEGER PRIMARY KEY
          REFERENCES perfil(id) ON DELETE CASCADE
      )
    ''');
    await lote.commit(noResult: true);
  }
}
