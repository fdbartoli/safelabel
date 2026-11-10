import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:safelabel/cuenta/reglas_usuario.dart';
import 'package:safelabel/cuenta/servicio_cuenta.dart';
import 'package:safelabel/cuenta/terminos_condiciones.dart';
import 'package:safelabel/datos/almacen_local.dart';
import 'package:safelabel/datos/preparador_perfiles.dart';
import 'package:safelabel/datos/repositorio_usuarios.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Crea un servicio con un almacenamiento local en memoria.
late PreparadorPerfilesMemoria preparadorPrueba;

Future<ServicioCuenta> crearServicio([
  Map<String, Object> valoresIniciales = const {},
]) async {
  SharedPreferences.setMockInitialValues(valoresIniciales);
  final almacen = await AlmacenLocal.abrir();
  preparadorPrueba = PreparadorPerfilesMemoria();
  final servicio = ServicioCuenta(
    RepositorioUsuarios(almacen),
    preparador: preparadorPrueba,
  );
  await servicio.restaurarSesion();
  return servicio;
}

/// Simula cerrar y volver a abrir la app sobre el mismo almacenamiento.
Future<ServicioCuenta> reabrirApp() async {
  final almacen = await AlmacenLocal.abrir();
  final servicio = ServicioCuenta(
    RepositorioUsuarios(almacen),
    preparador: preparadorPrueba,
  );
  await servicio.restaurarSesion();
  return servicio;
}

/// Registra una cuenta válida; cada prueba cambia solo lo que le interesa.
Future<CuentaUsuario> registrar(
  ServicioCuenta servicio, {
  String nombre = 'Ana',
  String apellido = 'Pérez',
  String email = 'ana@mail.com',
  DateTime? fechaNacimiento,
  String contrasena = 'secreta123',
  bool aceptaTerminos = true,
}) {
  return servicio.registrar(
    nombre: nombre,
    apellido: apellido,
    email: email,
    fechaNacimiento: fechaNacimiento ?? DateTime(1995, 3, 15),
    contrasena: contrasena,
    aceptaTerminos: aceptaTerminos,
  );
}

/// Ejecuta [accion] y devuelve el mensaje del ErrorCuenta, o null si no falló.
Future<String?> mensajeDeError(Future<void> Function() accion) async {
  try {
    await accion();
    return null;
  } on ErrorCuenta catch (error) {
    return error.mensaje;
  }
}

