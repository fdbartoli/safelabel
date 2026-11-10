import 'dart:convert';

import '../modelo/perfil.dart';

class ErrorRestriccionesCompartidas implements Exception {
  const ErrorRestriccionesCompartidas(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Documento de intercambio con el nombre del propietario y sus restricciones.
///
/// Los QR v1 anteriores no incluían nombre. Se siguen aceptando y, en ese
/// caso, [nombreCompleto] cae en [nombreAnterior] para que el receptor pueda
/// guardar la copia sin escribir nada.
class RestriccionesCompartidas {
  RestriccionesCompartidas._({
    required this.version,
    required this.nombre,
    required this.apellido,
    required Iterable<RestriccionPerfil> restricciones,
  }) : restricciones = List.unmodifiable(restricciones);

  final int version;
  final String nombre;
  final String apellido;
  final List<RestriccionPerfil> restricciones;

  String get nombreCompleto => '$nombre $apellido'.trim();

  bool get esVersionAnterior => version == 1;
}

class CodecRestriccionesCompartidas {
  CodecRestriccionesCompartidas(Set<String> gruposValidos)
    : gruposValidos = Set.unmodifiable(gruposValidos);

  static const limiteBytes = 2048;
  static const tipo = 'safelabel.restricciones';
  static const esquema = 'perfiles-locales-v1';
  static const versionActual = 2;
  static const versionAnterior = 1;
  static const nombreAnterior = 'Perfil recibido';
  static const largoMaximoNombre = 60;
  static final _caracteresDeControl = RegExp(r'[\u0000-\u001F\u007F]');

  final Set<String> gruposValidos;

  String codificar(
    List<RestriccionPerfil> restricciones, {
    required String nombre,
    required String apellido,
  }) {
    final nombreValido = _validarParteNombre(nombre, 'nombre');
    final apellidoValido = _validarParteNombre(apellido, 'apellido');
    _validarNombreCompleto(nombreValido, apellidoValido);
    final texto = jsonEncode({
      'tipo': tipo,
      'version': versionActual,
      'esquema_grupos': esquema,
      'nombre': nombreValido,
      'apellido': apellidoValido,
      'restricciones': [
        for (final r in restricciones)
          {
            'grupo_alergeno_id': r.grupoAlergenoId,
            'severidad': r.severidad.name,
          },
      ],
    });
    // Exportar también exige una lista completa y válida; nunca omite grupos.
    decodificar(texto);
    return texto;
  }

  RestriccionesCompartidas decodificar(String texto) {
    if (texto.length > limiteBytes || utf8.encode(texto).length > limiteBytes) {
      throw const ErrorRestriccionesCompartidas(
        'El QR supera el tamaño permitido.',
      );
    }
    try {
      _comprobarClavesYProfundidad(texto);
      final datos = jsonDecode(texto);
      if (datos is! Map<String, dynamic>) throw const FormatException();
      if (datos['tipo'] != tipo || datos['esquema_grupos'] != esquema) {
        throw const ErrorRestriccionesCompartidas(
          'Este QR no es de restricciones de SafeLabel o usa una versión incompatible.',
        );
      }

      final version = datos['version'];
      if (version is! int) {
        throw const ErrorRestriccionesCompartidas(
          'Este QR no es de restricciones de SafeLabel o usa una versión incompatible.',
        );
      }
      if (version == versionAnterior) {
        if (!_clavesExactas(datos, {
          'tipo',
          'version',
          'esquema_grupos',
          'restricciones',
        })) {
          throw const FormatException();
        }
        return RestriccionesCompartidas._(
          version: versionAnterior,
          nombre: nombreAnterior,
          apellido: '',
          restricciones: _leerRestricciones(datos['restricciones']),
        );
      }
      if (version == versionActual) {
        if (!_clavesExactas(datos, {
          'tipo',
          'version',
          'esquema_grupos',
          'nombre',
          'apellido',
          'restricciones',
        })) {
          throw const FormatException();
        }
        final nombre = _validarParteNombre(datos['nombre'], 'nombre');
        final apellido = _validarParteNombre(datos['apellido'], 'apellido');
        _validarNombreCompleto(nombre, apellido);
        return RestriccionesCompartidas._(
          version: versionActual,
          nombre: nombre,
          apellido: apellido,
          restricciones: _leerRestricciones(datos['restricciones']),
        );
      }
      throw const ErrorRestriccionesCompartidas(
        'Este QR no es de restricciones de SafeLabel o usa una versión incompatible.',
      );
    } on FormatException {
      throw const ErrorRestriccionesCompartidas(
        'El contenido del QR no tiene un formato válido.',
      );
    }
  }

  List<RestriccionPerfil> _leerRestricciones(Object? lista) {
    if (lista is! List ||
        lista.isEmpty ||
        lista.length > gruposValidos.length) {
      throw const ErrorRestriccionesCompartidas(
        'El QR debe contener una lista no vacía de restricciones válidas.',
      );
    }
    final vistos = <String>{};
    final restricciones = <RestriccionPerfil>[];
    for (final fila in lista) {
      if (fila is! Map<String, dynamic> ||
          !_clavesExactas(fila, {'grupo_alergeno_id', 'severidad'})) {
        throw const FormatException();
      }
      final grupo = fila['grupo_alergeno_id'];
      if (grupo is! String || !gruposValidos.contains(grupo)) {
        throw const ErrorRestriccionesCompartidas(
          'El QR contiene un grupo que esta versión de SafeLabel no reconoce.',
        );
      }
      if (!vistos.add(grupo)) {
        throw const ErrorRestriccionesCompartidas(
          'El QR contiene grupos repetidos.',
        );
      }
      final Severidad severidad;
      switch (fila['severidad']) {
        case 'leve':
          severidad = Severidad.leve;
        case 'moderada':
          severidad = Severidad.moderada;
        case 'anafilaxia':
          severidad = Severidad.anafilaxia;
        default:
          throw const ErrorRestriccionesCompartidas(
            'El QR contiene una severidad inválida.',
          );
      }
      restricciones.add(
        RestriccionPerfil(grupoAlergenoId: grupo, severidad: severidad),
      );
    }
    return restricciones;
  }

  String _validarParteNombre(Object? valor, String campo) {
    if (valor is! String) {
      throw ErrorRestriccionesCompartidas(
        'El QR debe incluir el $campo del propietario.',
      );
    }
    final texto = valor.trim();
    if (texto.isEmpty) {
      throw ErrorRestriccionesCompartidas(
        'El QR debe incluir el $campo del propietario.',
      );
    }
    if (texto.runes.length > largoMaximoNombre ||
        _caracteresDeControl.hasMatch(texto)) {
      throw ErrorRestriccionesCompartidas(
        'El $campo del propietario no es válido.',
      );
    }
    return texto;
  }

  void _validarNombreCompleto(String nombre, String apellido) {
    if ('$nombre $apellido'.runes.length > largoMaximoNombre) {
      throw const ErrorRestriccionesCompartidas(
        'El nombre y apellido del propietario son demasiado largos.',
      );
    }
  }

  bool _clavesExactas(Map<String, dynamic> mapa, Set<String> esperadas) =>
      mapa.length == esperadas.length && esperadas.containsAll(mapa.keys);

  /// jsonDecode acepta claves de objeto duplicadas. Rechazarlas antes evita
  /// que una segunda lista o severidad reemplace silenciosamente la primera.
  /// Los documentos v1 y v2 solo necesitan tres niveles (objeto, lista, objeto).
  void _comprobarClavesYProfundidad(String texto) {
    final pila = <Set<String>?>[];
    for (var i = 0; i < texto.length; i++) {
      final c = texto[i];
      if (c == '"') {
        final inicio = i;
        var cerrado = false;
        while (++i < texto.length) {
          if (texto[i] == r'\') {
            i++;
            continue;
          }
          if (texto[i] == '"') {
            cerrado = true;
            break;
          }
        }
        if (!cerrado) throw const FormatException();
        var siguiente = i + 1;
        while (siguiente < texto.length && texto[siguiente].trim().isEmpty) {
          siguiente++;
        }
        if (siguiente < texto.length && texto[siguiente] == ':') {
          if (pila.isEmpty || pila.last == null) throw const FormatException();
          final clave = jsonDecode(texto.substring(inicio, i + 1)) as String;
          if (!pila.last!.add(clave)) throw const FormatException();
        }
      } else if (c == '{' || c == '[') {
        pila.add(c == '{' ? <String>{} : null);
        if (pila.length > 3) throw const FormatException();
      } else if (c == '}' || c == ']') {
        if (pila.isEmpty ||
            (c == '}' && pila.last == null) ||
            (c == ']' && pila.last != null)) {
          throw const FormatException();
        }
        pila.removeLast();
      }
    }
    if (pila.isNotEmpty) throw const FormatException();
  }
}
