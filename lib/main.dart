import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show Database, databaseFactory;

import 'cuenta/servicio_cuenta.dart';
import 'conocimiento/catalogo_conocimiento.dart';
import 'datos/almacen_local.dart';
import 'datos/base_conocimiento.dart';
import 'datos/bd_conocimiento.dart';
import 'datos/bd_local.dart';
import 'datos/fabrica_bd.dart';
import 'datos/preparador_perfiles.dart';
import 'datos/repositorio_conocimiento.dart';
import 'datos/repositorio_perfiles.dart';
import 'datos/repositorio_usuarios.dart';
import 'ui/pantalla_inicio.dart';
import 'ui/puerta_de_sesion.dart';
import 'ui/tema.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeLabelApp());
}

class _Servicios {
  const _Servicios(
    this.cuenta,
    this.base,
    this.bd,
    this.bdConocimiento,
    this.conocimiento,
    this.catalogo,
  );

  final ServicioCuenta cuenta;
  final BaseConocimiento base;
  final Database bd;
  final Database bdConocimiento;
  final RepositorioConocimiento conocimiento;
  final CatalogoConocimiento catalogo;
}

Future<_Servicios> _arrancar() async {
  final almacen = await AlmacenLocal.abrir();
  final base = await BaseConocimiento.cargarDesdeAssets();
  final fabrica = fabricaBdPlataforma() ?? databaseFactory;
  final bd = await BdLocal.abrir(fabrica: fabrica);
  Database? bdConocimiento;
  ServicioCuenta? cuenta;
  try {
    cuenta = ServicioCuenta(
      RepositorioUsuarios(almacen),
      preparador: PreparadorPerfilesSqlite(bd),
    );
    // Prepara todas las cuentas antiguas, incluso sin sesión. No se siembran
    // perfiles globales de demostración en instalaciones nuevas.
    await cuenta.restaurarSesion();
    bdConocimiento = await BdConocimiento.abrir(fabrica);
    final conocimiento = RepositorioConocimiento(bdConocimiento);
    final catalogo = await conocimiento.cargarCatalogo();
    return _Servicios(cuenta, base, bd, bdConocimiento, conocimiento, catalogo);
  } catch (_) {
    cuenta?.dispose();
    await bdConocimiento?.close();
    await bd.close();
    rethrow;
  }
}

class SafeLabelApp extends StatefulWidget {
  const SafeLabelApp({super.key});

  @override
  State<SafeLabelApp> createState() => _SafeLabelAppState();
}

class _SafeLabelAppState extends State<SafeLabelApp> {
  late Future<_Servicios> _servicios = _arrancar();

  @override
  void dispose() {
    _servicios.then((s) async {
      s.cuenta.dispose();
      await s.bdConocimiento.close();
      await s.bd.close();
    }, onError: (Object _, StackTrace _) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SafeLabel',
    debugShowCheckedModeBanner: false,
    theme: temaApp,
    home: FutureBuilder<_Servicios>(
      future: _servicios,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No se pudo preparar la aplicación. Los datos '
                      'guardados se conservan.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() {
                        _servicios = _arrancar();
                      }),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final s = snapshot.data;
        if (s == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return PuertaDeSesion(
          servicio: s.cuenta,
          construirPrincipal: (_) => PantallaInicio(
            base: s.base,
            repositorio: RepositorioPerfilesSqlite(
              s.bd,
              gruposValidos: s.base.grupos.keys.toSet(),
              usuarioId: s.cuenta.cuentaActual()!.id,
            ),
            conocimiento: s.conocimiento,
            catalogo: s.catalogo,
            servicioCuenta: s.cuenta,
          ),
        );
      },
    ),
  );
}