void main() {
  group('Reglas de fecha de nacimiento', () {
    test('interpreta dd/mm/aaaa y rechaza fechas que no existen', () {
      expect(ReglasUsuario.parsearFecha('15/03/1995'), DateTime(1995, 3, 15));
      expect(ReglasUsuario.parsearFecha('31/02/2000'), isNull);
      expect(ReglasUsuario.parsearFecha('1995-03-15'), isNull);
      expect(ReglasUsuario.parsearFecha('15/03/95'), isNull);
    });

    test('calcula la edad teniendo en cuenta si ya cumplió', () {
      final hoy = DateTime(2026, 11, 1);
      expect(ReglasUsuario.calcularEdad(DateTime(2000, 11, 1), hoy), 26);
      expect(ReglasUsuario.calcularEdad(DateTime(2000, 11, 2), hoy), 25);
    });

    test('rechaza fechas futuras y menores de la edad mínima', () {
      final hoy = DateTime(2026, 11, 1);
      expect(
        ReglasUsuario.validarFechaNacimiento(DateTime(2027, 1, 1), hoy: hoy),
        isNotNull,
      );
      expect(
        ReglasUsuario.validarFechaNacimiento(DateTime(2014, 1, 1), hoy: hoy),
        isNotNull,
      );
      expect(
        ReglasUsuario.validarFechaNacimiento(DateTime(2013, 11, 1), hoy: hoy),
        isNull,
      );
    });
  });

  group('HU01 Registrarse', () {
    test(
      'crea la cuenta con todos los datos y deja la sesión iniciada',
      () async {
        final servicio = await crearServicio();
        await registrar(
          servicio,
          nombre: ' Ana ',
          apellido: ' Pérez ',
          email: ' Ana@Mail.com ',
        );

        final cuenta = servicio.cuentaActual()!;
        expect(cuenta.nombreCompleto, 'Ana Pérez');
        expect(cuenta.email, 'ana@mail.com');
        expect(cuenta.fechaNacimiento, DateTime(1995, 3, 15));
      },
    );

    test('exige aceptar los términos y guarda la versión aceptada', () async {
      final servicio = await crearServicio();
      final error = await mensajeDeError(
        () => registrar(servicio, aceptaTerminos: false),
      );
      expect(error, ServicioCuenta.mensajeTerminosNoAceptados);
      expect(servicio.haySesionActiva, isFalse);

      await registrar(servicio);
      final cuenta = servicio.cuentaActual()!;
      expect(cuenta.versionTerminos, TerminosCondiciones.version);
      expect(cuenta.fechaAceptacionTerminos, isNotNull);
    });

    test('rechaza un email ya registrado', () async {
      final servicio = await crearServicio();
      await registrar(servicio);
      final error = await mensajeDeError(
        () => registrar(servicio, nombre: 'Otra', email: 'ANA@mail.com'),
      );
      expect(error, isNotNull);
    });

    test('rechaza datos inválidos', () async {
      final servicio = await crearServicio();
      final casos = <Future<void> Function()>[
        () => registrar(servicio, nombre: ''),
        () => registrar(servicio, apellido: ''),
        () => registrar(servicio, email: 'ana-sin-arroba'),
        () => registrar(servicio, fechaNacimiento: DateTime(2100)),
        () => registrar(servicio, contrasena: 'corta'),
      ];
      for (final caso in casos) {
        expect(await mensajeDeError(caso), isNotNull);
      }
      expect(servicio.haySesionActiva, isFalse);
    });

    test('no guarda la contraseña en texto plano', () async {
      final servicio = await crearServicio();
      await registrar(servicio);
      final preferencias = await SharedPreferences.getInstance();
      final guardado = preferencias.getString(
        RepositorioUsuarios.claveUsuarios,
      )!;
      expect(guardado.contains('secreta123'), isFalse);
    });
  });

  group('HU02 Iniciar sesión', () {
    test('ingresa con credenciales correctas', () async {
      final servicio = await crearServicio();
      await registrar(servicio);
      await servicio.cerrarSesion();

      await servicio.iniciarSesion(
        email: 'ANA@mail.com',
        contrasena: 'secreta123',
      );
      expect(servicio.haySesionActiva, isTrue);
    });

    test('el error es el mismo si falla el email o la contraseña', () async {
      final servicio = await crearServicio();
      await registrar(servicio);
      await servicio.cerrarSesion();

      final errorContrasena = await mensajeDeError(
        () => servicio.iniciarSesion(
          email: 'ana@mail.com',
          contrasena: 'incorrecta',
        ),
      );
      final errorEmail = await mensajeDeError(
        () => servicio.iniciarSesion(
          email: 'nadie@mail.com',
          contrasena: 'secreta123',
        ),
      );

      expect(errorContrasena, ServicioCuenta.mensajeCredencialesInvalidas);
      expect(errorEmail, ServicioCuenta.mensajeCredencialesInvalidas);
      expect(servicio.haySesionActiva, isFalse);
    });

    test('la sesión persiste al reabrir la app', () async {
      final servicio = await crearServicio();
      await registrar(servicio);

      final reabierto = await reabrirApp();
      expect(reabierto.haySesionActiva, isTrue);
      expect(reabierto.cuentaActual()!.email, 'ana@mail.com');
    });
  });

  group('HU03 Consultar cuenta', () {
    test('sin sesión no hay cuenta para mostrar', () async {
      final servicio = await crearServicio();
      expect(servicio.cuentaActual(), isNull);
    });

    test(
      'lee cuentas guardadas antes de que existieran los datos nuevos',
      () async {
        final cuentaVieja = {
          'id': '1',
          'nombre': 'Ana',
          'email': 'ana@mail.com',
          'hashContrasena': 'x',
          'salt': 'y',
          'fechaAlta': DateTime(2026, 10, 1).toIso8601String(),
        };
        final servicio = await crearServicio({
          RepositorioUsuarios.claveUsuarios: jsonEncode([cuentaVieja]),
          RepositorioUsuarios.claveSesion: '1',
        });

        final cuenta = servicio.cuentaActual()!;
        expect(cuenta.nombre, 'Ana');
        expect(cuenta.apellido, '');
        expect(cuenta.fechaNacimiento, isNull);
        expect(cuenta.versionTerminos, isNull);
      },
    );
  });

  group('HU04 Editar cuenta', () {
    test('los cambios de datos persisten', () async {
      final servicio = await crearServicio();
      await registrar(servicio);
      await servicio.editarDatos(
        nombre: 'Ana María',
        apellido: 'Gómez',
        email: 'am@mail.com',
        fechaNacimiento: DateTime(1990, 1, 20),
      );

      final cuenta = (await reabrirApp()).cuentaActual()!;
      expect(cuenta.nombreCompleto, 'Ana María Gómez');
      expect(cuenta.email, 'am@mail.com');
      expect(cuenta.fechaNacimiento, DateTime(1990, 1, 20));
    });

    test('no permite usar el email de otra cuenta', () async {
      final servicio = await crearServicio();
      await registrar(servicio);
      await registrar(servicio, nombre: 'Beto', email: 'beto@mail.com');

      final error = await mensajeDeError(
        () => servicio.editarDatos(
          nombre: 'Beto',
          apellido: 'Pérez',
          email: 'ana@mail.com',
          fechaNacimiento: DateTime(1990),
        ),
      );
      expect(error, isNotNull);
    });

    test('cambiar la contraseña exige la actual', () async {
      final servicio = await crearServicio();
      await registrar(servicio);

      final error = await mensajeDeError(
        () => servicio.cambiarContrasena(
          contrasenaActual: 'incorrecta',
          contrasenaNueva: 'nuevaclave1',
        ),
      );
      expect(error, isNotNull);

      await servicio.cambiarContrasena(
        contrasenaActual: 'secreta123',
        contrasenaNueva: 'nuevaclave1',
      );
      await servicio.cerrarSesion();

      expect(
        await mensajeDeError(
          () => servicio.iniciarSesion(
            email: 'ana@mail.com',
            contrasena: 'secreta123',
          ),
        ),
        isNotNull,
      );
      expect(
        await mensajeDeError(
          () => servicio.iniciarSesion(
            email: 'ana@mail.com',
            contrasena: 'nuevaclave1',
          ),
        ),
        isNull,
      );
    });
  });

  test('avisa los cambios de sesión a la pantalla', () async {
    final servicio = await crearServicio();
    var avisos = 0;
    servicio.addListener(() => avisos++);

    await registrar(servicio);
    await servicio.cerrarSesion();

    expect(avisos, 2);
  });

  group('HU05 Cerrar sesión', () {
    test('borra la sesión activa', () async {
      final servicio = await crearServicio();
      await registrar(servicio);
      await servicio.cerrarSesion();

      expect(servicio.haySesionActiva, isFalse);
      final reabierto = await reabrirApp();
      expect(reabierto.haySesionActiva, isFalse);
    });
  });
}
