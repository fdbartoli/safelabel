import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Lector separado de la cámara OCR. En web se usa ZXing empaquetado con la
/// aplicación; no se descarga código ni se envían imágenes a un servidor.
class CamaraQr extends StatefulWidget {
  const CamaraQr({super.key, required this.alLeer});
  final ValueChanged<String> alLeer;

  @override
  State<CamaraQr> createState() => _CamaraQrState();
}

class _CamaraQrState extends State<CamaraQr> with WidgetsBindingObserver {
  late final MobileScannerController _controlador;
  bool _entregado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      MobileScannerPlatform.instance.setWebBarcodeReader(
        WebBarcodeReader.zxingJs,
      );
      MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(
        Uri.base.resolve('vendor/zxing/index.min.js').toString(),
      );
    }
    _controlador = MobileScannerController(
      autoStart: false,
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciar());
  }

  Future<void> _iniciar() async {
    if (!mounted || _entregado) return;
    setState(() => _error = null);
    try {
      await _controlador.start();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo abrir el lector. '
              'Revisá el permiso de cámara y que no esté ocupada. '
              'En Chrome usá HTTPS o localhost.',
        );
      }
    }
  }

  Future<void> _detectar(BarcodeCapture captura) async {
    if (_entregado) return;
    String? texto;
    for (final codigo in captura.barcodes) {
      if (codigo.rawValue case final valor? when valor.isNotEmpty) {
        texto = valor;
        break;
      }
    }
    if (texto == null) return;
    _entregado = true;
    await _detener();
    if (mounted) widget.alLeer(texto);
  }

  Future<void> _detener() async {
    try {
      await _controlador.stop();
    } catch (_) {
      /* Ya liberada. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // El diálogo de permisos también cambia el ciclo de vida; no interrumpir
    // la solicitud inicial mientras todavía no hay permiso de cámara.
    if (!_controlador.value.hasCameraPermission) return;
    if (estado == AppLifecycleState.resumed) {
      unawaited(_iniciar());
    } else {
      unawaited(_detener());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controlador.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      MobileScanner(
        controller: _controlador,
        onDetect: _detectar,
        errorBuilder: (context, error) =>
            const Center(child: Text('No se pudo acceder a la cámara.')),
      ),
      if (_error != null)
        ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _iniciar,
                    child: const Text('Reintentar cámara'),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
