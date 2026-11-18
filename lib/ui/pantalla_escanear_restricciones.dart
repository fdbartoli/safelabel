import 'package:flutter/material.dart';

import '../compartir/servicio_compartir_restricciones.dart';
import '../datos/base_conocimiento.dart';
import 'camara_qr.dart';
import 'pantalla_importar_restricciones.dart';

typedef ConstructorCamaraQr = Widget Function(ValueChanged<String> alLeer);

class PantallaEscanearRestricciones extends StatefulWidget {
  const PantallaEscanearRestricciones({
    super.key,
    required this.servicio,
    required this.base,
    this.construirCamara,
  });

  final ServicioCompartirRestricciones servicio;
  final BaseConocimiento base;

  /// Permite probar navegación y detecciones repetidas sin una cámara física.
  final ConstructorCamaraQr? construirCamara;

  @override
  State<PantallaEscanearRestricciones> createState() =>
      _PantallaEscanearRestriccionesState();
}

class _PantallaEscanearRestriccionesState
    extends State<PantallaEscanearRestricciones> {
  bool _procesando = false;

  Future<void> _leer(String texto) async {
    if (_procesando || !mounted) return;
    setState(() => _procesando = true);
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaImportarRestricciones(
          textoQr: texto,
          servicio: widget.servicio,
          base: widget.base,
        ),
      ),
    );
    if (!mounted) return;
    if (guardado == true) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear restricciones')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Apuntá al QR generado desde Perfiles en SafeLabel. '
            'Nada se guarda hasta que confirmes la vista previa.',
          ),
        ),
        Expanded(
          child: _procesando
              ? const Center(child: CircularProgressIndicator())
              : widget.construirCamara?.call(_leer) ?? CamaraQr(alLeer: _leer),
        ),
      ],
    ),
  );
}
