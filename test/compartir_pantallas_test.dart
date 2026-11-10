import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:safelabel/compartir/restricciones_compartidas.dart';
import 'package:safelabel/compartir/servicio_compartir_restricciones.dart';
import 'package:safelabel/datos/repositorio_perfiles.dart';
import 'package:safelabel/modelo/perfil.dart';
import 'package:safelabel/ui/pantalla_compartir_restricciones.dart';
import 'package:safelabel/ui/pantalla_escanear_restricciones.dart';
import 'package:safelabel/ui/pantalla_importar_restricciones.dart';
import 'package:safelabel/ui/pantalla_perfiles.dart';

import 'ayuda_base.dart';

const _restricciones = [
  RestriccionPerfil(grupoAlergenoId: 'leche', severidad: Severidad.anafilaxia),
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
    qr = servicio.codec.codificar(
      _restricciones,
      nombre: 'Ana',
      apellido: 'Pérez',
    );
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

  String qrVersionAnterior() {
    final mapa = jsonDecode(qr) as Map<String, dynamic>
      ..remove('nombre')
      ..remove('apellido')
      ..['version'] = 1;
    return jsonEncode(mapa);
  }

  testWidgets(
    'solo Mi perfil ofrece compartir y la acción queda deshabilitada si está vacío',
    (tester) async {
      await repo.asegurarPersonal();
      await repo.crear(
        const Perfil(nombre: 'Adicional', restricciones: _restricciones),
      );
      await montar(
        tester,
        PantallaPerfiles(
          repositorio: repo,
          base: base,
          nombrePropietario: 'Ana',
          apellidoPropietario: 'Pérez',
        ),
      );
      expect(find.byTooltip('Compartir mis restricciones'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) =>
                    w is IconButton &&
                    w.tooltip == 'Compartir mis restricciones',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.byTooltip('Escanear restricciones'), findsOneWidget);
    },
  );

  testWidgets('el QR generado solo representa Mi perfil y su propietario', (
    tester,
  ) async {
    final personal = await repo.asegurarPersonal();
    await repo.actualizar(personal.copiarCon(restricciones: _restricciones));
    await repo.crear(
      const Perfil(
        nombre: 'Privado adicional',
        restricciones: [
          RestriccionPerfil(grupoAlergenoId: 'mani', severidad: Severidad.leve),
        ],
      ),
    );
    await montar(
      tester,
      PantallaPerfiles(
        repositorio: repo,
        base: base,
        nombrePropietario: 'Ana',
        apellidoPropietario: 'Pérez',
      ),
    );
    await tocar(tester, find.byTooltip('Compartir mis restricciones'));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is CustomPaint && w.painter is QrPainter),
      findsOneWidget,
    );
    expect(await servicio.generarQrPersonal(), qr);
    expect(find.textContaining('nombre y apellido'), findsOneWidget);
    expect(find.text('Anafilaxia'), findsOneWidget);
    expect(find.text('Privado adicional'), findsNothing);
  });

  testWidgets(
    'no se genera QR cuando el servicio encuentra el personal vacío',
    (tester) async {
      await repo.asegurarPersonal();
      await montar(
        tester,
        PantallaCompartirRestricciones(servicio: servicio, base: base),
      );
      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('Agregá restricciones'), findsOneWidget);
    },
  );

  testWidgets(
    'vista previa muestra el nombre sin editarlo y cancelar no guarda',
    (tester) async {
      final personal = await repo.asegurarPersonal();
      await repo.marcarActivos({personal.id});
      await montar(tester, vistaPrevia());
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Anafilaxia'), findsOneWidget);
      expect(await repo.obtenerTodos(), hasLength(1));
      await tocar(tester, find.text('Cancelar'));
      expect(resultado, isFalse);
      expect(await repo.obtenerTodos(), hasLength(1));
      expect((await repo.obtenerPersonal())!.restricciones, isEmpty);
      expect((await repo.obtenerActivos()).single.id, personal.id);
    },
  );

  testWidgets(
    'guardar guarda el nombre del propietario, inactivo y sin tocar el personal',
    (tester) async {
      final personal = await repo.asegurarPersonal();
      await repo.marcarActivos({personal.id});
      await montar(tester, vistaPrevia());
      await tocar(tester, find.text('Guardar perfil'));
      expect(resultado, isTrue);
      final copia = (await repo.obtenerTodos()).singleWhere(
        (p) => !p.esPersonal,
      );
      expect(copia.nombre, 'Ana Pérez');
      expect(copia.usuarioId, 'receptor');
      expect(copia.severidadPara('leche'), Severidad.anafilaxia);
      expect((await repo.obtenerActivos()).single.id, personal.id);
      expect((await repo.obtenerPersonal())!.restricciones, isEmpty);
    },
  );

  testWidgets('un QR inválido no ofrece guardar y no persiste nada', (
    tester,
  ) async {
    await montar(tester, vistaPrevia('{"usuario_id":"otro"}'));
    expect(find.textContaining('no es de restricciones'), findsOneWidget);
    expect(find.text('Guardar perfil'), findsNothing);
    await tocar(tester, find.text('Cancelar'));
    expect(await repo.obtenerTodos(), isEmpty);
    expect(resultado, isFalse);
  });

  testWidgets(
    'un QR v1 muestra el nombre anterior y se puede guardar sin editar',
    (tester) async {
      await montar(tester, vistaPrevia(qrVersionAnterior()));
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
    },
  );

  testWidgets(
    'restricciones iguales a otro perfil no bloquean ni piden confirmación',
    (tester) async {
      await repo.crear(
        const Perfil(nombre: 'Otra persona', restricciones: _restricciones),
      );
      await montar(tester, vistaPrevia());
      expect(find.textContaining('Ya tenés un perfil'), findsNothing);
      expect(
        find.text('Quiero guardar otra copia de todos modos'),
        findsNothing,
      );
      await tocar(tester, find.text('Guardar perfil'));
      expect(resultado, isTrue);
      expect(await repo.obtenerTodos(), hasLength(2));
      expect(await repo.obtenerActivos(), isEmpty);
    },
  );

  testWidgets('un doble toque en guardar crea una sola copia', (tester) async {
    await montar(tester, vistaPrevia());
    final guardar = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Guardar perfil'),
        )
        .onPressed!;
    guardar();
    await tester.pump();
    guardar();
    await tester.pumpAndSettle();
    expect(resultado, isTrue);
    expect(await repo.obtenerTodos(), hasLength(1));
  });

  testWidgets(
    'la cámara procesa una sola lectura y cancelar permite volver a escanear',
    (tester) async {
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
      await tocar(tester, find.text('Guardar perfil'));
      expect(resultado, isTrue);
      expect(await repo.obtenerTodos(), hasLength(1));
    },
  );
}
