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
      builder: (context, _) => servicio.haySesionActiva
          ? construirPrincipal(context)
          : PantallaInicioSesion(servicio: servicio),
    );
  }
}
