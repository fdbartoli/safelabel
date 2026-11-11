import 'package:flutter/material.dart';

import '../cuenta/servicio_cuenta.dart';
import 'pantalla_inicio_sesion.dart';

/// Primera pantalla de la app (HU01 a HU05).
///
/// Sin sesión muestra el ingreso; con sesión, la pantalla que arme
/// [construirPrincipal]. Se actualiza sola cuando [servicio] avisa un cambio,
/// así que al cerrar sesión no queda forma de volver atrás a la app.
class PuertaDeSesion extends StatelessWidget {
  const PuertaDeSesion({
    super.key,
    required this.servicio,
    required this.construirPrincipal,
  });

  final ServicioCuenta servicio;
  final WidgetBuilder construirPrincipal;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: servicio,
      builder: (context, _) {
        final cuenta = servicio.cuentaActual();
        // Al cambiar la identidad se descarta toda la pila anterior (editores,
        // resultados y formularios incluidos), no solo la pantalla principal.
        return _NavegacionSesion(
          key: ValueKey(cuenta?.id ?? 'sin-sesion'),
          construirInicial: (context) => cuenta != null
              ? construirPrincipal(context)
              : PantallaInicioSesion(servicio: servicio),
        );
      },
    );
  }
}

class _NavegacionSesion extends StatefulWidget {
  const _NavegacionSesion({super.key, required this.construirInicial});

  final WidgetBuilder construirInicial;

  @override
  State<_NavegacionSesion> createState() => _NavegacionSesionState();
}

class _NavegacionSesionState extends State<_NavegacionSesion> {
  final _navegador = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => NavigatorPopHandler<void>(
    onPopWithResult: (_) => _navegador.currentState!.pop(),
    child: Navigator(
      key: _navegador,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (context) => widget.construirInicial(context),
      ),
    ),
  );
}
