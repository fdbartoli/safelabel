import 'package:flutter/material.dart';

import '../modelo/semaforo.dart';
import '../sugerencias/info_ingrediente.dart';
import 'tema.dart';

/// Semáforo por perfil, arriba del resultado: una tarjeta por perfil activo
/// con su color, el nombre y si es compatible, y un acordeón con los
/// ingredientes en rojo o verde para ese perfil. Ver `modelo/semaforo.dart`.
///
/// Con [gestorInfo], cada ingrediente tiene un botón "Más info" que abre una
/// explicación por IA (sección 5.7).
class SeccionSemaforo extends StatelessWidget {
  const SeccionSemaforo({super.key, required this.semaforos, this.gestorInfo});

  final List<SemaforoPerfil> semaforos;
  final GestorInfoIngredientes? gestorInfo;

  @override
  Widget build(BuildContext context) {
    if (semaforos.isEmpty) {
      return Text(
        'No hay perfiles activos: elegí al menos uno en la pantalla de inicio '
        'para ver si este producto es compatible.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in semaforos)
          _TarjetaPerfil(semaforo: s, gestorInfo: gestorInfo),
      ],
    );
  }
}

ColoresSemaforo _colores(ColorSemaforo c) => switch (c) {
  ColorSemaforo.rojo => ColoresSemaforo.rojo,
  ColorSemaforo.ambar => ColoresSemaforo.ambar,
  ColorSemaforo.verde => ColoresSemaforo.verde,
};

(ColoresSemaforo, IconData) _estiloIngrediente(EstadoIngrediente e) =>
    switch (e) {
      EstadoIngrediente.choca => (ColoresSemaforo.rojo, Icons.cancel_rounded),
      EstadoIngrediente.noReconocido => (
        ColoresSemaforo.ambar,
        Icons.help_rounded,
      ),
      EstadoIngrediente.noChoca => (
        ColoresSemaforo.verde,
        Icons.check_circle_rounded,
      ),
    };

class _TarjetaPerfil extends StatelessWidget {
  const _TarjetaPerfil({required this.semaforo, this.gestorInfo});

  final SemaforoPerfil semaforo;
  final GestorInfoIngredientes? gestorInfo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = _colores(semaforo.color);
    final icono = switch (semaforo.color) {
      ColorSemaforo.rojo => Icons.cancel_rounded,
      ColorSemaforo.ambar => Icons.help_rounded,
      ColorSemaforo.verde => Icons.check_circle_rounded,
    };

