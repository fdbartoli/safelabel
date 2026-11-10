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
  RestriccionesCompartidas? _recibido;
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
      await widget.servicio.guardarCopia(widget.textoQr);
      guardado = true;
      if (mounted) Navigator.of(context).pop(true);
    } on ErrorValidacionPerfil catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } on ErrorRestriccionesCompartidas catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar la copia. Reintentá.');
      }
    } finally {
      // No reactivar el botón durante la animación de salida: una segunda
      // pulsación no debe crear otra copia.
      if (mounted && !guardado) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: Scaffold(
      appBar: AppBar(title: const Text('Restricciones recibidas')),
      body: CuerpoFormulario(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_recibido case final recibido?) ...[
              const Text(
                'Revisá las restricciones antes de guardar una copia. '
                'Tu perfil personal no se modifica.',
              ),
              const SizedBox(height: 16),
              Text(
                recibido.nombreCompleto,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text('Nombre y apellido del propietario del perfil.'),
              if (recibido.esVersionAnterior) ...[
                const SizedBox(height: 8),
                Text(
                  'Este QR es de una versión anterior y no incluye el nombre. '
                  'Se guardará como "${CodecRestriccionesCompartidas.nombreAnterior}".',
                ),
              ],
              const SizedBox(height: 12),
              ListaRestriccionesCompartidas(
                restricciones: recibido.restricciones,
                base: widget.base,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: Text(_guardando ? 'Guardando…' : 'Guardar perfil'),
              ),
              const SizedBox(height: 8),
              const Text(
                'La copia se guardará inactiva. Podés editarla y activarla '
                'desde Perfiles.',
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
