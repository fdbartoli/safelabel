import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Las contraseñas nunca se guardan en texto plano: se guarda un hash
/// SHA-256 calculado con un salt aleatorio propio de cada usuario.
class SeguridadContrasena {
  SeguridadContrasena._();

  static final Random _azar = Random.secure();

  static String generarSalt() {
    final bytes = List<int>.generate(16, (_) => _azar.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String calcularHash(String contrasena, String salt) {
    final bytes = utf8.encode('$salt:$contrasena');
    return sha256.convert(bytes).toString();
  }

  static bool verificar(String contrasena, String salt, String hashGuardado) {
    return calcularHash(contrasena, salt) == hashGuardado;
  }
}
