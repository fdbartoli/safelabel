import 'dart:math';

import 'package:flutter/foundation.dart';

import '../datos/repositorio_usuarios.dart';
import '../datos/preparador_perfiles.dart';
import '../modelo/usuario.dart';
import 'reglas_usuario.dart';
import 'seguridad_contrasena.dart';
import 'terminos_condiciones.dart';

/// Datos de la cuenta que la presentación puede mostrar.
/// No incluye la contraseña ni su hash.
class CuentaUsuario {
  const CuentaUsuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.fechaNacimiento,
    required this.fechaAlta,
    required this.versionTerminos,
    required this.fechaAceptacionTerminos,
  });

  final String id;
  final String nombre;
  final String apellido;
  final String email;
  final DateTime? fechaNacimiento;
  final DateTime fechaAlta;
  final String? versionTerminos;
  final DateTime? fechaAceptacionTerminos;

  String get nombreCompleto => '$nombre $apellido'.trim();
}

/// Error de negocio con un mensaje listo para mostrar en pantalla.
class ErrorCuenta implements Exception {
  const ErrorCuenta(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Casos de uso de gestión de usuarios (HU01 a HU05).
///
/// Avisa a quien lo escuche cada vez que cambia la sesión o los datos de la
/// cuenta; así la app pasa sola del ingreso a la pantalla principal y vuelve.
class ServicioCuenta extends ChangeNotifier {
  ServicioCuenta(this._repositorio, {required this.preparador});

  static const String mensajeCredencialesInvalidas =
      'Email o contraseña incorrectos.';
  static const String mensajeTerminosNoAceptados =
      'Para crear la cuenta tenés que aceptar los términos y condiciones.';

  final RepositorioUsuarios _repositorio;
  final PreparadorPerfiles preparador;
  String? _sesionPreparadaId;
  Future<void> _operacionesSesion = Future.value();
  final Random _azar = Random();

  /// Evita que dos altas lean un conjunto antiguo de cuentas, o que un login
  /// pendiente vuelva a abrir la sesión después de un cierre solicitado.
  Future<T> _serializarSesion<T>(Future<T> Function() operacion) {
    final resultado = _operacionesSesion.then((_) => operacion());
    _operacionesSesion = resultado.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return resultado;
  }

  // Validaciones y conversiones que usan los formularios.
  String? validarNombre(String? valor) => ReglasUsuario.validarNombre(valor);
  String? validarApellido(String? valor) =>
      ReglasUsuario.validarApellido(valor);
  String? validarEmail(String? valor) => ReglasUsuario.validarEmail(valor);
  String? validarContrasena(String? valor) =>
      ReglasUsuario.validarContrasena(valor);
  String? validarFechaNacimiento(String? texto) =>
      ReglasUsuario.validarTextoFechaNacimiento(texto);
  DateTime? parsearFecha(String? texto) => ReglasUsuario.parsearFecha(texto);

  bool get haySesionActiva => cuentaActual() != null;

  /// HU03: datos de la cuenta con sesión iniciada.
  CuentaUsuario? cuentaActual() {
    final usuario = _usuarioEnSesionOpcional();
    return usuario == null || usuario.id != _sesionPreparadaId
        ? null
        : _aCuenta(usuario);
  }

  Future<void> _prepararPerfiles() async {
    try {
      final usuarios = _repositorio.obtenerTodos();
      await preparador.preparar(
        {for (final u in usuarios) u.id},
        usuariosConDemostracion: {
          for (final u in usuarios)
            if (u.incluirPerfilesDemostracion) u.id,
        },
      );
    } catch (_) {
      throw const ErrorCuenta(
        'No se pudieron preparar los perfiles. Los datos guardados se '
        'conservan; reintentá el acceso con tu email y contraseña.',
      );
    }
  }

  /// Se ejecuta antes de habilitar la app, aun cuando no hay sesión guardada.
  Future<void> restaurarSesion() => _serializarSesion(() async {
    _sesionPreparadaId = null;
    await _prepararPerfiles();
    final usuario = _usuarioEnSesionOpcional();
    if (usuario == null) await _repositorio.borrarSesion();
    _sesionPreparadaId = usuario?.id;
    notifyListeners();
  });

  Future<void> _abrirSesion(Usuario usuario) async {
    await _prepararPerfiles();
    try {
      await _repositorio.guardarSesion(usuario.id);
    } catch (_) {
      throw const ErrorCuenta(
        'La cuenta y sus perfiles se conservan, pero no se pudo guardar la '
        'sesión. Reintentá el ingreso.',
      );
    }
    _sesionPreparadaId = usuario.id;
    notifyListeners();
  }

  /// HU01: crea la cuenta y deja la sesión iniciada.
  Future<CuentaUsuario> registrar({
    required String nombre,
    required String apellido,
    required String email,
    required DateTime? fechaNacimiento,
    required String contrasena,
    required bool aceptaTerminos,
  }) => _serializarSesion(() async {
    _exigir(ReglasUsuario.validarNombre(nombre));
    _exigir(ReglasUsuario.validarApellido(apellido));
    _exigir(ReglasUsuario.validarEmail(email));
    _exigir(ReglasUsuario.validarFechaNacimiento(fechaNacimiento));
    _exigir(ReglasUsuario.validarContrasena(contrasena));
    if (!aceptaTerminos) throw const ErrorCuenta(mensajeTerminosNoAceptados);

    final emailNormalizado = ReglasUsuario.normalizarEmail(email);
    if (_repositorio.buscarPorEmail(emailNormalizado) != null) {
      throw const ErrorCuenta('Ya existe una cuenta registrada con ese email.');
    }

    final salt = SeguridadContrasena.generarSalt();
    final ahora = DateTime.now();
    final usuario = Usuario(
      id: '${ahora.microsecondsSinceEpoch}-${_azar.nextInt(1000000)}',
      nombre: nombre.trim(),
      apellido: apellido.trim(),
      email: emailNormalizado,
      fechaNacimiento: fechaNacimiento,
      hashContrasena: SeguridadContrasena.calcularHash(contrasena, salt),
      salt: salt,
      fechaAlta: ahora,
      incluirPerfilesDemostracion: true,
      versionTerminos: TerminosCondiciones.version,
      fechaAceptacionTerminos: ahora,
    );
    // Fija la asignación de heredados ANTES de agregar una cuenta nueva.
    await _prepararPerfiles();
    try {
      await _repositorio.guardar(usuario);
    } catch (_) {
      throw const ErrorCuenta(
        'No se pudo guardar la cuenta. Reintentá el registro.',
      );
    }
    await _abrirSesion(usuario);
    return _aCuenta(usuario);
  });

  /// HU02: inicia sesión. El error no revela si falló el email o la contraseña.
  Future<CuentaUsuario> iniciarSesion({
    required String email,
    required String contrasena,
  }) => _serializarSesion(() async {
    final usuario = _repositorio.buscarPorEmail(
      ReglasUsuario.normalizarEmail(email),
    );
    if (usuario == null ||
        !SeguridadContrasena.verificar(
          contrasena,
          usuario.salt,
          usuario.hashContrasena,
        )) {
      throw const ErrorCuenta(mensajeCredencialesInvalidas);
    }
    await _abrirSesion(usuario);
    return _aCuenta(usuario);
  });

  /// HU04: cambia los datos personales de la cuenta en sesión.
  Future<CuentaUsuario> editarDatos({
    required String nombre,
    required String apellido,
    required String email,
    required DateTime? fechaNacimiento,
  }) async {
    final usuario = _usuarioEnSesion();
    _exigir(ReglasUsuario.validarNombre(nombre));
    _exigir(ReglasUsuario.validarApellido(apellido));
    _exigir(ReglasUsuario.validarEmail(email));
    _exigir(ReglasUsuario.validarFechaNacimiento(fechaNacimiento));

    final emailNormalizado = ReglasUsuario.normalizarEmail(email);
    final otro = _repositorio.buscarPorEmail(emailNormalizado);
    if (otro != null && otro.id != usuario.id) {
      throw const ErrorCuenta(
        'Ya existe otra cuenta registrada con ese email.',
      );
    }

    final actualizado = usuario.copiarCon(
      nombre: nombre.trim(),
      apellido: apellido.trim(),
      email: emailNormalizado,
      fechaNacimiento: fechaNacimiento,
    );
    await _repositorio.guardar(actualizado);
    notifyListeners();
    return _aCuenta(actualizado);
  }

  /// HU04: cambia la contraseña; exige la contraseña actual.
  Future<void> cambiarContrasena({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) async {
    final usuario = _usuarioEnSesion();
    final actualCorrecta = SeguridadContrasena.verificar(
      contrasenaActual,
      usuario.salt,
      usuario.hashContrasena,
    );
    if (!actualCorrecta) {
      throw const ErrorCuenta('La contraseña actual no es correcta.');
    }
    _exigir(ReglasUsuario.validarContrasena(contrasenaNueva));

    final salt = SeguridadContrasena.generarSalt();
    await _repositorio.guardar(
      usuario.copiarCon(
        hashContrasena: SeguridadContrasena.calcularHash(contrasenaNueva, salt),
        salt: salt,
      ),
    );
  }

  /// HU05: cierra la sesión activa.
  Future<void> cerrarSesion() => _serializarSesion(() async {
    try {
      await _repositorio.borrarSesion();
    } catch (_) {
      throw const ErrorCuenta('No se pudo cerrar la sesión. Reintentá.');
    }
    _sesionPreparadaId = null;
    notifyListeners();
  });

  Usuario? _usuarioEnSesionOpcional() {
    final id = _repositorio.leerSesion();
    return id == null ? null : _repositorio.buscarPorId(id);
  }

  Usuario _usuarioEnSesion() {
    final usuario = _usuarioEnSesionOpcional();
    if (usuario == null || usuario.id != _sesionPreparadaId) {
      throw const ErrorCuenta('No hay una sesión activa.');
    }
    return usuario;
  }

  void _exigir(String? error) {
    if (error != null) throw ErrorCuenta(error);
  }

  CuentaUsuario _aCuenta(Usuario usuario) {
    return CuentaUsuario(
      id: usuario.id,
      nombre: usuario.nombre,
      apellido: usuario.apellido,
      email: usuario.email,
      fechaNacimiento: usuario.fechaNacimiento,
      fechaAlta: usuario.fechaAlta,
      versionTerminos: usuario.versionTerminos,
      fechaAceptacionTerminos: usuario.fechaAceptacionTerminos,
    );
  }
}
