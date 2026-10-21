import 'package:flutter/material.dart';

import 'datos/base_conocimiento.dart';
import 'ui/pantalla_inicio.dart';
import 'ui/tema.dart';

void main() {
  runApp(const SafeLabelApp());
}

class SafeLabelApp extends StatelessWidget {
  const SafeLabelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeLabel',
      debugShowCheckedModeBanner: false,
      // Verde pastel para el chrome general. La pantalla de resultado usa su
      // propio tema neutro — ver lib/ui/tema.dart (regla 1.4).
      theme: temaApp,
      home: FutureBuilder<BaseConocimiento>(
        future: BaseConocimiento.cargarDesdeAssets(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No se pudo cargar la base local.\n\n${snapshot.error}'),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return PantallaInicio(base: snapshot.data!);
        },
      ),
    );
  }
}
