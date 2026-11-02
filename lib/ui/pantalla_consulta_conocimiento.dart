import 'package:flutter/material.dart';

import '../datos/repositorio_conocimiento.dart';
import '../modelo/consulta_conocimiento.dart';

class PantallaConsultaConocimiento extends StatefulWidget {
  const PantallaConsultaConocimiento({
    super.key,
    required this.repositorio,
  });

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
                  return Text('No se pudo realizar la consulta.\n${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final resultado = snapshot.data!;
                if (!resultado.encontrado) {
                  return Text(
                    'No encontramos "${resultado.entrada}" en la base de conocimiento.',
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

class _TarjetaCoincidencia extends StatelessWidget {
  const _TarjetaCoincidencia({required this.coincidencia});

  final CoincidenciaConocimiento coincidencia;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              coincidencia.concepto,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Denominación: ${coincidencia.denominacion} (${coincidencia.idioma})'),
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
                Text(evidencia.url, style: Theme.of(context).textTheme.bodySmall),
              ],
          ],
        ),
      ),
    );
  }
}
