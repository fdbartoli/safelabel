import 'package:flutter/material.dart';

import '../datos/base_conocimiento.dart';
import '../modelo/perfil.dart';
import 'editor_perfil.dart' show nombreSeveridad;

class ListaRestriccionesCompartidas extends StatelessWidget {
  const ListaRestriccionesCompartidas({
    super.key,
    required this.restricciones,
    required this.base,
  });

  final List<RestriccionPerfil> restricciones;
  final BaseConocimiento base;

  @override
  Widget build(BuildContext context) {
    if (restricciones.isEmpty) {
      return Text(
        'Sin restricciones',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      children: [
        for (final restriccion in restricciones)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(base.grupo(restriccion.grupoAlergenoId)!.nombre),
            subtitle: Text(nombreSeveridad(restriccion.severidad)),
          ),
      ],
    );
  }
}
