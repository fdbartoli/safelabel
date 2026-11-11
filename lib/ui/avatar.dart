import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';

/// Avatares de los perfiles y de la cuenta, al estilo de Netflix: un ícono en
/// un cuadrado redondeado de color.
///
/// Los dibuja `random_avatar` (MIT) a partir de un texto, la "semilla": la
/// misma semilla da siempre el mismo avatar. Se generan en el dispositivo, sin
/// internet (el uso principal es offline, sección 2), y solo se guarda la
/// semilla, no una imagen.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.semilla,
    this.tamano = 40,
    this.seleccionado = false,
  });

  /// Texto que define el avatar. Si está vacío se usa uno genérico.
  final String semilla;
  final double tamano;

  /// Marca de selección (en la pantalla para elegir avatar).
  final bool seleccionado;

  @override
  Widget build(BuildContext context) {
    final semilla = this.semilla.trim().isEmpty ? 'SafeLabel' : this.semilla;
    final radio = BorderRadius.circular(tamano * 0.22);
    return Semantics(
      label: 'Avatar',
      image: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          color: colorDeFondo(semilla),
          borderRadius: radio,
          border: seleccionado
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: tamano * 0.05 + 1,
                )
              : null,
        ),
        padding: EdgeInsets.all(tamano * 0.1),
        child: RandomAvatar(
          semilla,
          trBackground: true,
          width: tamano,
          height: tamano,
        ),
      ),
    );
  }

  /// Fondos pastel que combinan con la paleta de la app. Sale de la semilla:
  /// el mismo avatar tiene siempre el mismo fondo.
  static Color colorDeFondo(String semilla) {
    const paleta = [
      Color(0xFFDCEFE3), // verde salvia
      Color(0xFFDDE8F6), // celeste
      Color(0xFFF6E3D3), // durazno
      Color(0xFFEDE1F5), // lavanda
      Color(0xFFF7EFC9), // amarillo
      Color(0xFFF6DCE3), // rosa
      Color(0xFFD9F0EF), // agua
      Color(0xFFE6E6E6), // gris
    ];
    var h = 0;
    for (final c in semilla.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return paleta[h % paleta.length];
  }
}

/// Las semillas que se ofrecen para elegir. [lote] cambia con "Ver otros":
/// son siempre las mismas para el mismo lote, así la grilla no cambia sola.
List<String> semillasSugeridas(int lote, {int cantidad = 12}) => [
  for (var i = 0; i < cantidad; i++) 'safelabel-${lote * cantidad + i}',
];

/// Pantalla para elegir avatar: una grilla de íconos grandes y "Ver otros".
/// Devuelve la semilla elegida, o `null` si se vuelve sin elegir.
class PantallaElegirAvatar extends StatefulWidget {
  const PantallaElegirAvatar({super.key, this.actual, this.titulo});

  /// Semilla actual, para marcarla como elegida.
  final String? actual;
  final String? titulo;

  @override
  State<PantallaElegirAvatar> createState() => _PantallaElegirAvatarState();
}

class _PantallaElegirAvatarState extends State<PantallaElegirAvatar> {
  var _lote = 0;

  @override
  Widget build(BuildContext context) {
    final actual = widget.actual;
    // La actual va primera, así se ve cuál está elegida aunque no sea del lote.
    final semillas = [
      if (actual != null && actual.isNotEmpty) actual,
      ...semillasSugeridas(_lote).where((s) => s != actual),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo ?? 'Elegí un avatar')),
      body: LayoutBuilder(
        builder: (context, restricciones) {
          final columnas = restricciones.maxWidth > 600 ? 5 : 3;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                sliver: SliverGrid.count(
                  crossAxisCount: columnas,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    for (final s in semillas)
                      LayoutBuilder(
                        builder: (context, celda) => InkWell(
                          key: Key('avatar_$s'),
                          borderRadius: BorderRadius.circular(
                            celda.maxWidth * 0.22,
                          ),
                          onTap: () => Navigator.of(context).pop(s),
                          child: Avatar(
                            semilla: s,
                            tamano: celda.maxWidth,
                            seleccionado: s == actual,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _lote++),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Ver otros'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Avatar grande con un lápiz, para los formularios: al tocarlo abre
/// [PantallaElegirAvatar] y avisa la semilla elegida.
class SelectorAvatar extends StatelessWidget {
  const SelectorAvatar({
    super.key,
    required this.semilla,
    required this.alCambiar,
    this.tamano = 104,
    this.titulo,
  });

  final String semilla;
  final ValueChanged<String> alCambiar;
  final double tamano;
  final String? titulo;

  Future<void> _elegir(BuildContext context) async {
    final elegida = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PantallaElegirAvatar(actual: semilla, titulo: titulo),
      ),
    );
    if (elegida != null) alCambiar(elegida);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        children: [
          InkWell(
            key: const Key('selector_avatar'),
            borderRadius: BorderRadius.circular(tamano * 0.22),
            onTap: () => _elegir(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(semilla: semilla, tamano: tamano),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.primary,
                    child: Icon(Icons.edit, size: 16, color: scheme.onPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _elegir(context),
            child: const Text('Cambiar avatar'),
          ),
        ],
      ),
    );
  }
}
