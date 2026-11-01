import 'package:flutter/material.dart';

import '../cuenta/servicio_cuenta.dart';
import 'componentes_cuenta.dart';
import 'pantalla_registro.dart';

/// HU02: Iniciar sesión.
class PantallaInicioSesion extends StatefulWidget {
  const PantallaInicioSesion({super.key, required this.servicio});

  final ServicioCuenta servicio;

  @override
  State<PantallaInicioSesion> createState() => _PantallaInicioSesionState();
}

class _PantallaInicioSesionState extends State<PantallaInicioSesion> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _contrasena = TextEditingController();
  bool _procesando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    setState(() => _error = null);
    if (!_formulario.currentState!.validate()) return;
    setState(() => _procesando = true);
    try {
      // Si sale bien, la PuertaDeSesion muestra sola la pantalla principal.
      await widget.servicio.iniciarSesion(
        email: _email.text,
        contrasena: _contrasena.text,
      );
    } on ErrorCuenta catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.mensaje;
        _procesando = false;
      });
    }
  }

  void _irARegistro() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaRegistro(servicio: widget.servicio),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: CuerpoFormulario(
        child: Form(
          key: _formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('SafeLabel', style: textos.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Ingresá con tu cuenta para consultar etiquetas.',
                style: textos.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const Key('login_email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (valor) => (valor == null || valor.trim().isEmpty)
                    ? 'Ingresá tu email.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('login_contrasena'),
                controller: _contrasena,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                validator: (valor) => (valor == null || valor.isEmpty)
                    ? 'Ingresá tu contraseña.'
                    : null,
                onFieldSubmitted: (_) => _ingresar(),
              ),
              if (_error != null) MensajeError(_error!),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _procesando ? null : _ingresar,
                child: const Text('Ingresar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _procesando ? null : _irARegistro,
                child: const Text('¿No tenés cuenta? Registrate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
