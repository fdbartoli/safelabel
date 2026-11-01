import 'package:flutter/material.dart';

import 'cuenta/servicio_cuenta.dart';
import 'datos/almacen_local.dart';
import 'datos/base_conocimiento.dart';
import 'datos/bd_local.dart';
import 'datos/fabrica_bd.dart';
import 'datos/perfiles_iniciales.dart';
import 'datos/repositorio_perfiles.dart';
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

/// Carga la base de conocimiento y los perfiles, y abre la pantalla de inicio.
class _CargaDeBase extends StatefulWidget {
  const _CargaDeBase({required this.servicioCuenta});

  final ServicioCuenta servicioCuenta;

  @override
  State<_CargaDeBase> createState() => _CargaDeBaseState();
}

class _CargaDeBaseState extends State<_CargaDeBase> {
  // En el State y no en build(): cada reconstrucción volvería a cargar la base
  // y a abrir SQLite.
  late final Future<_Arranque> _arranque = _arrancar();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Arranque>(
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
          servicioCuenta: widget.servicioCuenta,
        );
      },
    );
  }
}
