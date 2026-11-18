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

  Future<String> generarQr(List<Perfil> perfiles) async {
    return codec.codificar(
      perfiles,
      nombre: nombrePropietario,
      apellido: apellidoPropietario,
    );
  }

  PerfilesCompartidos leerQr(String texto) => codec.decodificar(texto);

  Future<List<Perfil>> guardarCopias(String texto) {
    // Volver a validar al guardar; los datos del QR nunca deciden identidad.
    final recibido = leerQr(texto);
    return repositorio.crearRecibidos([
      for (final perfil in recibido.perfiles)
        Perfil(nombre: perfil.nombre, restricciones: perfil.restricciones),
    ]);
  }
}
