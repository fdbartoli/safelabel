import 'package:flutter/material.dart';

import 'datos/base_conocimiento.dart';
import 'datos/bd_local.dart';
import 'datos/fabrica_bd.dart';
import 'datos/perfiles_iniciales.dart';
import 'datos/repositorio_perfiles.dart';
import 'ui/pantalla_inicio.dart';
import 'ui/tema.dart';

void main() {
  runApp(const SafeLabelApp());
}

/// Lo que la app necesita cargado antes de mostrar la pantalla de inicio.
class _Arranque {
  const _Arranque(this.base, this.repositorio);
  final BaseConocimiento base;
  final RepositorioPerfiles repositorio;
}

Future<_Arranque> _arrancar() async {
  final base = await BaseConocimiento.cargarDesdeAssets();
  var recienCreada = false;
  final bd = await BdLocal.abrir(
    fabrica: fabricaBdPlataforma(),
    alCrear: () => recienCreada = true,
  );
  final repositorio = RepositorioPerfilesSqlite(
    bd,
    gruposValidos: base.grupos.keys.toSet(),
  );
  if (recienCreada) await sembrarPerfilesIniciales(repositorio);
  return _Arranque(base, repositorio);
}

class SafeLabelApp extends StatefulWidget {
  const SafeLabelApp({super.key});

  @override
  State<SafeLabelApp> createState() => _SafeLabelAppState();
}

class _SafeLabelAppState extends State<SafeLabelApp> {
  // En el State y no en build(): cada reconstrucción volvería a cargar la base
  // y a abrir SQLite.
  late final Future<_Arranque> _arranque = _arrancar();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeLabel',
      debugShowCheckedModeBanner: false,
      // Verde pastel para el chrome general. La pantalla de resultado usa su
      // propio tema neutro — ver lib/ui/tema.dart (regla 1.4).
      theme: temaApp,
      home: FutureBuilder<_Arranque>(
        future: _arranque,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No se pudo cargar la base local.\n\n${snapshot.error}',
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final arranque = snapshot.data!;
          return PantallaInicio(
            base: arranque.base,
            repositorio: arranque.repositorio,
          );
        },
      ),
    );
  }
}
