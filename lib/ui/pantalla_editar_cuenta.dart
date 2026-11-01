import 'package:flutter/material.dart';

import '../cuenta/servicio_cuenta.dart';
import 'componentes_cuenta.dart';

/// HU04: Editar cuenta (datos personales y contraseña).
class PantallaEditarCuenta extends StatefulWidget {
  const PantallaEditarCuenta({super.key, required this.servicio});

  final ServicioCuenta servicio;

  @override
  State<PantallaEditarCuenta> createState() => _PantallaEditarCuentaState();
}

class _PantallaEditarCuentaState extends State<PantallaEditarCuenta> {
  final _formularioDatos = GlobalKey<FormState>();
  final _formularioContrasena = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _apellido;
  late final TextEditingController _email;
  late final TextEditingController _fechaNacimiento;
  final _contrasenaActual = TextEditingController();
  final _contrasenaNueva = TextEditingController();
  final _confirmacion = TextEditingController();
  String? _errorDatos;
  String? _errorContrasena;

  @override
  void initState() {
    super.initState();
    final cuenta = widget.servicio.cuentaActual();
    final nacimiento = cuenta?.fechaNacimiento;
    _nombre = TextEditingController(text: cuenta?.nombre ?? '');
    _apellido = TextEditingController(text: cuenta?.apellido ?? '');
    _email = TextEditingController(text: cuenta?.email ?? '');
    _fechaNacimiento = TextEditingController(
      text: nacimiento == null ? '' : formatearFecha(nacimiento),
    );
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _email.dispose();
    _fechaNacimiento.dispose();
    _contrasenaActual.dispose();
    _contrasenaNueva.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardarDatos() async {
    setState(() => _errorDatos = null);
    if (!_formularioDatos.currentState!.validate()) return;
    try {
      await widget.servicio.editarDatos(
        nombre: _nombre.text,
        apellido: _apellido.text,
        email: _email.text,
        fechaNacimiento: widget.servicio.parsearFecha(_fechaNacimiento.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Datos guardados.')));
      Navigator.of(context).pop();
    } on ErrorCuenta catch (error) {
      if (!mounted) return;
      setState(() => _errorDatos = error.mensaje);
    }
  }

  Future<void> _cambiarContrasena() async {
    setState(() => _errorContrasena = null);
    if (!_formularioContrasena.currentState!.validate()) return;
    try {
      await widget.servicio.cambiarContrasena(
        contrasenaActual: _contrasenaActual.text,
        contrasenaNueva: _contrasenaNueva.text,
      );
      if (!mounted) return;
      _contrasenaActual.clear();
      _contrasenaNueva.clear();
      _confirmacion.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Contraseña cambiada.')));
    } on ErrorCuenta catch (error) {
      if (!mounted) return;
      setState(() => _errorContrasena = error.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Editar cuenta')),
      body: CuerpoFormulario(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tus datos', style: textos.titleMedium),
            const SizedBox(height: 12),
            Form(
              key: _formularioDatos,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('editar_nombre'),
                    controller: _nombre,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: widget.servicio.validarNombre,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('editar_apellido'),
                    controller: _apellido,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Apellido'),
                    validator: widget.servicio.validarApellido,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('editar_email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: widget.servicio.validarEmail,
                  ),
                  const SizedBox(height: 12),
                  CampoFechaNacimiento(
                    key: const Key('editar_fecha_nacimiento'),
                    controlador: _fechaNacimiento,
                    validador: widget.servicio.validarFechaNacimiento,
                  ),
                  if (_errorDatos != null) MensajeError(_errorDatos!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _guardarDatos,
                    child: const Text('Guardar datos'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text('Cambiar contraseña', style: textos.titleMedium),
            const SizedBox(height: 12),
            Form(
              key: _formularioContrasena,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('editar_contrasena_actual'),
                    controller: _contrasenaActual,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña actual',
                    ),
                    validator: (valor) => (valor == null || valor.isEmpty)
                        ? 'Ingresá tu contraseña actual.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('editar_contrasena_nueva'),
                    controller: _contrasenaNueva,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña nueva',
                      helperText: 'Al menos 8 caracteres.',
                    ),
                    validator: widget.servicio.validarContrasena,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('editar_confirmacion'),
                    controller: _confirmacion,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Repetí la contraseña nueva',
                    ),
                    validator: (valor) => valor != _contrasenaNueva.text
                        ? 'Las contraseñas no coinciden.'
                        : null,
                  ),
                  if (_errorContrasena != null) MensajeError(_errorContrasena!),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _cambiarContrasena,
                    child: const Text('Cambiar contraseña'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
