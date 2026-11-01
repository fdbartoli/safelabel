/// Reglas de validación de los datos de una cuenta.
///
/// Cada función `validar...` devuelve null si el dato es válido, o el
/// mensaje de error para mostrar.
class ReglasUsuario {
  ReglasUsuario._();

  static const int largoMinimoContrasena = 8;
  static const int largoMaximoNombre = 60;

  /// Edad mínima para crear una cuenta (ver sección 6 de los términos).
  static const int edadMinima = 13;
  static final RegExp _formatoEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String normalizarEmail(String email) => email.trim().toLowerCase();

  static String? validarNombre(String? nombre) {
    return _validarTextoObligatorio(nombre, 'Ingresá tu nombre.', 'nombre');
  }

  static String? validarApellido(String? apellido) {
    return _validarTextoObligatorio(
      apellido,
      'Ingresá tu apellido.',
      'apellido',
    );
  }

  static String? validarEmail(String? email) {
    final valor = email?.trim() ?? '';
    if (valor.isEmpty) return 'Ingresá tu email.';
    if (!_formatoEmail.hasMatch(valor)) {
      return 'El formato del email no es válido.';
    }
    return null;
  }

  static String? validarContrasena(String? contrasena) {
    final valor = contrasena ?? '';
    if (valor.isEmpty) return 'Ingresá una contraseña.';
    if (valor.length < largoMinimoContrasena) {
      return 'La contraseña debe tener al menos $largoMinimoContrasena caracteres.';
    }
    return null;
  }

  /// Convierte un texto dd/mm/aaaa en fecha. Devuelve null si no es una
  /// fecha real (por ejemplo, 31/02/2000).
  static DateTime? parsearFecha(String? texto) {
    final partes = (texto ?? '').trim().split('/');
    if (partes.length != 3 || partes[2].length != 4) return null;
    final dia = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final anio = int.tryParse(partes[2]);
    if (dia == null || mes == null || anio == null) return null;
    final fecha = DateTime(anio, mes, dia);
    final esReal = fecha.year == anio && fecha.month == mes && fecha.day == dia;
    return esReal ? fecha : null;
  }

  static int calcularEdad(DateTime nacimiento, DateTime hoy) {
    var edad = hoy.year - nacimiento.year;
    final todaviaNoCumplio =
        hoy.month < nacimiento.month ||
        (hoy.month == nacimiento.month && hoy.day < nacimiento.day);
    if (todaviaNoCumplio) edad--;
    return edad;
  }

  static String? validarFechaNacimiento(DateTime? fecha, {DateTime? hoy}) {
    if (fecha == null) return 'Ingresá tu fecha de nacimiento (dd/mm/aaaa).';
    final ahora = hoy ?? DateTime.now();
    if (fecha.isAfter(ahora)) {
      return 'La fecha de nacimiento no puede ser futura.';
    }
    if (fecha.year < 1900) return 'Revisá el año de nacimiento.';
    if (calcularEdad(fecha, ahora) < edadMinima) {
      return 'Tenés que tener al menos $edadMinima años para crear una cuenta.';
    }
    return null;
  }

  /// Valida el texto que se escribe en el formulario.
  static String? validarTextoFechaNacimiento(String? texto) {
    if (texto == null || texto.trim().isEmpty) {
      return 'Ingresá tu fecha de nacimiento.';
    }
    final fecha = parsearFecha(texto);
    if (fecha == null) {
      return 'Usá el formato dd/mm/aaaa, por ejemplo 15/03/1995.';
    }
    return validarFechaNacimiento(fecha);
  }

  static String? _validarTextoObligatorio(
    String? texto,
    String mensajeVacio,
    String dato,
  ) {
    final valor = texto?.trim() ?? '';
    if (valor.isEmpty) return mensajeVacio;
    if (valor.length > largoMaximoNombre) {
      return 'El $dato no puede superar los $largoMaximoNombre caracteres.';
    }
    return null;
  }
}
