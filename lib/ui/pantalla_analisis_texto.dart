import 'package:flutter/material.dart';

import '../datos/base_conocimiento.dart';
import '../modelo/perfil.dart';
import '../ocr/servicio_ocr.dart';
import '../pipeline/analizador.dart';
import 'pantalla_resultado.dart';

/// Camino sin cámara: se pega el texto de la etiqueta (por ejemplo el texto
/// esperado de una fixture) y se corre el mismo pipeline que tras un escaneo.
/// Sirve para validar normalización y matching de la Etapa 1.
class PantallaAnalisisTexto extends StatefulWidget {
  const PantallaAnalisisTexto({
    super.key,
    required this.base,
    required this.perfilesActivos,
  });

  final BaseConocimiento base;
  final List<Perfil> perfilesActivos;

  @override
  State<PantallaAnalisisTexto> createState() => _PantallaAnalisisTextoState();
}

class _PantallaAnalisisTextoState extends State<PantallaAnalisisTexto> {
  final _controller = TextEditingController(text: _ejemplo);

  static const _ejemplo =
      'Ingredientes: harina de trigo enriquecida, azúcar, aceite vegetal, '
      'cacao, jarabe de glucosa, lecitina de soja, sal, aroma vainilla, '
      'bicarbonato de sodio.\n'
      'CONTIENE: trigo y soja. PUEDE CONTENER leche y frutas secas.';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _analizar() {
    final ocr = ServicioOcrFalso.desdeTexto(_controller.text);
    ocr.reconocer('').then((lectura) {
      final resultado = Analizador(widget.base).analizar(
        lectura,
        perfilesActivos: widget.perfilesActivos,
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PantallaResultado(resultado: resultado),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analizar texto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pegá la lista de ingredientes y la línea "CONTIENE" tal como '
              'figuran en el envase.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ingredientes: ...',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _analizar,
              child: const Text('Analizar'),
            ),
          ],
        ),
      ),
    );
  }
}
