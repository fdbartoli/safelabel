import 'package:sqflite/sqflite.dart';

import '../modelo/perfil.dart';

/// El perfil no cumple las reglas de [validarPerfil]. [mensaje] está pensado
/// para mostrarse tal cual en el editor.
class ErrorValidacionPerfil implements Exception {
  const ErrorValidacionPerfil(this.mensaje);
  final String mensaje;

  @override
  String toString() => 'ErrorValidacionPerfil: $mensaje';
}

/// Se pidió actualizar, eliminar o activar un perfil que no está guardado.
class PerfilNoEncontrado implements Exception {
  const PerfilNoEncontrado(this.id);
  final String id;

  @override
  String toString() => 'PerfilNoEncontrado: $id';
}

const largoMaximoNombre = 60;

/// Reglas comunes a todas las implementaciones. Devuelve el perfil con el
/// nombre recortado; lanza [ErrorValidacionPerfil] si algo no cumple.
///
/// [gruposValidos] son los ids de grupo de la base de conocimiento
/// (`BaseConocimiento.grupos.keys`). Una restricción con un id que no está ahí
/// no cruza con nada en el análisis, y lo haría en silencio: "lactosa" en vez
/// de "leche" dejaría al perfil sin protección.
///
/// Vive fuera de las implementaciones a propósito: si cada una validara por su
/// cuenta, la de memoria (la que usan los tests) podría aceptar algo que la de
/// SQLite (la de la app) rechaza, o al revés.
Perfil validarPerfil(Perfil perfil, Set<String> gruposValidos) {
  final nombre = perfil.nombre.trim();
  if (nombre.isEmpty) {
    throw const ErrorValidacionPerfil('El perfil necesita un nombre.');
  }
  // runes cuenta caracteres Unicode, no unidades UTF-16: "Sofía 🥛" no se
  // penaliza por el emoji.
  if (nombre.runes.length > largoMaximoNombre) {
    throw const ErrorValidacionPerfil(
      'El nombre puede tener hasta $largoMaximoNombre caracteres.',
    );
  }
  final vistos = <String>{};
  for (final r in perfil.restricciones) {
    if (!gruposValidos.contains(r.grupoAlergenoId)) {
      throw ErrorValidacionPerfil(
        'El grupo "${r.grupoAlergenoId}" no existe en la base de conocimiento.',
      );
    }
    if (!vistos.add(r.grupoAlergenoId)) {
      throw ErrorValidacionPerfil(
        'El grupo "${r.grupoAlergenoId}" está repetido en el perfil.',
      );
    }
  }
  return perfil.copiarCon(nombre: nombre);
}

/// Contrato de persistencia de perfiles (Etapa 3: varios perfiles en el mismo
/// dispositivo, sin cuentas).
///
/// La app usa [RepositorioPerfilesSqlite]; los tests de pantallas y del
/// análisis pueden usar [RepositorioPerfilesMemoria]. Ambas pasan el mismo
/// cuerpo de pruebas.
abstract class RepositorioPerfiles {
  /// Todos los perfiles, en orden de creación.
  Future<List<Perfil>> obtenerTodos();

  /// Guarda un perfil nuevo y lo devuelve con el id asignado. [perfil] debe
  /// venir sin id.
  Future<Perfil> crear(Perfil perfil);

  /// Reemplaza nombre y restricciones de un perfil ya guardado.
  Future<Perfil> actualizar(Perfil perfil);

  /// Borra el perfil, sus restricciones y su marca de activo.
  Future<void> eliminar(String id);

  /// Reemplaza el conjunto de perfiles activos por [ids].
  Future<void> marcarActivos(Set<String> ids);

  /// Los perfiles activos ya resueltos (con sus restricciones), listos para
  /// pasarle al analizador. Mismo orden que [obtenerTodos].
  Future<List<Perfil>> obtenerActivos();
}

/// Implementación en memoria: sin I/O, para tests. No sobrevive al cierre de
/// la app.
class RepositorioPerfilesMemoria implements RepositorioPerfiles {
  RepositorioPerfilesMemoria({required this.gruposValidos});

  /// Ver [validarPerfil].
  final Set<String> gruposValidos;

  // Map literal = LinkedHashMap: conserva el orden de inserción.
  final _perfiles = <String, Perfil>{};
  final _activos = <String>{};
  // Igual que AUTOINCREMENT en SQLite: un id borrado no se reutiliza.
  var _ultimoId = 0;

  @override
  Future<List<Perfil>> obtenerTodos() async => _perfiles.values.toList();

  @override
  Future<Perfil> crear(Perfil perfil) async {
    _exigirSinId(perfil);
    final valido = validarPerfil(perfil, gruposValidos);
    final guardado = _congelar(valido.copiarCon(id: '${++_ultimoId}'));
    _perfiles[guardado.id] = guardado;
    return guardado;
  }

  @override
  Future<Perfil> actualizar(Perfil perfil) async {
    final valido = validarPerfil(perfil, gruposValidos);
    _exigirExistente(perfil.id);
    final guardado = _congelar(valido);
    _perfiles[guardado.id] = guardado;
    return guardado;
  }

  @override
  Future<void> eliminar(String id) async {
    _exigirExistente(id);
    _perfiles.remove(id);
    _activos.remove(id);
  }

  @override
  Future<void> marcarActivos(Set<String> ids) async {
    ids.forEach(_exigirExistente);
    _activos
      ..clear()
      ..addAll(ids);
  }

  @override
  Future<List<Perfil>> obtenerActivos() async =>
      _perfiles.values.where((p) => _activos.contains(p.id)).toList();

  void _exigirExistente(String id) {
    if (!_perfiles.containsKey(id)) throw PerfilNoEncontrado(id);
  }

