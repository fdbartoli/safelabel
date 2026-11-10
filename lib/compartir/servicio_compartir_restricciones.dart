import '../datos/repositorio_perfiles.dart';
import '../modelo/perfil.dart';
import 'restricciones_compartidas.dart';

class ServicioCompartirRestricciones {
  ServicioCompartirRestricciones({
    required this.repositorio,
    required Set<String> gruposValidos,
    required this.nombrePropietario,
    required this.apellidoPropietario,
  }) : codec = CodecRestriccionesCompartidas(gruposValidos);

  final RepositorioPerfiles repositorio;
  final CodecRestriccionesCompartidas codec;
  final String nombrePropietario;
  final String apellidoPropietario;

  Future<String> generarQrPersonal() async {
    // No se acepta un ID ni un perfil arbitrario del llamador.
    final personal = await repositorio.obtenerPersonal();
    if (personal == null || !personal.esPersonal) {
      throw const ErrorRestriccionesCompartidas(
        'No se encontró Mi perfil en esta cuenta.',
      );
    }
    if (personal.restricciones.isEmpty) {
      throw const ErrorRestriccionesCompartidas(
        'Agregá restricciones a Mi perfil antes de compartirlo.',
      );
    }
    return codec.codificar(
      personal.restricciones,
      nombre: nombrePropietario,
      apellido: apellidoPropietario,
    );
  }

  RestriccionesCompartidas leerQr(String texto) => codec.decodificar(texto);

  Future<Perfil> guardarCopia(String texto) {
    // Volver a validar al guardar; los datos del QR nunca deciden identidad.
    final recibido = leerQr(texto);
    return repositorio.crearAdicionalRecibido(
      Perfil(
        nombre: recibido.nombreCompleto,
        restricciones: recibido.restricciones,
      ),
    );
  }
}
