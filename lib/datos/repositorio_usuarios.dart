import 'dart:convert';

import '../modelo/usuario.dart';
import 'almacen_local.dart';

/// Guarda y recupera usuarios y la sesión activa en el almacenamiento local.
class RepositorioUsuarios {
  RepositorioUsuarios(this._almacen);

  static const String claveUsuarios = 'safelabel.usuarios';
  static const String claveSesion = 'safelabel.sesion_usuario_id';

  final AlmacenLocal _almacen;

  List<Usuario> obtenerTodos() {
    final texto = _almacen.leerTexto(claveUsuarios);
    if (texto == null) return [];
    final lista = jsonDecode(texto) as List<dynamic>;
    return lista
        .map((elemento) => Usuario.desdeMapa(elemento as Map<String, dynamic>))
        .toList();
  }

  Usuario? buscarPorEmail(String emailNormalizado) {
    for (final usuario in obtenerTodos()) {
      if (usuario.email == emailNormalizado) return usuario;
    }
    return null;
  }

  Usuario? buscarPorId(String id) {
    for (final usuario in obtenerTodos()) {
      if (usuario.id == id) return usuario;
    }
    return null;
  }

  Future<void> guardar(Usuario usuario) async {
    final usuarios = obtenerTodos();
    final indice = usuarios.indexWhere((u) => u.id == usuario.id);
    if (indice >= 0) {
      usuarios[indice] = usuario;
    } else {
      usuarios.add(usuario);
    }
    final texto = jsonEncode(usuarios.map((u) => u.aMapa()).toList());
    await _almacen.guardarTexto(claveUsuarios, texto);
  }

  String? leerSesion() => _almacen.leerTexto(claveSesion);

  Future<void> guardarSesion(String idUsuario) {
    return _almacen.guardarTexto(claveSesion, idUsuario);
  }

  Future<void> borrarSesion() => _almacen.borrar(claveSesion);
}
