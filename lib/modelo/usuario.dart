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
    this.avatar = '',
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

  /// Versión de los términos y condiciones aceptada al registrarse.
  final String? versionTerminos;
  final DateTime? fechaAceptacionTerminos;

  /// Semilla del avatar de la cuenta (ver `ui/avatar.dart`). Vacía en cuentas
  /// creadas antes de que existieran los avatares: ahí se usa el nombre.
  final String avatar;

  Usuario copiarCon({
    String? nombre,
    String? apellido,
    String? email,
    DateTime? fechaNacimiento,
    String? hashContrasena,
    String? salt,
    String? avatar,
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
      versionTerminos: versionTerminos,
      fechaAceptacionTerminos: fechaAceptacionTerminos,
      avatar: avatar ?? this.avatar,
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
      'versionTerminos': versionTerminos,
      'fechaAceptacionTerminos': fechaAceptacionTerminos?.toIso8601String(),
      'avatar': avatar,
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
      versionTerminos: mapa['versionTerminos'] as String?,
      fechaAceptacionTerminos: _leerFecha(mapa['fechaAceptacionTerminos']),
      avatar: mapa['avatar'] as String? ?? '',
    );
  }

  static DateTime? _leerFecha(Object? valor) {
    return valor is String ? DateTime.tryParse(valor) : null;
  }
}
