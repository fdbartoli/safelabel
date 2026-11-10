import 'package:flutter/material.dart';

import '../datos/repositorio_conocimiento.dart';
import '../modelo/consulta_conocimiento.dart';

class PantallaConsultaConocimiento extends StatefulWidget {
  const PantallaConsultaConocimiento({super.key, required this.repositorio});

  final RepositorioConocimiento repositorio;

  @override
  State<PantallaConsultaConocimiento> createState() =>
      _PantallaConsultaConocimientoState();
}

class _PantallaConsultaConocimientoState
    extends State<PantallaConsultaConocimiento> {
  final _controlador = TextEditingController();
  Future<ResultadoConsultaConocimiento>? _consulta;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _buscar() {
    FocusScope.of(context).unfocus();
    setState(() {
      _consulta = widget.repositorio.buscar(_controlador.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultar ingrediente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controlador,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _buscar(),
            decoration: const InputDecoration(
              labelText: 'Ingrediente',
              hintText: 'Ej.: caseinato de sodio',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _buscar,
            icon: const Icon(Icons.search),
            label: const Text('Buscar en la base local'),
          ),
          const SizedBox(height: 20),
          if (_consulta case final consulta?)
            FutureBuilder<ResultadoConsultaConocimiento>(
              future: consulta,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'No se pudo realizar la consulta.\n${snapshot.error}',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final resultado = snapshot.data!;
                if (!resultado.encontrado) {
                  return _SinCoincidencia(
                    resultado: resultado,
                    alElegirSugerencia: (sugerencia) {
                      _controlador.text = sugerencia;
                      _buscar();
                    },
                  );
                }
                return Column(
                  children: [
                    for (final coincidencia in resultado.coincidencias)
                      _TarjetaCoincidencia(coincidencia: coincidencia),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

/// "No encontrado" o "se parece a…". Nunca se presenta como seguro (regla 1.3).
class _SinCoincidencia extends StatelessWidget {
  const _SinCoincidencia({
    required this.resultado,
    required this.alElegirSugerencia,
  });

  final ResultadoConsultaConocimiento resultado;
  final ValueChanged<String> alElegirSugerencia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final sugerencia = resultado.sugerencia;
    final similitud = resultado.similitudSugerencia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No encontramos "${resultado.entrada}" en la base de conocimiento.',
          style: tema.textTheme.bodyLarge,
        ),
        if (sugerencia != null) ...[
          const SizedBox(height: 12),
          Text(
            'Se parece a "$sugerencia"'
            '${similitud == null ? '' : ' (${(similitud * 100).round()}%)'}. '
            'Puede ser un error de escritura.',
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => alElegirSugerencia(sugerencia),
            child: Text('Buscar "$sugerencia"'),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Que no esté en la base no significa que sea seguro: la base no '
          'tiene información sobre este término.',
          style: tema.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _TarjetaCoincidencia extends StatelessWidget {
  const _TarjetaCoincidencia({required this.coincidencia});

  final CoincidenciaConocimiento coincidencia;

  String? get _comoCoincidio {
    switch (coincidencia.coincidencia) {
      case TipoCoincidenciaConsulta.exacta:
        return null;
      case TipoCoincidenciaConsulta.contiene:
        return 'Lo escrito contiene "${coincidencia.denominacion}".';
      case TipoCoincidenciaConsulta.aproximada:
        return 'Coincidencia aproximada '
            '(${(coincidencia.similitud * 100).round()}%) con '
            '"${coincidencia.denominacion}". Verificá cómo está escrito.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final comoCoincidio = _comoCoincidio;
    final idioma = coincidencia.idioma;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              coincidencia.denominacion,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (comoCoincidio != null) ...[
              const SizedBox(height: 4),
              Text(
                comoCoincidio,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Concepto en la base: ${coincidencia.concepto}'
              '${idioma == null ? '' : ' ($idioma)'}',
            ),
            if (!coincidencia.tieneRestriccion) ...[
              const SizedBox(height: 8),
              const Text(
                'Ingrediente reconocido. La base actual no registra una '
                'relación con las restricciones incorporadas. Esto no '
                'significa que sea seguro para cualquier persona.',
              ),
            ] else ...[
              Text('Restricción: ${coincidencia.restriccionVisible}'),
              Text(
                coincidencia.tipoCoincidencia == 'DIRECT'
                    ? 'Relación: directa'
                    : 'Relación: ingrediente relacionado',
              ),
              const SizedBox(height: 12),
              Text('Fuentes', style: Theme.of(context).textTheme.titleSmall),
              if (coincidencia.evidencias.isEmpty)
                const Text('Sin evidencia disponible.')
              else
                for (final evidencia in coincidencia.evidencias) ...[
                  const SizedBox(height: 8),
                  Text(
                    evidencia.tituloFuente,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(evidencia.fragmento),
                  Text(
                    evidencia.url,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
            ],
          ],
        ),
      ),
    );
  }
}
