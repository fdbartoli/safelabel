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
  static const version = 3;

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
          alCrear?.call();
        },
        onUpgrade: (db, anterior, nueva) async {
          if (anterior < 2) await _agregarUsuarioId(db);
          if (anterior < 3) await _migrarV3(db);
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

  /// Paso intermedio para bases v1. La v2 agregaba además la propiedad
  /// personal; la v3 elimina esa columna.
  static Future<void> _agregarUsuarioId(Database db) async {
    await db.execute('ALTER TABLE perfil ADD COLUMN usuario_id TEXT');
    await db.execute('CREATE INDEX perfil_usuario ON perfil(usuario_id)');
    await db.execute('''CREATE TABLE IF NOT EXISTS migracion_perfiles (
      clave TEXT PRIMARY KEY NOT NULL
    )''');
  }

  /// Migración v2 → v3: elimina la noción de perfil personal y conserva
  /// perfiles, restricciones y selección de activos.
  ///
  /// Se reconstruyen las tres tablas en vez de usar `ALTER TABLE DROP COLUMN`
  /// para no depender de la versión de SQLite del dispositivo. Las bases v1
  /// pasan por acá después de agregarles `usuario_id`.
  static Future<void> _migrarV3(Database db) async {
    for (final trigger in const [
      'perfil_personal_con_usuario',
      'perfil_personal_no_eliminar',
      'perfil_identidad_inmutable',
    ]) {
      await db.execute('DROP TRIGGER IF EXISTS $trigger');
    }
    await db.execute('DROP INDEX IF EXISTS perfil_personal_unico');

    await db.execute('''
      CREATE TABLE perfil_nuevo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        usuario_id TEXT
      )
    ''');
    await db.execute('''
      INSERT INTO perfil_nuevo (id, nombre, usuario_id)
      SELECT id, nombre, usuario_id FROM perfil
    ''');

    await db.execute('''
      CREATE TABLE restriccion_perfil_nuevo (
        perfil_id INTEGER NOT NULL
          REFERENCES perfil_nuevo(id) ON DELETE CASCADE,
        grupo_alergeno_id TEXT NOT NULL,
        severidad TEXT NOT NULL
          CHECK (severidad IN ('leve', 'moderada', 'anafilaxia')),
        PRIMARY KEY (perfil_id, grupo_alergeno_id)
      )
    ''');
    await db.execute('''
      INSERT INTO restriccion_perfil_nuevo
        (perfil_id, grupo_alergeno_id, severidad)
      SELECT perfil_id, grupo_alergeno_id, severidad FROM restriccion_perfil
    ''');

    await db.execute('''
      CREATE TABLE perfil_activo_nuevo (
        perfil_id INTEGER PRIMARY KEY
          REFERENCES perfil_nuevo(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      INSERT INTO perfil_activo_nuevo (perfil_id)
      SELECT perfil_id FROM perfil_activo
    ''');

    await db.execute('DROP TABLE restriccion_perfil');
    await db.execute('DROP TABLE perfil_activo');
    await db.execute('DROP TABLE perfil');
    await db.execute('ALTER TABLE perfil_nuevo RENAME TO perfil');
    await db.execute(
      'ALTER TABLE restriccion_perfil_nuevo RENAME TO restriccion_perfil',
    );
    await db.execute('ALTER TABLE perfil_activo_nuevo RENAME TO perfil_activo');

    await _crearIndicesYTriggers(db);
  }

  static Future<void> _crear(Database db, int version) async {
    final lote = db.batch();
    // AUTOINCREMENT evita que SQLite reutilice el id de un perfil borrado: una
    // selección de activos vieja nunca puede terminar apuntando a otro perfil.
    lote.execute('''
      CREATE TABLE perfil (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        usuario_id TEXT
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
    lote.execute('''
      CREATE TABLE migracion_perfiles (
        clave TEXT PRIMARY KEY NOT NULL
      )
    ''');
    await lote.commit(noResult: true);
    await _crearIndicesYTriggers(db);
  }

  static Future<void> _crearIndicesYTriggers(Database db) async {
    await db.execute('CREATE INDEX perfil_usuario ON perfil(usuario_id)');
    await db.execute('''
      CREATE TRIGGER perfil_usuario_inmutable
      BEFORE UPDATE OF usuario_id ON perfil
      WHEN OLD.usuario_id IS NOT NULL
        AND NEW.usuario_id IS NOT OLD.usuario_id
      BEGIN
        SELECT RAISE(ABORT, 'No se puede cambiar el propietario del perfil');
      END
    ''');
  }
}
