import 'dart:convert';

import '../modelo/perfil.dart';

class ErrorRestriccionesCompartidas implements Exception {
  const ErrorRestriccionesCompartidas(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Un perfil dentro de un documento de intercambio.
class PerfilCompartido {
  PerfilCompartido({
    required this.nombre,
    required Iterable<RestriccionPerfil> restricciones,
  }) : restricciones = List.unmodifiable(restricciones);

  final String nombre;
  final List<RestriccionPerfil> restricciones;
}

/// Documento de intercambio con el nombre del propietario y los perfiles que
/// eligió compartir.
class PerfilesCompartidos {
  PerfilesCompartidos._({
    required this.version,
    required this.nombre,
    required this.apellido,
    required Iterable<PerfilCompartido> perfiles,
  }) : perfiles = List.unmodifiable(perfiles);

  final int version;
  final String nombre;
  final String apellido;
  final List<PerfilCompartido> perfiles;

  String get nombreCompleto => '$nombre $apellido'.trim();

  bool get esVersionAnterior =>
      version < CodecRestriccionesCompartidas.versionActual;
}

class CodecRestriccionesCompartidas {
  CodecRestriccionesCompartidas(Set<String> gruposValidos)
    : gruposValidos = Set.unmodifiable(gruposValidos);

  static const limiteBytes = 2048;
  static const tipo = 'safelabel.restricciones';
  static const esquema = 'perfiles-locales-v1';
  static const versionActual = 3;
  static const versionV2 = 2;
  static const versionAnterior = 1;
  static const nombreAnterior = 'Perfil recibido';
  static const largoMaximoNombre = 60;
  static const mensajeTamanoExcedido =
      'La selección supera el límite de 2048 bytes del QR. '
      'Compartí menos perfiles.';
  static final _caracteresDeControl = RegExp(r'[\u0000-\u001F\u007F]');

  final Set<String> gruposValidos;

  String codificar(
    List<Perfil> perfiles, {
    required String nombre,
    required String apellido,
  }) {
    if (perfiles.isEmpty) {
      throw const ErrorRestriccionesCompartidas(
        'Elegí al menos un perfil para compartir.',
      );
    }
    final nombreValido = _validarParteNombre(nombre, 'nombre');
    final apellidoValido = _validarParteNombre(apellido, 'apellido');
    _validarNombreCompleto(nombreValido, apellidoValido);
    final texto = jsonEncode({
      'tipo': tipo,
      'version': versionActual,
      'esquema_grupos': esquema,
      'nombre': nombreValido,
      'apellido': apellidoValido,
      'perfiles': [
        for (final perfil in perfiles)
          {
            'nombre': _validarNombrePerfil(perfil.nombre),
            'restricciones': _serializarRestricciones(perfil.restricciones),
          },
      ],
    });
    // Exportar también exige un documento completo y válido; nunca omite
    // perfiles ni grupos.
    decodificar(texto);
    return texto;
  }

  PerfilesCompartidos decodificar(String texto) {
    if (texto.length > limiteBytes || utf8.encode(texto).length > limiteBytes) {
      throw const ErrorRestriccionesCompartidas(mensajeTamanoExcedido);
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
        return PerfilesCompartidos._(
          version: versionAnterior,
          nombre: '',
          apellido: '',
          perfiles: [
            PerfilCompartido(
              nombre: nombreAnterior,
              restricciones: _leerRestricciones(datos['restricciones']),
            ),
          ],
        );
      }
      if (version == versionV2) {
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
        final completo = '$nombre $apellido'.trim();
        return PerfilesCompartidos._(
          version: versionV2,
          nombre: nombre,
          apellido: apellido,
          perfiles: [
            PerfilCompartido(
              nombre: completo,
              restricciones: _leerRestricciones(datos['restricciones']),
            ),
          ],
        );
      }
      if (version == versionActual) {
        if (!_clavesExactas(datos, {
          'tipo',
          'version',
          'esquema_grupos',
          'nombre',
          'apellido',
          'perfiles',
        })) {
          throw const FormatException();
        }
        final nombre = _validarParteNombre(datos['nombre'], 'nombre');
        final apellido = _validarParteNombre(datos['apellido'], 'apellido');
        _validarNombreCompleto(nombre, apellido);
        return PerfilesCompartidos._(
          version: versionActual,
          nombre: nombre,
          apellido: apellido,
          perfiles: _leerPerfiles(datos['perfiles']),
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

  List<PerfilCompartido> _leerPerfiles(Object? lista) {
    if (lista is! List || lista.isEmpty) {
      throw const ErrorRestriccionesCompartidas(
        'El QR debe incluir al menos un perfil.',
      );
    }
    return [
      for (final fila in lista)
        if (fila is Map<String, dynamic> &&
            _clavesExactas(fila, {'nombre', 'restricciones'}))
          PerfilCompartido(
            nombre: _validarNombrePerfil(fila['nombre']),
            restricciones: _leerRestricciones(fila['restricciones']),
          )
        else
          throw const FormatException(),
    ];
  }

  List<Map<String, String>> _serializarRestricciones(
    List<RestriccionPerfil> restricciones,
  ) {
    final vistos = <String>{};
    final salida = <Map<String, String>>[];
    for (final r in restricciones) {
      if (!gruposValidos.contains(r.grupoAlergenoId)) {
        throw const ErrorRestriccionesCompartidas(
          'El QR contiene un grupo que esta versión de SafeLabel no reconoce.',
        );
      }
      if (!vistos.add(r.grupoAlergenoId)) {
        throw const ErrorRestriccionesCompartidas(
          'El QR contiene grupos repetidos.',
        );
      }
      salida.add({
        'grupo_alergeno_id': r.grupoAlergenoId,
        'severidad': r.severidad.name,
      });
    }
    return salida;
  }

  List<RestriccionPerfil> _leerRestricciones(Object? lista) {
    if (lista is! List) {
      throw const ErrorRestriccionesCompartidas(
        'El QR debe contener una lista de restricciones válida.',
      );
    }
    if (lista.length > gruposValidos.length) {
      throw const ErrorRestriccionesCompartidas(
        'El QR contiene más restricciones de las permitidas.',
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
    return List.unmodifiable(restricciones);
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

  String _validarNombrePerfil(Object? valor) {
    if (valor is! String) {
      throw const ErrorRestriccionesCompartidas(
        'El QR debe incluir el nombre de cada perfil.',
      );
    }
    final texto = valor.trim();
    if (texto.isEmpty) {
      throw const ErrorRestriccionesCompartidas(
        'El QR debe incluir el nombre de cada perfil.',
      );
    }
    if (texto.runes.length > largoMaximoNombre ||
        _caracteresDeControl.hasMatch(texto)) {
      throw const ErrorRestriccionesCompartidas(
        'El nombre de un perfil no es válido.',
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
  /// v3 necesita cinco niveles: objeto, perfiles, perfil, restricciones y
  /// restricción.
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
        if (pila.length > 5) throw const FormatException();
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
