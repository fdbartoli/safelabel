import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/cuenta/servicio_cuenta.dart';
import 'package:safelabel/datos/almacen_local.dart';
import 'package:safelabel/datos/repositorio_usuarios.dart';
import 'package:safelabel/ui/pantalla_mi_cuenta.dart';
import 'package:safelabel/ui/puerta_de_sesion.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ServicioCuenta> crearServicio() async {
  SharedPreferences.setMockInitialValues({});
  final almacen = await AlmacenLocal.abrir();
  return ServicioCuenta(RepositorioUsuarios(almacen));
}

/// La app de prueba usa una pantalla principal mínima en lugar de la real,
/// para no depender de la base de conocimiento ni del OCR.
Widget appDePrueba(ServicioCuenta servicio) {
  return MaterialApp(
    home: PuertaDeSesion(
      servicio: servicio,
      construirPrincipal: (context) => Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: 'Mi cuenta',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PantallaMiCuenta(servicio: servicio),
                ),
              ),
            ),
          ],
        ),
        body: const Text('Pantalla principal'),
      ),
    ),
  );
}

Future<void> tocar(WidgetTester tester, Finder boton) async {
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

Future<void> escribir(WidgetTester tester, String clave, String texto) async {
  final campo = find.byKey(Key(clave));
  await tester.ensureVisible(campo);
  await tester.enterText(campo, texto);
}

/// Pantalla alta, para que el formulario de registro entre completo.
void usarPantallaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> registrarCuentaDePrueba(ServicioCuenta servicio) {
  return servicio.registrar(
    nombre: 'Ana',
    apellido: 'Pérez',
    email: 'ana@mail.com',
    fechaNacimiento: DateTime(1995, 3, 15),
    contrasena: 'secreta123',
    aceptaTerminos: true,
  );
}

/// Completa el formulario de registro, salvo la casilla de términos.
Future<void> completarRegistro(WidgetTester tester) async {
  await tocar(tester, find.text('¿No tenés cuenta? Registrate'));
  await escribir(tester, 'registro_nombre', 'Ana');
  await escribir(tester, 'registro_apellido', 'Pérez');
  await escribir(tester, 'registro_email', 'ana@mail.com');
  await escribir(tester, 'registro_fecha_nacimiento', '15/03/1995');
  await escribir(tester, 'registro_contrasena', 'secreta123');
  await escribir(tester, 'registro_confirmacion', 'secreta123');
}

void main() {
  testWidgets('sin sesión se abre el ingreso', (tester) async {
    final servicio = await crearServicio();
    await tester.pumpWidget(appDePrueba(servicio));

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Pantalla principal'), findsNothing);
  });

  testWidgets('HU02: valida campos vacíos al ingresar', (tester) async {
    final servicio = await crearServicio();
    await tester.pumpWidget(appDePrueba(servicio));

    await tocar(tester, find.text('Ingresar'));

    expect(find.text('Ingresá tu email.'), findsOneWidget);
    expect(find.text('Ingresá tu contraseña.'), findsOneWidget);
  });

  testWidgets('HU02: con credenciales incorrectas muestra el error', (
    tester,
  ) async {
    final servicio = await crearServicio();
    await registrarCuentaDePrueba(servicio);
    await servicio.cerrarSesion();
    await tester.pumpWidget(appDePrueba(servicio));

    await tester.enterText(
      find.byKey(const Key('login_email')),
      'ana@mail.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_contrasena')),
      'incorrecta',
    );
    await tocar(tester, find.text('Ingresar'));

    expect(
      find.text(ServicioCuenta.mensajeCredencialesInvalidas),
      findsOneWidget,
    );
  });

  testWidgets('HU01: sin aceptar los términos no se crea la cuenta', (
    tester,
  ) async {
    usarPantallaGrande(tester);
    final servicio = await crearServicio();
    await tester.pumpWidget(appDePrueba(servicio));

    await completarRegistro(tester);
    await tocar(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));

    expect(
      find.text(ServicioCuenta.mensajeTerminosNoAceptados),
      findsOneWidget,
    );
    expect(servicio.haySesionActiva, isFalse);
  });

  testWidgets('HU01: se pueden leer los términos desde el registro', (
    tester,
  ) async {
    usarPantallaGrande(tester);
    final servicio = await crearServicio();
    await tester.pumpWidget(appDePrueba(servicio));

    await tocar(tester, find.text('¿No tenés cuenta? Registrate'));
    await tocar(tester, find.text('Leer los términos y condiciones'));

    expect(find.text('Términos y Condiciones de Uso'), findsOneWidget);
    expect(find.text('1. Objeto y aceptación'), findsOneWidget);
  });

  testWidgets('HU01: registrarse lleva a la pantalla principal', (
    tester,
  ) async {
    usarPantallaGrande(tester);
    final servicio = await crearServicio();
    await tester.pumpWidget(appDePrueba(servicio));

    await completarRegistro(tester);
    await tocar(tester, find.byKey(const Key('casilla_terminos')));
    await tocar(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));

    expect(find.text('Pantalla principal'), findsOneWidget);
    final cuenta = servicio.cuentaActual()!;
    expect(cuenta.nombreCompleto, 'Ana Pérez');
    expect(cuenta.fechaNacimiento, DateTime(1995, 3, 15));
  });

  testWidgets('HU03 y HU05: ver la cuenta y cerrar sesión', (tester) async {
    usarPantallaGrande(tester);
    final servicio = await crearServicio();
    await registrarCuentaDePrueba(servicio);
    await tester.pumpWidget(appDePrueba(servicio));

    await tocar(tester, find.byTooltip('Mi cuenta'));
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('ana@mail.com'), findsOneWidget);
    expect(find.text('15/03/1995'), findsOneWidget);

    await tocar(tester, find.text('Cerrar sesión'));
    await tocar(tester, find.widgetWithText(FilledButton, 'Cerrar sesión'));

    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Pantalla principal'), findsNothing);
    expect(servicio.haySesionActiva, isFalse);
  });
}
