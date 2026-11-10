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
  static const version = 2;

  /// Abre (o crea) la base.
  ///
  /// [fabrica] y [ruta] existen para los tests: ahí se pasa la fábrica de
  /// `sqflite_common_ffi` y una ruta en memoria o temporal, así corren sin
  /// dispositivo. En la app se usan los valores por defecto de sqflite.
  ///
  /// [alCrear] se llama solo si la base se creó en esta apertura (la primera
  /// vez en la vida de la app). Sirve para sembrar datos iniciales: no alcanza
  /// con "si no hay perfiles", porque alguien puede haberlos borrado todos a
  /// propósito y no querría verlos reaparecer.
  static Future<Database> abrir({
    DatabaseFactory? fabrica,
    String? ruta,
    void Function()? alCrear,
  }) async {
    final f = fabrica ?? databaseFactory;
    final destino = ruta ?? p.join(await f.getDatabasesPath(), nombreArchivo);
    return f.openDatabase(
      destino,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: _configurar,
        onCreate: (db, version) async {
          await _crear(db, version);
          await _agregarPropiedad(db);
          alCrear?.call();
        },
        onUpgrade: (db, anterior, nueva) async {
          if (anterior < 2) await _agregarPropiedad(db);
        },
      ),
    );
  }

  /// SQLite trae las claves foráneas apagadas y el ajuste vale por conexión:
  /// sin esto, `ON DELETE CASCADE` no hace nada y borrar un perfil dejaría
  /// sus restricciones huérfanas.
  static Future<void> _configurar(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// onCreate/onUpgrade ya se ejecutan dentro de una transacción de sqflite.
  /// Los null heredados quedan fuera de todos los repositorios de usuario.
  static Future<void> _agregarPropiedad(Database db) async {
    await db.execute('ALTER TABLE perfil ADD COLUMN usuario_id TEXT');
    await db.execute('''ALTER TABLE perfil ADD COLUMN es_personal INTEGER
      NOT NULL DEFAULT 0 CHECK (es_personal IN (0, 1))''');
    await db.execute('CREATE INDEX perfil_usuario ON perfil(usuario_id)');
    await db.execute('''CREATE UNIQUE INDEX perfil_personal_unico
      ON perfil(usuario_id) WHERE es_personal = 1''');
    await db.execute('''CREATE TABLE migracion_perfiles (
      clave TEXT PRIMARY KEY NOT NULL
    )''');
    await db.execute('''CREATE TRIGGER perfil_personal_con_usuario
      BEFORE INSERT ON perfil WHEN NEW.es_personal = 1
        AND (NEW.usuario_id IS NULL OR length(trim(NEW.usuario_id)) = 0)
      BEGIN SELECT RAISE(ABORT, 'El perfil personal necesita usuario'); END''');
    await db.execute('''CREATE TRIGGER perfil_personal_no_eliminar
      BEFORE DELETE ON perfil WHEN OLD.es_personal = 1
      BEGIN SELECT RAISE(ABORT, 'No se puede eliminar Mi perfil'); END''');
    await db.execute(
      '''CREATE TRIGGER perfil_identidad_inmutable
      BEFORE UPDATE OF usuario_id, es_personal ON perfil
      WHEN (OLD.usuario_id IS NOT NULL AND NEW.usuario_id IS NOT OLD.usuario_id)
        OR NEW.es_personal != OLD.es_personal
      BEGIN SELECT RAISE(ABORT, 'No se puede cambiar la identidad del perfil'); END''',
    );
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