    // Lo que choca primero, después lo no reconocido y al final lo demás.
    final ingredientes = [...semaforo.ingredientes]
      ..sort((a, b) => _orden(a.estado).compareTo(_orden(b.estado)));
    final cantidadChoca = ingredientes
        .where((i) => i.estado == EstadoIngrediente.choca)
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // Material (no Container) para que el acordeón dibuje bien su efecto
      // al tocarlo sobre el fondo de color.
      child: Material(
        color: colores.fondo,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colores.fuerte.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icono, size: 44, color: colores.fuerte),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // El perfil completo, chico, como etiqueta.
                        Text(
                          semaforo.perfil,
                          style: tema.textTheme.labelMedium?.copyWith(
                            color: colores.texto,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // La frase principal: "Sofía puede consumir este
                        // producto" / "No es seguro para Mateo".
                        Text(
                          semaforo.titular,
                          style: tema.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colores.fuerte,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final m in semaforo.motivos)
                          Text(
                            m,
                            style: tema.textTheme.bodyMedium?.copyWith(
                              color: colores.texto,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (ingredientes.isNotEmpty)
              Theme(
                // Sin las líneas divisorias que ExpansionTile dibuja por
                // defecto.
                data: tema.copyWith(
                  dividerColor: Colors.transparent,
                  // Sin el fondo gris que el tema les da a las filas de lista.
                  listTileTheme: tema.listTileTheme.copyWith(
                    tileColor: Colors.transparent,
                  ),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  iconColor: colores.texto,
                  collapsedIconColor: colores.texto,
                  // Sin el fondo gris que el tema le da a los ListTile.
                  backgroundColor: Colors.transparent,
                  collapsedBackgroundColor: Colors.transparent,
                  title: Text(
                    cantidadChoca > 0
                        ? 'Ver ingredientes (${ingredientes.length}) · '
                              '$cantidadChoca con problema'
                        : 'Ver ingredientes (${ingredientes.length})',
                    style: tema.textTheme.labelLarge?.copyWith(
                      color: colores.texto,
                    ),
                  ),
                  children: [
                    for (final i in ingredientes)
                      _FilaIngrediente(
                        i,
                        alPedirInfo: gestorInfo == null
                            ? null
                            : () => _mostrarInfo(context, i),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _mostrarInfo(BuildContext context, IngredienteSemaforo i) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => HojaInfoIngrediente(
        ingrediente: i,
        nombre: semaforo.nombre,
        gestor: gestorInfo!,
        solicitud: SolicitudInfoIngrediente(
          ingrediente: i.texto,
          estado: i.estado,
          chocaCon: i.motivo,
          restriccionesPerfil: semaforo.restricciones,
        ),
      ),
    );
  }

  static int _orden(EstadoIngrediente e) => switch (e) {
    EstadoIngrediente.choca => 0,
    EstadoIngrediente.noReconocido => 1,
    EstadoIngrediente.noChoca => 2,
  };
}

class _FilaIngrediente extends StatelessWidget {
  const _FilaIngrediente(this.ingrediente, {this.alPedirInfo});

  final IngredienteSemaforo ingrediente;
  final VoidCallback? alPedirInfo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final (colores, icono) = _estiloIngrediente(ingrediente.estado);
    final detalle = switch (ingrediente.estado) {
      // Lo declarado en la etiqueta ya lo dice en el nombre.
      EstadoIngrediente.choca when ingrediente.declarado => null,
      EstadoIngrediente.choca => 'Contiene ${ingrediente.motivo ?? ''}',
      EstadoIngrediente.noReconocido =>
        'No lo reconocimos: revisalo en la etiqueta',
      EstadoIngrediente.noChoca => null,
    };
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: tema.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icono, size: 22, color: colores.fuerte),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingrediente.texto,
                  style: tema.textTheme.bodyLarge?.copyWith(
                    fontWeight: ingrediente.estado == EstadoIngrediente.choca
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                if (detalle != null)
                  Text(
                    detalle,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: colores.texto,
                    ),
                  ),
              ],
            ),
          ),
          if (alPedirInfo != null)
            TextButton.icon(
              onPressed: alPedirInfo,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Más info'),
              style: TextButton.styleFrom(
                foregroundColor: temaApp.colorScheme.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

/// Hoja de "Más info": primero lo que dice la base (definitivo), después la
/// explicación de la IA, siempre marcada como tal (sección 5.7).
class HojaInfoIngrediente extends StatefulWidget {
  const HojaInfoIngrediente({
    super.key,
    required this.ingrediente,
    required this.nombre,
    required this.gestor,
    required this.solicitud,
  });

  final IngredienteSemaforo ingrediente;

  /// Nombre de pila del perfil, para las frases ("Sofía").
  final String nombre;
  final GestorInfoIngredientes gestor;
  final SolicitudInfoIngrediente solicitud;

  @override
  State<HojaInfoIngrediente> createState() => _HojaInfoIngredienteState();
}

class _HojaInfoIngredienteState extends State<HojaInfoIngrediente> {
  late Future<InfoIngrediente> _info = widget.gestor.obtener(widget.solicitud);

  void _reintentar() =>
      setState(() => _info = widget.gestor.obtener(widget.solicitud));

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final i = widget.ingrediente;
    final (colores, icono) = _estiloIngrediente(i.estado);
    final dictamen = switch (i.estado) {
      EstadoIngrediente.choca =>
        'No es seguro para ${widget.nombre}: contiene '
            '${i.motivo ?? 'algo que tiene que evitar'}.',
      EstadoIngrediente.noChoca =>
        'Este ingrediente no es un problema para ${widget.nombre}.',
      EstadoIngrediente.noReconocido =>
        'No lo reconocimos, así que no sabemos si es un problema para '
            '${widget.nombre}. Revisalo en la etiqueta.',
    };

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                i.texto,
                style: tema.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              // Lo que dice la base: es lo que decide el color.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colores.fondo,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(icono, color: colores.fuerte),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dictamen,
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: colores.texto,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: temaApp.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Generado por IA',
                    style: tema.textTheme.labelLarge?.copyWith(
                      color: temaApp.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<InfoIngrediente>(
                future: _info,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) return _error(context, snap.error);
                  return _contenido(context, snap.data!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, InfoIngrediente info) {
    final tema = Theme.of(context);
    Widget seccion(String titulo, String texto) => texto.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: tema.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(texto, style: tema.textTheme.bodyMedium),
              ],
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        seccion('Qué es', info.queEs),
        seccion('De dónde sale', info.origen),
        seccion('Dónde aparece', info.dondeAparece),
        Text(
          widget.ingrediente.estado == EstadoIngrediente.noReconocido
              ? 'Es solo orientativo: la IA puede equivocarse y no '
                    'verificamos este ingrediente. Ante la duda, revisá la '
                    'etiqueta.'
              : 'La IA solo te cuenta qué es y puede equivocarse. Si '
                    '${widget.nombre} puede consumirlo lo decide la app, '
                    'no la IA.',
          style: tema.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _error(BuildContext context, Object? error) {
    final tema = Theme.of(context);
    final mensaje = switch (error) {
      ErrorInfoIngrediente(motivo: 'falta configurar la clave') =>
        'La conexión con la IA todavía no está configurada en esta versión '
            'de la app.',
      ErrorInfoIngrediente(sinConexion: true) =>
        'Necesitás conexión a internet para ver más información. El resto '
            'del resultado funciona sin conexión.',
      _ => 'No se pudo obtener la información en este momento.',
    };
    final reintentable =
        !(error is ErrorInfoIngrediente &&
            error.motivo == 'falta configurar la clave');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mensaje, style: tema.textTheme.bodyMedium),
        if (reintentable) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _reintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ],
    );
  }
}
