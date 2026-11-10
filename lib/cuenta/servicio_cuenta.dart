import 'dart:math';

import 'package:flutter/foundation.dart';

import '../datos/repositorio_usuarios.dart';
import '../modelo/usuario.dart';
import 'reglas_usuario.dart';
import 'seguridad_contrasena.dart';
import 'terminos_condiciones.dart';

/// Datos de la cuenta que la presentación puede mostrar.
/// No incluye la contraseña ni su hash.
class CuentaUsuario {
  const CuentaUsuario({
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.fechaNacimiento,
    required this.fechaAlta,
    required this.versionTerminos,
    required this.fechaAceptacionTerminos,
    this.avatar = '',
  });

  final String nombre;
  final String apellido;
  final String email;
  final DateTime? fechaNacimiento;
  final DateTime fechaAlta;
  final String? versionTerminos;
  final DateTime? fechaAceptacionTerminos;

  /// Semilla del avatar; vacía en cuentas anteriores a los avatares.
  final String avatar;

  String get nombreCompleto => '$nombre $apellido'.trim();

  /// La semilla con la que se dibuja el avatar.
  String get semillaAvatar => avatar.isEmpty ? nombreCompleto : avatar;
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
  ServicioCuenta(this._repositorio);

  static const String mensajeCredencialesInvalidas =
      'Email o contraseña incorrectos.';
  static const String mensajeTerminosNoAceptados =
      'Para crear la cuenta tenés que aceptar los términos y condiciones.';

  final RepositorioUsuarios _repositorio;
  final Random _azar = Random();

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
    return usuario == null ? null : _aCuenta(usuario);
  }

  /// HU01: crea la cuenta y deja la sesión iniciada.
  Future<CuentaUsuario> registrar({
    required String nombre,
    required String apellido,
    required String email,
    required DateTime? fechaNacimiento,
    required String contrasena,
    required bool aceptaTerminos,
    String avatar = '',
  }) async {
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
      versionTerminos: TerminosCondiciones.version,
      fechaAceptacionTerminos: ahora,
      avatar: avatar.trim(),
    );
    await _repositorio.guardar(usuario);
    await _repositorio.guardarSesion(usuario.id);
    notifyListeners();
    return _aCuenta(usuario);
  }

  /// HU02: inicia sesión. El error no revela si falló el email o la contraseña.
  Future<CuentaUsuario> iniciarSesion({
    required String email,
    required String contrasena,
  }) async {
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
    await _repositorio.guardarSesion(usuario.id);
    notifyListeners();
    return _aCuenta(usuario);
  }

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

  /// Cambia el avatar de la cuenta en sesión.
  Future<CuentaUsuario> cambiarAvatar(String avatar) async {
    final actualizado = _usuarioEnSesion().copiarCon(avatar: avatar.trim());
    await _repositorio.guardar(actualizado);
    notifyListeners();
    return _aCuenta(actualizado);
  }

  /// HU05: cierra la sesión activa.
  Future<void> cerrarSesion() async {
    await _repositorio.borrarSesion();
    notifyListeners();
  }

  Usuario? _usuarioEnSesionOpcional() {
    final id = _repositorio.leerSesion();
    return id == null ? null : _repositorio.buscarPorId(id);
  }

  Usuario _usuarioEnSesion() {
    final usuario = _usuarioEnSesionOpcional();
    if (usuario == null) throw const ErrorCuenta('No hay una sesión activa.');
    return usuario;
  }

  void _exigir(String? error) {
    if (error != null) throw ErrorCuenta(error);
  }

  CuentaUsuario _aCuenta(Usuario usuario) {
    return CuentaUsuario(
      nombre: usuario.nombre,
      apellido: usuario.apellido,
      email: usuario.email,
      fechaNacimiento: usuario.fechaNacimiento,
      fechaAlta: usuario.fechaAlta,
      versionTerminos: usuario.versionTerminos,
      fechaAceptacionTerminos: usuario.fechaAceptacionTerminos,
      avatar: usuario.avatar,
    );
  }
}
