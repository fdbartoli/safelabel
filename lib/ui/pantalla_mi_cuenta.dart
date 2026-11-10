import 'package:flutter/material.dart';

import '../cuenta/servicio_cuenta.dart';
import 'componentes_cuenta.dart';
import 'pantalla_editar_cuenta.dart';
import 'pantalla_terminos.dart';

/// HU03: Consultar cuenta. HU05: Cerrar sesión.
class PantallaMiCuenta extends StatefulWidget {
  const PantallaMiCuenta({super.key, required this.servicio});

  final ServicioCuenta servicio;

  @override
  State<PantallaMiCuenta> createState() => _PantallaMiCuentaState();
}

class _PantallaMiCuentaState extends State<PantallaMiCuenta> {
  Future<void> _editar() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaEditarCuenta(servicio: widget.servicio),
      ),
    );
    if (mounted) setState(() {});
  }

  void _leerTerminos() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PantallaTerminos()));
  }

  Future<void> _confirmarCierreDeSesion() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Vas a tener que ingresar tu email y contraseña para volver a entrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contextoDialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contextoDialogo).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await widget.servicio.cerrarSesion();
    } on ErrorCuenta catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.mensaje)));
      }
      return;
    }
    if (!mounted) return;
    volverAlInicio(context);
  }

  @override
  Widget build(BuildContext context) {
    final cuenta = widget.servicio.cuentaActual();
    if (cuenta == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi cuenta')),
        body: const Center(child: Text('No hay una sesión activa.')),
      );
    }
    final nacimiento = cuenta.fechaNacimiento;
    final aceptacion = cuenta.fechaAceptacionTerminos;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: CuerpoFormulario(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Dato(
              icono: Icons.person_outline,
              titulo: 'Nombre y apellido',
              valor: cuenta.nombreCompleto,
            ),
            _Dato(
              icono: Icons.email_outlined,
              titulo: 'Email',
              valor: cuenta.email,
            ),
            _Dato(
              icono: Icons.cake_outlined,
              titulo: 'Fecha de nacimiento',
              valor: nacimiento == null
                  ? 'Sin completar'
                  : formatearFecha(nacimiento),
            ),
            _Dato(
              icono: Icons.event_outlined,
              titulo: 'Cuenta creada el',
              valor: formatearFecha(cuenta.fechaAlta),
            ),
            _Dato(
              icono: Icons.gavel_outlined,
              titulo: 'Términos y condiciones',
              valor: aceptacion == null
                  ? 'Sin registro de aceptación'
                  : 'Versión ${cuenta.versionTerminos}, aceptada el '
                        '${formatearFecha(aceptacion)}',
              alTocar: _leerTerminos,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _editar,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar cuenta'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _confirmarCierreDeSesion,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.titulo,
    required this.valor,
    this.alTocar,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icono),
      title: Text(titulo),
      subtitle: Text(valor),
      trailing: alTocar == null ? null : const Icon(Icons.chevron_right),
      onTap: alTocar,
    );
  }
}
