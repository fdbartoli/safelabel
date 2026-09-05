import 'package:flutter/material.dart';

import 'datos/base_conocimiento.dart';
import 'ui/pantalla_inicio.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          // Azul neutro, a propósito: nada de verde de "aprobación" (regla 1.4).
          seedColor: const Color(0xFF1B4965),
          brightness: Brightness.light,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
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
