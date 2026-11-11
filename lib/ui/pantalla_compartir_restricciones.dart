import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../compartir/restricciones_compartidas.dart';
import '../compartir/servicio_compartir_restricciones.dart';
import '../datos/base_conocimiento.dart';
import '../modelo/perfil.dart';
import 'componentes_cuenta.dart';
import 'lista_restricciones_compartidas.dart';

class PantallaCompartirRestricciones extends StatefulWidget {
  const PantallaCompartirRestricciones({
    super.key,
    required this.servicio,
    required this.base,
    required this.perfiles,
  });

  final ServicioCompartirRestricciones servicio;
  final BaseConocimiento base;
  final List<Perfil> perfiles;

  @override
  State<PantallaCompartirRestricciones> createState() =>
      _PantallaCompartirRestriccionesState();
}

class _PantallaCompartirRestriccionesState
    extends State<PantallaCompartirRestricciones> {
  late final _qr = widget.servicio.generarQr(widget.perfiles);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Compartir perfiles')),
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
                    semanticsLabel: 'QR con perfiles alimentarios',
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => _VistaQrAmpliado(texto: texto),
                  ),
                ),
                icon: const Icon(Icons.fullscreen),
                label: const Text('Ampliar QR'),
              ),
              const SizedBox(height: 16),
              Text(
                'Incluye ${datos.perfiles.length} '
                '${datos.perfiles.length == 1 ? 'perfil' : 'perfiles'}, '
                'con sus restricciones y severidades. No incluye credenciales '
                'ni IDs de cuenta. Es una copia estática: no se actualiza '
                'automáticamente.',
              ),
              const SizedBox(height: 12),
              if (datos.nombreCompleto.isNotEmpty) ...[
                Text(
                  datos.nombreCompleto,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text('Nombre y apellido del propietario.'),
                const SizedBox(height: 12),
              ],
              for (final perfil in datos.perfiles) ...[
                Text(
                  perfil.nombre,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ListaRestriccionesCompartidas(
                  restricciones: perfil.restricciones,
                  base: widget.base,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _VistaQrAmpliado extends StatelessWidget {
  _VistaQrAmpliado({required String texto})
    : _qr = QrCode.fromData(
        data: texto,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );

  final QrCode _qr;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('QR ampliado'),
      leading: IconButton(
        tooltip: 'Cerrar QR ampliado',
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ladoDisponible = constraints.biggest.shortestSide;
          // El pintor redondea los módulos a medios píxeles lógicos. Ajustar
          // el tamaño a ese paso conserva cuatro módulos blancos por lado.
          final modulo =
              (ladoDisponible / (_qr.moduleCount + 8) * 2).floorToDouble() / 2;
          return Center(
            child: QrImageView.withQr(
              qr: _qr,
              size: modulo * (_qr.moduleCount + 8),
              padding: EdgeInsets.all(modulo * 4),
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
              semanticsLabel: 'QR ampliado con perfiles alimentarios',
            ),
          );
        },
      ),
    ),
  );
}
