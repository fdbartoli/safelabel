import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../datos/base_conocimiento.dart';
import '../modelo/perfil.dart';
import '../ocr/guia_captura.dart';
import '../ocr/servicio_ocr.dart';
import '../ocr/servicio_ocr_mlkit.dart';
import '../ocr/triage_confianza.dart';
import '../pipeline/analizador.dart';
import 'pantalla_resultado.dart';

/// Paso 1 del Flujo B: cámara con guía activa de captura.
///
/// La guía se muestra en positivo (hacia dónde ir), tanto como recuadro fijo
/// antes de la foto como sugerencias concretas si la lectura salió pobre.
class PantallaCaptura extends StatefulWidget {
  const PantallaCaptura({
    super.key,
    required this.base,
    required this.perfilesActivos,
    this.servicioOcr,
  });

  final BaseConocimiento base;
  final List<Perfil> perfilesActivos;

  /// Inyectable para tests; por defecto usa ML Kit / Vision.
  final ServicioOcr? servicioOcr;

  @override
  State<PantallaCaptura> createState() => _PantallaCapturaState();
}

class _PantallaCapturaState extends State<PantallaCaptura> {
  CameraController? _camara;
  late final ServicioOcr _ocr;
  final _triage = const TriageConfianza();
  final _evaluador = const EvaluadorCaptura();

  String? _error;
  bool _procesando = false;
  List<SugerenciaCaptura> _sugerencias = const [];

  @override
  void initState() {
    super.initState();
    _ocr = widget.servicioOcr ?? ServicioOcrMlKit();
    _iniciarCamara();
  }

  Future<void> _iniciarCamara() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) {
        setState(() => _error = 'No se encontró una cámara en el dispositivo.');
        return;
      }
      final trasera = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      final controller = CameraController(
        trasera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _camara = controller);
    } catch (e) {
      setState(() => _error = 'No se pudo abrir la cámara: $e');
    }
  }

  @override
  void dispose() {
    _camara?.dispose();
    _ocr.liberar();
    super.dispose();
  }

  Future<void> _capturarYAnalizar() async {
    final camara = _camara;
    if (camara == null || _procesando) return;
    setState(() {
      _procesando = true;
      _sugerencias = const [];
    });
    try {
      final foto = await camara.takePicture();
      final lectura = await _ocr.reconocer(foto.path);
      final triage = _triage.clasificar(lectura);
      final sugerencias = _evaluador.evaluar(lectura, triage);

      final resultado = Analizador(widget.base, triage: _triage).analizar(
        lectura,
        perfilesActivos: widget.perfilesActivos,
      );

      if (!mounted) return;

      // Si la lectura fue muy pobre y no hubo nada útil, guiar antes de mostrar
      // un resultado casi vacío.
      final lecturaInutil = resultado.itemsAnalizados == 0 &&
          resultado.coincidencias.isEmpty;
      if (sugerencias.isNotEmpty && lecturaInutil) {
        setState(() => _sugerencias = sugerencias);
        return;
      }

      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PantallaResultado(resultado: resultado),
      ));
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al procesar la foto: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear etiqueta')),
      body: _error != null
          ? _VistaError(mensaje: _error!)
          : _camara == null
              ? const Center(child: CircularProgressIndicator())
              : _VistaCamara(
                  controller: _camara!,
                  procesando: _procesando,
                  sugerencias: _sugerencias,
                  onCapturar: _capturarYAnalizar,
                ),
    );
  }
}

class _VistaCamara extends StatelessWidget {
  const _VistaCamara({
    required this.controller,
    required this.procesando,
    required this.sugerencias,
    required this.onCapturar,
  });

  final CameraController controller;
  final bool procesando;
  final List<SugerenciaCaptura> sugerencias;
  final VoidCallback onCapturar;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        // Recuadro guía.
        Center(
          child: FractionallySizedBox(
            widthFactor: 0.86,
            heightFactor: 0.44,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 16,
          child: _Tarjeta(
            child: Text(
              sugerencias.isEmpty
                  ? 'Encuadrá la lista de ingredientes y la línea "CONTIENE" '
                      'dentro del recuadro. Buena luz, sin reflejo, envase lo '
                      'más plano posible.'
                  : sugerencias.map((s) => '• ${s.mensaje}').join('\n'),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 32,
          child: Center(
            child: FilledButton.icon(
              onPressed: procesando ? null : onCapturar,
              icon: procesando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(procesando ? 'Leyendo…' : 'Tomar foto'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
        child: child,
      ),
    );
  }
}

class _VistaError extends StatelessWidget {
  const _VistaError({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera_back_outlined, size: 40),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Podés usar "Analizar texto pegado" desde la pantalla anterior '
              'para probar el resto del pipeline sin cámara.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
