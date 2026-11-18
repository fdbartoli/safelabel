import 'package:flutter/material.dart';

import '../compartir/restricciones_compartidas.dart';
import '../compartir/servicio_compartir_restricciones.dart';
import '../datos/base_conocimiento.dart';
import '../datos/repositorio_perfiles.dart';
import 'componentes_cuenta.dart';
import 'lista_restricciones_compartidas.dart';

class PantallaImportarRestricciones extends StatefulWidget {
  const PantallaImportarRestricciones({
    super.key,
    required this.textoQr,
    required this.servicio,
    required this.base,
  });

  final String textoQr;
  final ServicioCompartirRestricciones servicio;
  final BaseConocimiento base;

  @override
  State<PantallaImportarRestricciones> createState() =>
      _PantallaImportarRestriccionesState();
}

class _PantallaImportarRestriccionesState
    extends State<PantallaImportarRestricciones> {
  PerfilesCompartidos? _recibido;
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  void _preparar() {
    try {
      _recibido = widget.servicio.leerQr(widget.textoQr);
    } on ErrorRestriccionesCompartidas catch (e) {
      _error = e.mensaje;
    } catch (_) {
      _error = 'No se pudo preparar la vista previa. Volvé a escanear el QR.';
    }
  }

  Future<void> _guardar() async {
    if (_guardando || _recibido == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    var guardado = false;
    try {
      await widget.servicio.guardarCopias(widget.textoQr);
      guardado = true;
      if (mounted) Navigator.of(context).pop(true);
    } on ErrorValidacionPerfil catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } on ErrorRestriccionesCompartidas catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudieron guardar los perfiles. Reintentá.',
        );
      }
    } finally {
      // No reactivar el botón durante la animación de salida: una segunda
      // pulsación no debe crear copias duplicadas.
      if (mounted && !guardado) setState(() => _guardando = false);
    }
  }

  String get _textoGuardar {
    final cantidad = _recibido?.perfiles.length ?? 0;
    if (_guardando) return 'Guardando…';
    return cantidad == 1 ? 'Guardar perfil' : 'Guardar $cantidad perfiles';
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: Scaffold(
      appBar: AppBar(title: const Text('Perfiles recibidos')),
      body: CuerpoFormulario(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_recibido case final recibido?) ...[
              const Text(
                'Revisá los perfiles y sus restricciones antes de guardarlos. '
                'Se guardarán inactivos y no se modificará ningún perfil '
                'existente.',
              ),
              const SizedBox(height: 16),
              if (recibido.nombreCompleto.isNotEmpty) ...[
                Text(
                  recibido.nombreCompleto,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text('Nombre y apellido del propietario.'),
                const SizedBox(height: 12),
              ],
              if (recibido.version ==
                  CodecRestriccionesCompartidas.versionAnterior) ...[
                const SizedBox(height: 8),
                Text(
                  'Este QR es de una versión anterior y no incluye el nombre '
                  'del propietario. El perfil se guardará como '
                  '"${CodecRestriccionesCompartidas.nombreAnterior}".',
                ),
                const SizedBox(height: 12),
              ] else if (recibido.esVersionAnterior) ...[
                const SizedBox(height: 8),
                const Text(
                  'Este QR es de una versión anterior. Se guardará un único '
                  'perfil con el nombre del propietario.',
                ),
                const SizedBox(height: 12),
              ],
              for (final perfil in recibido.perfiles) ...[
                Text(
                  perfil.nombre,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ListaRestriccionesCompartidas(
                  restricciones: perfil.restricciones,
                  base: widget.base,
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: Text(_textoGuardar),
              ),
              const SizedBox(height: 8),
              const Text(
                'Los perfiles se guardarán inactivos. Podés editarlos y '
                'activarlos desde Perfiles.',
              ),
            ],
            if (_error != null) MensajeError(_error!),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _guardando
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    ),
  );
}
