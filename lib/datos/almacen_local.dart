import 'package:shared_preferences/shared_preferences.dart';

/// Capa de datos: lectura y escritura en el almacenamiento local.
///
/// En Android usa SharedPreferences y en Chrome el localStorage del navegador.
class AlmacenLocal {
  AlmacenLocal(this._preferencias);

  final SharedPreferences _preferencias;

  static Future<AlmacenLocal> abrir() async {
    final preferencias = await SharedPreferences.getInstance();
    return AlmacenLocal(preferencias);
  }

  String? leerTexto(String clave) => _preferencias.getString(clave);

  Future<void> guardarTexto(String clave, String valor) async {
    if (!await _preferencias.setString(clave, valor)) {
      throw StateError('No se pudo guardar en el almacenamiento local.');
    }
  }

  Future<void> borrar(String clave) async {
    if (!await _preferencias.remove(clave)) {
      throw StateError('No se pudo borrar del almacenamiento local.');
    }
  }
}
