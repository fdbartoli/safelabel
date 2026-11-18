import 'package:sqflite/sqflite.dart';

import 'perfiles_iniciales.dart';
import 'repositorio_perfiles.dart';

/// Coordina SQLite con las identidades ya persistidas en SharedPreferences.
abstract class PreparadorPerfiles {
  Future<void> preparar(
    Set<String> usuarios, {
    Set<String> usuariosConDemostracion = const {},
  });
}

class PreparadorPerfilesSqlite implements PreparadorPerfiles {
  PreparadorPerfilesSqlite(this._db);

  final Database _db;

  @override
  Future<void> preparar(
    Set<String> usuarios, {
    Set<String> usuariosConDemostracion = const {},
  }) async {
    if (!usuarios.containsAll(usuariosConDemostracion)) {
      throw ArgumentError('Los ejemplos requieren una cuenta existente.');
    }
    await _db.transaction((txn) async {
      final migracion = await txn.query(
        'migracion_perfiles',
        where: 'clave = ?',
        whereArgs: ['propiedad_inicial'],
      );
      if (migracion.isEmpty) {
        // La decisión se toma una sola vez sobre las cuentas antiguas. Si no
        // hay ninguna o hay varias, los heredados quedan pendientes para siempre
        // hasta una futura asignación explícita; un login no se los apropia.
        if (usuarios.length == 1) {
          await txn.update('perfil', {
            'usuario_id': usuarios.single,
          }, where: 'usuario_id IS NULL');
        }
        await txn.insert('migracion_perfiles', {'clave': 'propiedad_inicial'});
      }
      for (final id in usuarios) {
        if (id.trim().isEmpty) throw ArgumentError('Falta usuarioId');
        if (usuariosConDemostracion.contains(id)) {
          await _asegurarDemostracion(txn, id);
        }
      }
    });
  }

  Future<void> _asegurarDemostracion(Transaction txn, String usuarioId) async {
    final clave = 'demostracion:$usuarioId';
    final completada = await txn.query(
      'migracion_perfiles',
      where: 'clave = ?',
      whereArgs: [clave],
    );
    if (completada.isNotEmpty) return;

    final activos = await txn.rawQuery(
      '''SELECT a.perfil_id FROM perfil_activo a
      JOIN perfil p ON p.id = a.perfil_id WHERE p.usuario_id = ?''',
      [usuarioId],
    );
    int? primero;
    for (final perfil in perfilesIniciales) {
      final id = await txn.insert('perfil', {
        'nombre': perfil.nombre,
        'usuario_id': usuarioId,
      });
      primero ??= id;
      for (final restriccion in perfil.restricciones) {
        await txn.insert('restriccion_perfil', {
          'perfil_id': id,
          'grupo_alergeno_id': restriccion.grupoAlergenoId,
          'severidad': restriccion.severidad.name,
        });
      }
    }
    // Conserva selecciones previas y activa el primero solo si no había nada.
    if (activos.isEmpty && primero != null) {
      await txn.insert('perfil_activo', {'perfil_id': primero});
    }
    // Datos y marcador se confirman juntos: un fallo no deja carga parcial.
    await txn.insert('migracion_perfiles', {'clave': clave});
  }
}

/// Sustituto sin I/O para las pruebas de cuenta y presentación.
class PreparadorPerfilesMemoria implements PreparadorPerfiles {
  final almacen = AlmacenPerfilesMemoria();
  final _demostracionesPreparadas = <String>{};
  Future<void> _operaciones = Future.value();

  @override
  Future<void> preparar(
    Set<String> usuarios, {
    Set<String> usuariosConDemostracion = const {},
  }) {
    final resultado = _operaciones.then((_) async {
      if (!usuarios.containsAll(usuariosConDemostracion)) {
        throw ArgumentError('Los ejemplos requieren una cuenta existente.');
      }
      final grupos = {
        for (final p in perfilesIniciales)
          for (final r in p.restricciones) r.grupoAlergenoId,
      };
      // Validar todo antes de escribir para no dejar cargas parciales en memoria.
      for (final p in perfilesIniciales) {
        validarPerfil(p, grupos);
      }
      for (final id in usuarios) {
        final repositorio = RepositorioPerfilesMemoria(
          usuarioId: id,
          gruposValidos: grupos,
          almacen: almacen,
        );
        if (usuariosConDemostracion.contains(id) &&
            !_demostracionesPreparadas.contains(id)) {
          await sembrarPerfilesIniciales(
            repositorio,
            activarPrimero: (await repositorio.obtenerActivos()).isEmpty,
          );
          _demostracionesPreparadas.add(id);
        }
      }
    });
    _operaciones = resultado.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return resultado;
  }
}
