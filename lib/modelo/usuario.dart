/// Entidad del dominio que representa a una persona registrada.
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.fechaNacimiento,
    required this.hashContrasena,
    required this.salt,
    required this.fechaAlta,
    this.versionTerminos,
    this.fechaAceptacionTerminos,
    this.incluirPerfilesDemostracion = false,
  });

  final String id;
  final String nombre;
  final String apellido;
  final String email;

  /// Puede faltar en cuentas creadas antes de que existiera este dato.
  final DateTime? fechaNacimiento;
  final String hashContrasena;
  final String salt;
  final DateTime fechaAlta;

  /// Intención persistida al registrar cuentas nuevas. Las cuentas anteriores
  /// no tienen este campo y no reciben ejemplos retroactivamente. La carga
  /// completada se registra por separado en SQLite y nunca se repite.
  final bool incluirPerfilesDemostracion;

  /// Versión de los términos y condiciones aceptada al registrarse.
  final String? versionTerminos;
  final DateTime? fechaAceptacionTerminos;

  Usuario copiarCon({
    String? nombre,
    String? apellido,
    String? email,
    DateTime? fechaNacimiento,
    String? hashContrasena,
    String? salt,
  }) {
    return Usuario(
      id: id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      email: email ?? this.email,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      hashContrasena: hashContrasena ?? this.hashContrasena,
      salt: salt ?? this.salt,
      fechaAlta: fechaAlta,
      incluirPerfilesDemostracion: incluirPerfilesDemostracion,
      versionTerminos: versionTerminos,
      fechaAceptacionTerminos: fechaAceptacionTerminos,
    );
  }

  Map<String, dynamic> aMapa() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      'fechaNacimiento': fechaNacimiento?.toIso8601String(),
      'hashContrasena': hashContrasena,
      'salt': salt,
      'fechaAlta': fechaAlta.toIso8601String(),
      'incluirPerfilesDemostracion': incluirPerfilesDemostracion,
      'versionTerminos': versionTerminos,
      'fechaAceptacionTerminos': fechaAceptacionTerminos?.toIso8601String(),
    };
  }

  factory Usuario.desdeMapa(Map<String, dynamic> mapa) {
    return Usuario(
      id: mapa['id'] as String,
      nombre: mapa['nombre'] as String,
      apellido: mapa['apellido'] as String? ?? '',
      email: mapa['email'] as String,
      fechaNacimiento: _leerFecha(mapa['fechaNacimiento']),
      hashContrasena: mapa['hashContrasena'] as String,
      salt: mapa['salt'] as String,
      fechaAlta: DateTime.parse(mapa['fechaAlta'] as String),
      incluirPerfilesDemostracion: mapa['incluirPerfilesDemostracion'] == true,
      versionTerminos: mapa['versionTerminos'] as String?,
      fechaAceptacionTerminos: _leerFecha(mapa['fechaAceptacionTerminos']),
    );
  }

  static DateTime? _leerFecha(Object? valor) {
    return valor is String ? DateTime.tryParse(valor) : null;
  }
}
