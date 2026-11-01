import 'package:flutter/material.dart';

import 'cuenta/servicio_cuenta.dart';
import 'datos/almacen_local.dart';
import 'datos/base_conocimiento.dart';
import 'datos/repositorio_usuarios.dart';
import 'ui/pantalla_inicio.dart';
import 'ui/puerta_de_sesion.dart';
import 'ui/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cuentas de usuario guardadas en el almacenamiento local (HU01 a HU05).
  final almacen = await AlmacenLocal.abrir();
  final servicioCuenta = ServicioCuenta(RepositorioUsuarios(almacen));
  runApp(SafeLabelApp(servicioCuenta: servicioCuenta));
}

class SafeLabelApp extends StatelessWidget {
  const SafeLabelApp({super.key, required this.servicioCuenta});

  final ServicioCuenta servicioCuenta;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeLabel',
      debugShowCheckedModeBanner: false,
      // Verde pastel para el chrome general. La pantalla de resultado usa su
      // propio tema neutro — ver lib/ui/tema.dart (regla 1.4).
      theme: temaApp,
      // Sin sesión se muestra el ingreso; con sesión, la app de siempre.
      home: PuertaDeSesion(
        servicio: servicioCuenta,
        construirPrincipal: (context) =>
            _CargaDeBase(servicioCuenta: servicioCuenta),
      ),
    );
  }
}

/// Carga la base de conocimiento local y abre la pantalla de inicio.
class _CargaDeBase extends StatefulWidget {
  const _CargaDeBase({required this.servicioCuenta});

  final ServicioCuenta servicioCuenta;

  @override
  State<_CargaDeBase> createState() => _CargaDeBaseState();
}

class _CargaDeBaseState extends State<_CargaDeBase> {
  late final Future<BaseConocimiento> _base =
      BaseConocimiento.cargarDesdeAssets();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BaseConocimiento>(
      future: _base,
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
        return PantallaInicio(
          base: snapshot.data!,
          servicioCuenta: widget.servicioCuenta,
        );
      },
    );
  }
}
