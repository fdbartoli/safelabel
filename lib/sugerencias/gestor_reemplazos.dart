import '../datos/base_conocimiento.dart';
import '../modelo/perfil.dart';
import '../modelo/resultado_analisis.dart';
import 'filtro_reemplazos.dart';
import 'servicio_reemplazos.dart';

class ResultadoReemplazos {
  const ResultadoReemplazos({
    required this.tipoProducto,
    required this.sugerencias,
    required this.descartadas,
  });

  final String tipoProducto;

  /// Ya filtradas: ninguna choca con un perfil activo según la base local.
  final List<SugerenciaReemplazo> sugerencias;

  /// Lo que el LLM propuso y el filtro sacó. Se muestra, por transparencia.
  final List<SugerenciaDescartada> descartadas;
}

/// Orquesta el paso 11 del Flujo B (sección 5.6): arma el pedido con solo
/// texto, llama al LLM y pasa la respuesta por el filtro determinista.
class GestorReemplazos {
  GestorReemplazos({
    required this.base,
    required this.perfilesActivos,
    required this.servicio,
  }) : _filtro = FiltroReemplazos(base, perfilesActivos);

  /// Con la clave inyectada en la compilación. Si no hay clave, [servicio] es
  /// `null` y la pantalla de resultado avisa que la función no está
  /// configurada.
  factory GestorReemplazos.desdeConfiguracion(
    BaseConocimiento base,
    List<Perfil> perfilesActivos,
  ) {
    const clave = ServicioReemplazosGemini.apiKeyDeCompilacion;
    return GestorReemplazos(
      base: base,
      perfilesActivos: perfilesActivos,
      servicio: clave.isEmpty ? null : ServicioReemplazosGemini(apiKey: clave),
    );
  }

  final BaseConocimiento base;
  final List<Perfil> perfilesActivos;
  final ServicioReemplazos? servicio;
  final FiltroReemplazos _filtro;

  bool get configurado => servicio != null;

  /// Solo se piden reemplazos si hay coincidencias con algún perfil.
  bool aplica(ResultadoAnalisis resultado) =>
      resultado.coincidencias.isNotEmpty;

  SolicitudReemplazo construirSolicitud(ResultadoAnalisis resultado) {
    final gruposRestringidos = <String>{
      for (final p in perfilesActivos)
        for (final r in p.restricciones)
          base.grupo(r.grupoAlergenoId)?.nombre ?? r.grupoAlergenoId,
    }.toList();
    return SolicitudReemplazo(
      gruposRestringidos: gruposRestringidos,
      ingredientesConflictivos: [
        for (final h in resultado.coincidencias)
          '${h.textoLeido} (${h.grupoAlergeno})',
      ],
      ingredientesLeidos: resultado.ingredientesLeidos,
    );
  }

  Future<ResultadoReemplazos> obtener(ResultadoAnalisis resultado) async {
    final s = servicio;
    if (s == null) throw const ErrorReemplazos('falta configurar la clave');
    final respuesta = await s.sugerir(construirSolicitud(resultado));
    final filtrado = _filtro.filtrar(respuesta.sugerencias);
    return ResultadoReemplazos(
      tipoProducto: respuesta.tipoProducto,
      sugerencias: filtrado.aceptadas,
      descartadas: filtrado.descartadas,
    );
  }
}
