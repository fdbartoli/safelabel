import '../modelo/perfil.dart';

/// Perfiles de ejemplo para la Etapa 1. La persistencia, la autenticación y la
/// compartición llegan en la Etapa 3; acá solo se necesita algo contra qué
/// cruzar el análisis.
const perfilesDemo = <Perfil>[
  Perfil(
    nombre: 'Sofía (alergia a la leche)',
    restricciones: [
      RestriccionPerfil(
        grupoAlergenoId: 'leche',
        severidad: Severidad.anafilaxia,
      ),
    ],
  ),
  Perfil(
    nombre: 'Mateo (celíaco)',
    restricciones: [
      RestriccionPerfil(
        grupoAlergenoId: 'trigo',
        severidad: Severidad.moderada,
      ),
    ],
  ),
  Perfil(
    nombre: 'Juli (frutos secos y maní)',
    restricciones: [
      RestriccionPerfil(
        grupoAlergenoId: 'frutos_secos',
        severidad: Severidad.anafilaxia,
      ),
      RestriccionPerfil(
        grupoAlergenoId: 'mani',
        severidad: Severidad.anafilaxia,
      ),
    ],
  ),
  Perfil(
    nombre: 'Intolerancia a sulfitos',
    restricciones: [
      RestriccionPerfil(grupoAlergenoId: 'sulfitos', severidad: Severidad.leve),
    ],
  ),
];
