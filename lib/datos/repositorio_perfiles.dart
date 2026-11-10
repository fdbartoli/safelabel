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

class PerfilProtegido implements Exception {
  const PerfilProtegido();
  @override
  String toString() =>
      'No se puede eliminar ni cambiar la identidad de Mi perfil.';
}

void _validarIdentidad(Perfil anterior, Perfil nuevo) {
  if (nuevo.usuarioId != anterior.usuarioId ||
      nuevo.esPersonal != anterior.esPersonal) {
    throw const PerfilProtegido();
  }
}

void _validarNuevo(Perfil perfil, String usuarioId) {
  _exigirSinId(perfil);
  if (perfil.esPersonal ||
      (perfil.usuarioId != null && perfil.usuarioId != usuarioId)) {
    throw const PerfilProtegido();
  }
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

/// Persistencia de perfiles limitada a una cuenta local. El propietario sale
/// del contexto del repositorio, nunca de un formulario.
///
/// La app usa [RepositorioPerfilesSqlite]; los tests de pantallas y del
/// análisis pueden usar [RepositorioPerfilesMemoria]. Ambas pasan el mismo
/// cuerpo de pruebas.
abstract class RepositorioPerfiles {
  /// Crea una sola vez el personal vacío e inactivo; nunca borra restricciones.
  Future<Perfil> asegurarPersonal();

  Future<Perfil?> obtenerPersonal();

  /// Los perfiles de esta cuenta, en orden de creación.
  Future<List<Perfil>> obtenerTodos();

  /// Guarda un perfil nuevo y lo devuelve con el id asignado. [perfil] debe
  /// venir sin id.
  Future<Perfil> crear(Perfil perfil);

  /// Guarda una copia sin activarla. No compara con otros perfiles: dos
  /// personas distintas pueden tener exactamente las mismas restricciones.
  Future<Perfil> crearAdicionalRecibido(Perfil perfil);

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
class AlmacenPerfilesMemoria {
  final _perfiles = <String, Perfil>{};
  final _activos = <String>{};
  var _ultimoId = 0;
}

class RepositorioPerfilesMemoria implements RepositorioPerfiles {
  RepositorioPerfilesMemoria({
    required this.gruposValidos,
    required this.usuarioId,
    AlmacenPerfilesMemoria? almacen,
  }) : _almacen = almacen ?? AlmacenPerfilesMemoria() {
    if (usuarioId.trim().isEmpty) throw ArgumentError('Falta usuarioId');
  }

  final String usuarioId;
  final AlmacenPerfilesMemoria _almacen;

  /// Ver [validarPerfil].
  final Set<String> gruposValidos;

  // Map literal = LinkedHashMap: conserva el orden de inserción.
  Map<String, Perfil> get _perfiles => _almacen._perfiles;
  Set<String> get _activos => _almacen._activos;

  @override
  Future<Perfil?> obtenerPersonal() async {
    for (final p in await obtenerTodos()) {
      if (p.esPersonal) return p;
    }
    return null;
  }

  @override
  Future<Perfil> asegurarPersonal() async {
    // Sin await entre comprobar e insertar, incluso con llamadas concurrentes.
    for (final p in _perfiles.values) {
      if (p.usuarioId == usuarioId && p.esPersonal) return p;
    }
    final p = Perfil(
      id: '${++_almacen._ultimoId}',
      usuarioId: usuarioId,
      esPersonal: true,
      nombre: 'Mi perfil',
      restricciones: const [],
    );
    _perfiles[p.id] = p;
    return p;
  }

  @override
  Future<List<Perfil>> obtenerTodos() async =>
      _perfiles.values.where((p) => p.usuarioId == usuarioId).toList();

  @override
  Future<Perfil> crear(Perfil perfil) async {
    _validarNuevo(perfil, usuarioId);
    final valido = validarPerfil(perfil, gruposValidos);
    return _guardarNuevo(valido);
  }

  Perfil _guardarNuevo(Perfil valido) {
    final guardado = _congelar(
      valido.copiarCon(id: '${++_almacen._ultimoId}', usuarioId: usuarioId),
    );
    _perfiles[guardado.id] = guardado;
    return guardado;
  }

  @override
  Future<Perfil> crearAdicionalRecibido(Perfil perfil) async {
    _validarNuevo(perfil, usuarioId);
    final valido = validarPerfil(perfil, gruposValidos);
    if (valido.restricciones.isEmpty) {
      throw const ErrorValidacionPerfil(
        'La copia debe contener restricciones.',
      );
    }
    return _guardarNuevo(valido);
  }

  @override
  Future<Perfil> actualizar(Perfil perfil) async {
    final valido = validarPerfil(perfil, gruposValidos);
    _exigirExistente(perfil.id);
    _validarIdentidad(_perfiles[perfil.id]!, perfil);
    final guardado = _congelar(
      valido.esPersonal ? valido.copiarCon(nombre: 'Mi perfil') : valido,
    );
    _perfiles[guardado.id] = guardado;
    return guardado;
  }

  @override
  Future<void> eliminar(String id) async {
    _exigirExistente(id);
    if (_perfiles[id]!.esPersonal) throw const PerfilProtegido();
    _perfiles.remove(id);
    _activos.remove(id);
  }

  @override
  Future<void> marcarActivos(Set<String> ids) async {
    ids.forEach(_exigirExistente);
    _activos.removeWhere((id) => _perfiles[id]?.usuarioId == usuarioId);
    _activos.addAll(ids);
  }

  @override
  Future<List<Perfil>> obtenerActivos() async => _perfiles.values
      .where((p) => p.usuarioId == usuarioId && _activos.contains(p.id))
      .toList();

  void _exigirExistente(String id) {
    if (_perfiles[id]?.usuarioId != usuarioId) throw PerfilNoEncontrado(id);
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
  RepositorioPerfilesSqlite(
    this._db, {
    required this.gruposValidos,
    required this.usuarioId,
  }) {
    if (usuarioId.trim().isEmpty) throw ArgumentError('Falta usuarioId');
  }

  final String usuarioId;

  final Database _db;

  /// Ver [validarPerfil].
  final Set<String> gruposValidos;

  @override
  Future<Perfil?> obtenerPersonal() async {
    final perfiles = await obtenerTodos();
    for (final p in perfiles) {
      if (p.esPersonal) return p;
    }
    return null;
  }

  @override
  Future<Perfil> asegurarPersonal() async {
    await _db.transaction((txn) => asegurarPersonalEn(txn, usuarioId));
    return (await obtenerPersonal())!;
  }

  @override
  Future<List<Perfil>> obtenerTodos() => _leerPerfiles(soloActivos: false);

  @override
  Future<Perfil> crear(Perfil perfil) async {
    _validarNuevo(perfil, usuarioId);
    final valido = validarPerfil(perfil, gruposValidos);
    return _db.transaction((txn) => _crearEn(txn, valido));
  }

  Future<Perfil> _crearEn(Transaction txn, Perfil valido) async {
    final id = await txn.insert('perfil', {
      'nombre': valido.nombre,
      'usuario_id': usuarioId,
      'es_personal': 0,
    });
    await _insertarRestricciones(txn, id, valido.restricciones);
    return valido.copiarCon(
      id: '$id',
      usuarioId: usuarioId,
      restricciones: List.unmodifiable(valido.restricciones),
    );
  }

  @override
  Future<Perfil> crearAdicionalRecibido(Perfil perfil) async {
    _validarNuevo(perfil, usuarioId);
    final valido = validarPerfil(perfil, gruposValidos);
    if (valido.restricciones.isEmpty) {
      throw const ErrorValidacionPerfil(
        'La copia debe contener restricciones.',
      );
    }
    return _db.transaction((txn) => _crearEn(txn, valido));
  }

  @override
  Future<Perfil> actualizar(Perfil perfil) async {
    final valido = validarPerfil(perfil, gruposValidos);
    final id = _idNumerico(perfil.id);
    return _db.transaction((txn) async {
      final filasAnteriores = await txn.query(
        'perfil',
        where: 'id = ? AND usuario_id = ?',
        whereArgs: [id, usuarioId],
      );
      if (filasAnteriores.isEmpty) throw PerfilNoEncontrado(perfil.id);
      final esPersonal = filasAnteriores.single['es_personal'] == 1;
      _validarIdentidad(
        Perfil(
          id: perfil.id,
          nombre: '',
          restricciones: const [],
          usuarioId: usuarioId,
          esPersonal: esPersonal,
        ),
        perfil,
      );
      final nombre = esPersonal ? 'Mi perfil' : valido.nombre;
      final filas = await txn.update(
        'perfil',
        {'nombre': nombre},
        where: 'id = ? AND usuario_id = ?',
        whereArgs: [id, usuarioId],
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
        nombre: nombre,
        restricciones: List.unmodifiable(valido.restricciones),
      );
    });
  }

  @override
  Future<void> eliminar(String id) async {
    await _db.transaction((txn) async {
      final filas = await txn.query(
        'perfil',
        where: 'id = ? AND usuario_id = ?',
        whereArgs: [_idNumerico(id), usuarioId],
      );
      if (filas.isEmpty) throw PerfilNoEncontrado(id);
      if (filas.single['es_personal'] == 1) throw const PerfilProtegido();
      await txn.delete(
        'perfil',
        where: 'id = ? AND usuario_id = ?',
        whereArgs: [_idNumerico(id), usuarioId],
      );
    });
  }

  @override
  Future<void> marcarActivos(Set<String> ids) async {
    final numericos = ids.map(_idNumerico).toList();
    await _db.transaction((txn) async {
      for (final id in numericos) {
        final existe = await txn.query(
          'perfil',
          columns: ['id'],
          where: 'id = ? AND usuario_id = ?',
          whereArgs: [id, usuarioId],
        );
        if (existe.isEmpty) throw PerfilNoEncontrado('$id');
      }
      await txn.delete(
        'perfil_activo',
        where: 'perfil_id IN (SELECT id FROM perfil WHERE usuario_id = ?)',
        whereArgs: [usuarioId],
      );
      for (final id in numericos) {
        await txn.insert('perfil_activo', {'perfil_id': id});
      }
    });
  }

  @override
  Future<List<Perfil>> obtenerActivos() => _leerPerfiles(soloActivos: true);

  Future<List<Perfil>> _leerPerfiles({
    required bool soloActivos,
    DatabaseExecutor? ejecutor,
  }) async {
    final filtro = soloActivos
        ? 'AND p.id IN (SELECT perfil_id FROM perfil_activo)'
        : '';
    // Un LEFT JOIN trae perfiles y restricciones en una sola consulta; el LEFT
    // es para que un perfil sin restricciones también aparezca.
    final filas = await (ejecutor ?? _db).rawQuery(
      '''
      SELECT p.id, p.nombre, p.usuario_id, p.es_personal,
        r.grupo_alergeno_id, r.severidad
      FROM perfil p
      LEFT JOIN restriccion_perfil r ON r.perfil_id = p.id
      WHERE p.usuario_id = ? $filtro
      ORDER BY p.id, r.rowid
    ''',
      [usuarioId],
    );

    final restriccionesPorId = <int, List<RestriccionPerfil>>{};
    final nombrePorId = <int, String>{};
    final personales = <int>{};
    for (final f in filas) {
      final id = f['id'] as int;
      nombrePorId[id] = f['nombre'] as String;
      if (f['es_personal'] == 1) personales.add(id);
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
          usuarioId: usuarioId,
          esPersonal: personales.contains(e.key),
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

/// Compartido con la reconciliación de cuentas, dentro de su transacción.
Future<void> asegurarPersonalEn(DatabaseExecutor db, String usuarioId) async {
  final existentes = await db.query(
    'perfil',
    columns: ['id'],
    where: 'usuario_id = ? AND es_personal = 1',
    whereArgs: [usuarioId],
  );
  if (existentes.isEmpty) {
    await db.insert('perfil', {
      'nombre': 'Mi perfil',
      'usuario_id': usuarioId,
      'es_personal': 1,
    });
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
