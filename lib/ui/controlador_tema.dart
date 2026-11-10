import 'package:flutter/material.dart';

import '../datos/almacen_local.dart';

/// Modo claro u oscuro de la app, elegido con el botón de la barra superior.
///
/// Mientras la persona no elija, sigue el modo del teléfono. La elección se
/// guarda en el almacenamiento local y se recuerda al volver a abrir la app.
class ControladorTema extends ChangeNotifier {
  ControladorTema(this._almacen) : _modo = _leer(_almacen);

  static const clave = 'modo_tema';

  final AlmacenLocal? _almacen;
  ThemeMode _modo;

  ThemeMode get modo => _modo;

  static ThemeMode _leer(AlmacenLocal? almacen) =>
      switch (almacen?.leerTexto(clave)) {
        'claro' => ThemeMode.light,
        'oscuro' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// Pasa al modo opuesto al que se ve ahora ([brilloActual]), que con
  /// [ThemeMode.system] depende del teléfono.
  Future<void> alternar(Brightness brilloActual) async {
    _modo = brilloActual == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    await _almacen?.guardarTexto(
      clave,
      _modo == ThemeMode.dark ? 'oscuro' : 'claro',
    );
  }
}

/// Botón sol / luna para la barra superior.
class BotonModoTema extends StatelessWidget {
  const BotonModoTema({super.key, required this.controlador});

  final ControladorTema controlador;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      key: const Key('boton_modo_tema'),
      tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
      icon: Icon(oscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => controlador.alternar(Theme.of(context).brightness),
    );
  }
}