  /// Copia inmodificable de las restricciones: si quien llamó después muta su
  /// lista, no cambia lo "guardado" (en SQLite eso no puede pasar, y las dos
  /// implementaciones tienen que comportarse igual).
  Perfil _congelar(Perfil p) =>
      p.copiarCon(restricciones: List.unmodifiable(p.restricciones));
}

/// Implementación sobre el SQLite local abierto con `BdLocal.abrir`.
///
/// No cierra la base: la abre y la cierra quien la creó.
class RepositorioPerfilesSqlite implements RepositorioPerfiles {
  RepositorioPerfilesSqlite(this._db, {required this.gruposValidos});

  final Database _db;

  /// Ver [validarPerfil].
  final Set<String> gruposValidos;

  @override
  Future<List<Perfil>> obtenerTodos() => _leerPerfiles(soloActivos: false);

  @override
  Future<Perfil> crear(Perfil perfil) async {
    _exigirSinId(perfil);
    final valido = validarPerfil(perfil, gruposValidos);
    return _db.transaction((txn) async {
      final id = await txn.insert('perfil', {'nombre': valido.nombre});
      await _insertarRestricciones(txn, id, valido.restricciones);
      return valido.copiarCon(
        id: '$id',
        restricciones: List.unmodifiable(valido.restricciones),
      );
    });
  }

  @override
  Future<Perfil> actualizar(Perfil perfil) async {
    final valido = validarPerfil(perfil, gruposValidos);
    final id = _idNumerico(perfil.id);
    return _db.transaction((txn) async {
      final filas = await txn.update(
        'perfil',
        {'nombre': valido.nombre},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (filas == 0) throw PerfilNoEncontrado(perfil.id);
      // Reemplazo completo: más simple y seguro que calcular un diff, y la
      // transacción garantiza que nunca se vea un perfil sin restricciones a
      // mitad de camino.
      await txn.delete(
        'restriccion_perfil',
        where: 'perfil_id = ?',
        whereArgs: [id],
      );
      await _insertarRestricciones(txn, id, valido.restricciones);
      return valido.copiarCon(
        restricciones: List.unmodifiable(valido.restricciones),
      );
    });
  }

  @override
  Future<void> eliminar(String id) async {
    // Las restricciones y la marca de activo se van por ON DELETE CASCADE.
    final filas = await _db.delete(
      'perfil',
      where: 'id = ?',
      whereArgs: [_idNumerico(id)],
    );
    if (filas == 0) throw PerfilNoEncontrado(id);
  }

  @override
  Future<void> marcarActivos(Set<String> ids) async {
    final numericos = ids.map(_idNumerico).toList();
    await _db.transaction((txn) async {
      for (final id in numericos) {
        final existe = await txn.query(
          'perfil',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
        );
        if (existe.isEmpty) throw PerfilNoEncontrado('$id');
      }
      await txn.delete('perfil_activo');
      for (final id in numericos) {
        await txn.insert('perfil_activo', {'perfil_id': id});
      }
    });
  }

  @override
  Future<List<Perfil>> obtenerActivos() => _leerPerfiles(soloActivos: true);

  Future<List<Perfil>> _leerPerfiles({required bool soloActivos}) async {
    final filtro = soloActivos
        ? 'WHERE p.id IN (SELECT perfil_id FROM perfil_activo)'
        : '';
    // Un LEFT JOIN trae perfiles y restricciones en una sola consulta; el LEFT
    // es para que un perfil sin restricciones también aparezca.
    final filas = await _db.rawQuery('''
      SELECT p.id, p.nombre, r.grupo_alergeno_id, r.severidad
      FROM perfil p
      LEFT JOIN restriccion_perfil r ON r.perfil_id = p.id
      $filtro
      ORDER BY p.id, r.rowid
    ''');

    final restriccionesPorId = <int, List<RestriccionPerfil>>{};
    final nombrePorId = <int, String>{};
    for (final f in filas) {
      final id = f['id'] as int;
      nombrePorId[id] = f['nombre'] as String;
      final lista = restriccionesPorId.putIfAbsent(id, () => []);
      final grupo = f['grupo_alergeno_id'] as String?;
      if (grupo != null) {
        lista.add(
          RestriccionPerfil(
            grupoAlergenoId: grupo,
            // byName y no Severidad.desdeJson: desdeJson cae en `leve` ante un
            // valor desconocido, y degradar en silencio la severidad de un
            // perfil con anafilaxia es justo lo que no puede pasar.
            severidad: Severidad.values.byName(f['severidad'] as String),
          ),
        );
      }
    }
    return [
      for (final e in nombrePorId.entries)
        Perfil(
          id: '${e.key}',
          nombre: e.value,
          restricciones: List.unmodifiable(restriccionesPorId[e.key]!),
        ),
    ];
  }

  Future<void> _insertarRestricciones(
    Transaction txn,
    int perfilId,
    List<RestriccionPerfil> restricciones,
  ) async {
    for (final r in restricciones) {
      await txn.insert('restriccion_perfil', {
        'perfil_id': perfilId,
        'grupo_alergeno_id': r.grupoAlergenoId,
        'severidad': r.severidad.name,
      });
    }
  }

  /// En SQLite el id es INTEGER; hacia afuera se expone como String para que
  /// el modelo no dependa del motor. Un id que no es número no puede existir.
  int _idNumerico(String id) {
    final n = int.tryParse(id);
    if (n == null) throw PerfilNoEncontrado(id);
    return n;
  }
}

void _exigirSinId(Perfil perfil) {
  if (perfil.id.isNotEmpty) {
    throw ArgumentError.value(
      perfil.id,
      'perfil.id',
      'crear() asigna el id; para un perfil ya guardado usar actualizar()',
    );
  }
}
