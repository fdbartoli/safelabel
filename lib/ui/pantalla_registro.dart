import 'dart:math';

import 'package:flutter/material.dart';

import '../cuenta/servicio_cuenta.dart';
import 'avatar.dart';
import 'componentes_cuenta.dart';
import 'pantalla_terminos.dart';

/// HU01: Registrarse.
class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key, required this.servicio});

  final ServicioCuenta servicio;

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _email = TextEditingController();
  final _fechaNacimiento = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _aceptaTerminos = false;

  /// Arranca con uno al azar de los sugeridos; se cambia tocándolo.
  String _avatar = () {
    final sugeridos = semillasSugeridas(0);
    return sugeridos[Random().nextInt(sugeridos.length)];
  }();
  bool _procesando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _email.dispose();
    _fechaNacimiento.dispose();
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  void _leerTerminos() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PantallaTerminos()));
  }

  Future<void> _crearCuenta() async {
    setState(() => _error = null);
    if (!_formulario.currentState!.validate()) return;
    setState(() => _procesando = true);
    try {
      await widget.servicio.registrar(
        nombre: _nombre.text,
        apellido: _apellido.text,
        email: _email.text,
        fechaNacimiento: widget.servicio.parsearFecha(_fechaNacimiento.text),
        contrasena: _contrasena.text,
        aceptaTerminos: _aceptaTerminos,
        avatar: _avatar,
      );
      if (!mounted) return;
      // Queda la sesión iniciada: al volver a la PuertaDeSesion se ve la app.
      volverAlInicio(context);
    } on ErrorCuenta catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.mensaje;
        _procesando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicio = widget.servicio;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: CuerpoFormulario(
        child: Form(
          key: _formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectorAvatar(
                semilla: _avatar,
                titulo: 'Elegí tu avatar',
                alCambiar: (s) => setState(() => _avatar = s),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('registro_nombre'),
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: servicio.validarNombre,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('registro_apellido'),
                controller: _apellido,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Apellido'),
                validator: servicio.validarApellido,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('registro_email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: servicio.validarEmail,
              ),
              const SizedBox(height: 12),
              CampoFechaNacimiento(
                key: const Key('registro_fecha_nacimiento'),
                controlador: _fechaNacimiento,
                validador: servicio.validarFechaNacimiento,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('registro_contrasena'),
                controller: _contrasena,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  helperText: 'Al menos 8 caracteres.',
                ),
                validator: servicio.validarContrasena,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('registro_confirmacion'),
                controller: _confirmacion,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Repetí la contraseña',
                ),
                validator: (valor) => valor != _contrasena.text
                    ? 'Las contraseñas no coinciden.'
                    : null,
              ),
              const SizedBox(height: 12),
              CampoAceptaTerminos(
                alCambiar: (valor) => _aceptaTerminos = valor,
                alLeerTerminos: _leerTerminos,
              ),
              if (_error != null) MensajeError(_error!),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _procesando ? null : _crearCuenta,
                child: const Text('Crear cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
