import 'package:flutter/material.dart';

import '../cuenta/reglas_usuario.dart';
import '../cuenta/servicio_cuenta.dart';

/// Centra el contenido y limita su ancho, para que los formularios de cuenta
/// se vean bien tanto en el celular como en Chrome.
class CuerpoFormulario extends StatelessWidget {
  const CuerpoFormulario({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Mensaje de error de un formulario.
class MensajeError extends StatelessWidget {
  const MensajeError(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        mensaje,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

String formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

/// Cierra todas las pantallas apiladas y vuelve a la primera, que es la
/// [PuertaDeSesion]: ella decide si mostrar el ingreso o la app.
void volverAlInicio(BuildContext context) {
  Navigator.of(context).popUntil((ruta) => ruta.isFirst);
}

/// Campo de fecha de nacimiento: se puede escribir (dd/mm/aaaa) o elegir en
/// el calendario.
class CampoFechaNacimiento extends StatelessWidget {
  const CampoFechaNacimiento({
    super.key,
    required this.controlador,
    required this.validador,
  });

  final TextEditingController controlador;
  final FormFieldValidator<String> validador;

  Future<void> _elegirEnCalendario(BuildContext context) async {
    final hoy = DateTime.now();
    final primera = DateTime(1900);
    final escrita = ReglasUsuario.parsearFecha(controlador.text);
    final inicial =
        (escrita == null || escrita.isAfter(hoy) || escrita.isBefore(primera))
        ? DateTime(hoy.year - 25)
        : escrita;
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: primera,
      lastDate: hoy,
      helpText: 'Fecha de nacimiento',
    );
    if (elegida != null) controlador.text = formatearFecha(elegida);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controlador,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: 'Fecha de nacimiento',
        helperText: 'dd/mm/aaaa',
        suffixIcon: IconButton(
          tooltip: 'Elegir en el calendario',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () => _elegirEnCalendario(context),
        ),
      ),
      validator: validador,
    );
  }
}

/// Casilla obligatoria de aceptación de los términos y condiciones.
class CampoAceptaTerminos extends FormField<bool> {
  CampoAceptaTerminos({
    super.key,
    required ValueChanged<bool> alCambiar,
    required VoidCallback alLeerTerminos,
  }) : super(
         initialValue: false,
         validator: (valor) =>
             valor == true ? null : ServicioCuenta.mensajeTerminosNoAceptados,
         builder: (estado) => Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             CheckboxListTile(
               key: const Key('casilla_terminos'),
               value: estado.value ?? false,
               onChanged: (valor) {
                 estado.didChange(valor ?? false);
                 alCambiar(valor ?? false);
               },
               contentPadding: EdgeInsets.zero,
               controlAffinity: ListTileControlAffinity.leading,
               title: const Text('Leí y acepto los términos y condiciones'),
             ),
             TextButton(
               onPressed: alLeerTerminos,
               child: const Text('Leer los términos y condiciones'),
             ),
             if (estado.errorText case final error?)
               Text(
                 error,
                 style: TextStyle(
                   color: Theme.of(estado.context).colorScheme.error,
                 ),
               ),
           ],
         ),
       );
}
