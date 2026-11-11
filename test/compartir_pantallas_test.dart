import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:safelabel/compartir/restricciones_compartidas.dart';
import 'package:safelabel/compartir/servicio_compartir_restricciones.dart';
import 'package:safelabel/datos/repositorio_perfiles.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/ui/pantalla_escanear_restricciones.dart';
import 'package:safelabel/ui/pantalla_importar_restricciones.dart';
import 'package:safelabel/ui/pantalla_perfiles.dart';

import 'ayuda_base.dart';

const _leche = RestriccionPerfil(
  grupoAlergenoId: 'leche',
  severidad: Severidad.anafilaxia,
);
const _mani = RestriccionPerfil(
  grupoAlergenoId: 'mani',
  severidad: Severidad.leve,
);

final _perfiles = [
  const Perfil(nombre: 'Sofía', restricciones: [_leche]),
  const Perfil(nombre: 'Mateo', restricciones: [_mani]),
];

void main() {
  final base = cargarBaseReal();
  late RepositorioPerfilesMemoria repo;
  late ServicioCompartirRestricciones servicio;
  late String qr;
  bool? resultado;

  setUp(() {
    repo = RepositorioPerfilesMemoria(
      usuarioId: 'receptor',
      gruposValidos: base.grupos.keys.toSet(),
    );
    servicio = ServicioCompartirRestricciones(
      repositorio: repo,
      gruposValidos: base.grupos.keys.toSet(),
      nombrePropietario: 'Ana',
      apellidoPropietario: 'Pérez',
    );
    qr = servicio.codec.codificar(_perfiles, nombre: 'Ana', apellido: 'Pérez');
    resultado = null;
  });

  Future<void> montar(WidgetTester tester, Widget pantalla) async {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultado = await Navigator.of(context)
                    .push<bool>(MaterialPageRoute(builder: (_) => pantalla));
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  PantallaImportarRestricciones vistaPrevia([String? texto]) =>
      PantallaImportarRestricciones(
        textoQr: texto ?? qr,
        servicio: servicio,
        base: base,
      );

  String qrV1() {
    final mapa = jsonDecode(qr) as Map<String, dynamic>
      ..['version'] = 1
      ..['restricciones'] = _perfiles.first.restricciones
          .map(
            (r) => {
              'grupo_alergeno_id': r.grupoAlergenoId,
              'severidad': r.severidad.name,
            },
          )
          .toList();
    mapa
      ..remove('perfiles')
      ..remove('nombre')
      ..remove('apellido');
    return jsonEncode(mapa);
  }

  IconButton botonCompartir(WidgetTester tester) => tester.widget<IconButton>(
    find.byWidgetPredicate(
      (w) =>
          w is IconButton && w.tooltip == 'Compartir perfiles seleccionados',
    ),
  );

  testWidgets('selecciona uno o todos y comparte un único QR', (tester) async {
    final sofia = await repo.crear(_perfiles[0]);
    final mateo = await repo.crear(_perfiles[1]);
    await montar(
      tester,
      PantallaPerfiles(
        repositorio: repo,
        base: base,
        nombrePropietario: 'Ana',
        apellidoPropietario: 'Pérez',
      ),
    );

    expect(botonCompartir(tester).onPressed, isNull);
    await tocar(tester, find.byKey(ValueKey('seleccionar_${sofia.id}')));
    expect(botonCompartir(tester).onPressed, isNotNull);
    await tocar(tester, find.byTooltip('Compartir perfiles seleccionados'));

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Sofía'), findsOneWidget);
    expect(find.text('Mateo'), findsNothing);
    expect(find.text('Anafilaxia'), findsOneWidget);

    await tocar(tester, find.byType(BackButton));
    await tocar(tester, find.byTooltip('Seleccionar todos'));
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((c) => c.value == true),
      isTrue,
    );
    await tocar(tester, find.byTooltip('Compartir perfiles seleccionados'));
    expect(find.text('Sofía'), findsOneWidget);
    expect(find.text('Mateo'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(mateo.id, isNotEmpty);
  });

  testWidgets('la vista previa muestra todos los perfiles y no edita nada', (
    tester,
  ) async {
    final propio = await repo.crear(
      const Perfil(nombre: 'Beto', restricciones: [_leche]),
    );
    await repo.marcarActivos({propio.id});
    await montar(tester, vistaPrevia());

    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Sofía'), findsOneWidget);
    expect(find.text('Mateo'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Anafilaxia'), findsOneWidget);
    expect(find.text('Leve'), findsOneWidget);
    expect(await repo.obtenerTodos(), hasLength(1));

    await tocar(tester, find.text('Cancelar'));
    expect(resultado, isFalse);
    expect(await repo.obtenerTodos(), hasLength(1));
    expect((await repo.obtenerActivos()).single.id, propio.id);
  });

  testWidgets('guarda todos los perfiles, inactivos y sin tocar los previos', (
    tester,
  ) async {
    final propio = await repo.crear(
      const Perfil(nombre: 'Beto', restricciones: [_leche]),
    );
    await repo.marcarActivos({propio.id});
    await montar(tester, vistaPrevia());
    await tocar(tester, find.text('Guardar 2 perfiles'));

    expect(resultado, isTrue);
    final todos = await repo.obtenerTodos();
    expect(todos.map((p) => p.nombre), ['Beto', 'Sofía', 'Mateo']);
    expect(todos.every((p) => p.usuarioId == 'receptor'), isTrue);
    expect((await repo.obtenerActivos()).single.id, propio.id);
    expect(
      todos.firstWhere((p) => p.nombre == 'Sofía').severidadPara('leche'),
      Severidad.anafilaxia,
    );
  });

  testWidgets('un QR inválido no ofrece guardar y no persiste nada', (
    tester,
  ) async {
    await montar(tester, vistaPrevia('{"usuario_id":"otro"}'));
    expect(find.textContaining('no es de restricciones'), findsOneWidget);
    expect(find.textContaining('Guardar'), findsNothing);
    await tocar(tester, find.text('Cancelar'));
    expect(await repo.obtenerTodos(), isEmpty);
    expect(resultado, isFalse);
  });

  testWidgets('un QR v1 se previsualiza y se guarda como perfil recibido', (
    tester,
  ) async {
    await montar(tester, vistaPrevia(qrV1()));
    expect(
      find.text(CodecRestriccionesCompartidas.nombreAnterior),
      findsOneWidget,
    );
    expect(find.textContaining('versión anterior'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tocar(tester, find.text('Guardar perfil'));
    expect(resultado, isTrue);
    expect(
      (await repo.obtenerTodos()).single.nombre,
      CodecRestriccionesCompartidas.nombreAnterior,
    );
  });

  testWidgets('un doble toque en guardar no duplica los perfiles', (
    tester,
  ) async {
    await montar(tester, vistaPrevia());
    final guardar = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Guardar 2 perfiles'),
        )
        .onPressed!;
    guardar();
    await tester.pump();
    guardar();
    await tester.pumpAndSettle();
    expect(resultado, isTrue);
    expect(await repo.obtenerTodos(), hasLength(2));
  });

  testWidgets('la cámara procesa una sola lectura y cancelar permite reintentar', (
    tester,
  ) async {
    await montar(
      tester,
      PantallaEscanearRestricciones(
        servicio: servicio,
        base: base,
        construirCamara: (alLeer) => TextButton(
          onPressed: () {
            alLeer(qr);
            alLeer(qr);
          },
          child: const Text('Simular cámara'),
        ),
      ),
    );
    await tocar(tester, find.text('Simular cámara'));
    expect(find.byType(PantallaImportarRestricciones), findsOneWidget);
    expect(await repo.obtenerTodos(), isEmpty);
    await tocar(tester, find.text('Cancelar'));
    expect(find.text('Simular cámara'), findsOneWidget);
    expect(resultado, isNull);
    await tocar(tester, find.text('Simular cámara'));
    await tocar(tester, find.text('Guardar 2 perfiles'));
    expect(resultado, isTrue);
    expect(await repo.obtenerTodos(), hasLength(2));
  });
}
