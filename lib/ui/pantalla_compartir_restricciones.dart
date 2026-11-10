import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../compartir/restricciones_compartidas.dart';
import '../compartir/servicio_compartir_restricciones.dart';
import '../datos/base_conocimiento.dart';
import 'componentes_cuenta.dart';
import 'lista_restricciones_compartidas.dart';

class PantallaCompartirRestricciones extends StatefulWidget {
  const PantallaCompartirRestricciones({
    super.key,
    required this.servicio,
    required this.base,
  });

  final ServicioCompartirRestricciones servicio;
  final BaseConocimiento base;

  @override
  State<PantallaCompartirRestricciones> createState() =>
      _PantallaCompartirRestriccionesState();
}

class _PantallaCompartirRestriccionesState
    extends State<PantallaCompartirRestricciones> {
  late final _qr = widget.servicio.generarQrPersonal();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Compartir mis restricciones')),
    body: FutureBuilder<String>(
      future: _qr,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return CuerpoFormulario(
            child: MensajeError(
              error is ErrorRestriccionesCompartidas
                  ? error.mensaje
                  : 'No se pudo generar el QR. Volvé a intentarlo.',
            ),
          );
        }
        final texto = snapshot.data;
        if (texto == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final datos = widget.servicio.leerQr(texto);
        return CuerpoFormulario(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mostrá este QR para que otra persona lo escanee desde SafeLabel.',
              ),
              const SizedBox(height: 16),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: QrImageView(
                    data: texto,
                    padding: const EdgeInsets.all(24),
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                    semanticsLabel: 'QR con mis restricciones alimentarias',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Incluye tu nombre y apellido, estas restricciones y sus '
                'severidades. No incluye credenciales, IDs de cuenta ni otros '
                'perfiles. Es una copia estática: no se actualiza automáticamente.',
              ),
              ListaRestriccionesCompartidas(
                restricciones: datos.restricciones,
                base: widget.base,
              ),
            ],
          ),
        );
      },
    ),
  );
}
