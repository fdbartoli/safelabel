import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;

import 'cuenta/servicio_cuenta.dart';
import 'conocimiento/catalogo_conocimiento.dart';
import 'datos/almacen_local.dart';
import 'datos/base_conocimiento.dart';
import 'datos/bd_conocimiento.dart';
import 'datos/bd_local.dart';
import 'datos/fabrica_bd.dart';
import 'datos/perfiles_iniciales.dart';
import 'datos/repositorio_conocimiento.dart';
import 'datos/repositorio_perfiles.dart';
import 'datos/repositorio_usuarios.dart';
import 'ui/controlador_tema.dart';
import 'ui/pantalla_inicio.dart';
import 'ui/puerta_de_sesion.dart';
import 'ui/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cuentas de usuario guardadas en el almacenamiento local (HU01 a HU05).
  final almacen = await AlmacenLocal.abrir();
  final servicioCuenta = ServicioCuenta(RepositorioUsuarios(almacen));
  // Modo claro u oscuro elegido por la persona (o el del teléfono).
  final controladorTema = ControladorTema(almacen);
  runApp(
    SafeLabelApp(
      servicioCuenta: servicioCuenta,
      controladorTema: controladorTema,
    ),
  );
}

/// Lo que la app necesita cargado antes de mostrar la pantalla de inicio.
class _Arranque {
  const _Arranque(
    this.base,
    this.repositorio,
    this.conocimiento,
    this.catalogo,
  );
  final BaseConocimiento base;
  final RepositorioPerfiles repositorio;
  final RepositorioConocimiento conocimiento;
  final CatalogoConocimiento catalogo;
}

Future<_Arranque> _arrancar() async {
  final base = await BaseConocimiento.cargarDesdeAssets();
  // En Android, iOS y macOS no hay fábrica alternativa (null): ahí se usa la
  // de sqflite, que va por el plugin nativo.
  final fabrica = fabricaBdPlataforma() ?? databaseFactory;
  var recienCreada = false;
  final bd = await BdLocal.abrir(
    fabrica: fabrica,
    alCrear: () => recienCreada = true,
  );
  final repositorio = RepositorioPerfilesSqlite(
    bd,
    gruposValidos: base.grupos.keys.toSet(),
  );
  if (recienCreada) await sembrarPerfilesIniciales(repositorio);
  final bdConocimiento = await BdConocimiento.abrir(fabrica);
  final conocimiento = RepositorioConocimiento(bdConocimiento);
  final catalogo = await conocimiento.cargarCatalogo();
  return _Arranque(base, repositorio, conocimiento, catalogo);
}

class SafeLabelApp extends StatelessWidget {
  const SafeLabelApp({
    super.key,
    required this.servicioCuenta,
    this.controladorTema,
  });

  final ServicioCuenta servicioCuenta;

  /// `null` = sigue el modo del teléfono, sin botón para cambiarlo.
  final ControladorTema? controladorTema;

  @override
  Widget build(BuildContext context) {
    final controlador = controladorTema;
    Widget app(ThemeMode modo) => MaterialApp(
      title: 'SafeLabel',
      debugShowCheckedModeBanner: false,
      // Verde pastel para el chrome general, claro u oscuro. La pantalla de
      // resultado usa su propio tema neutro — ver lib/ui/tema.dart.
      theme: temaApp,
      darkTheme: temaAppOscuro,
      themeMode: modo,
      // Sin sesión se muestra el ingreso; con sesión, la app de siempre.
      home: PuertaDeSesion(
        servicio: servicioCuenta,
        construirPrincipal: (context) => _CargaDeBase(
          servicioCuenta: servicioCuenta,
          controladorTema: controlador,
        ),
      ),
    );
    if (controlador == null) return app(ThemeMode.system);
    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) => app(controlador.modo),
    );
  }
}

/// Carga la base de conocimiento y los perfiles, y abre la pantalla de inicio.
class _CargaDeBase extends StatefulWidget {
  const _CargaDeBase({required this.servicioCuenta, this.controladorTema});

  final ServicioCuenta servicioCuenta;
  final ControladorTema? controladorTema;

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
          conocimiento: arranque.conocimiento,
          catalogo: arranque.catalogo,
          servicioCuenta: widget.servicioCuenta,
          controladorTema: widget.controladorTema,
        );
      },
    );
  }
}
