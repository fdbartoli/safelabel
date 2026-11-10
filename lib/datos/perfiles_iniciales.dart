import '../modelo/perfil.dart';
import 'repositorio_perfiles.dart';

/// Ejemplos adicionales para cuentas nuevas. PreparadorPerfiles registra su
/// carga una sola vez por usuario; después pueden editarse o borrarse sin que
/// reaparezcan. Nunca se usan para reconstruir perfiles heredados.
const perfilesIniciales = <Perfil>[
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

/// Guarda [perfilesIniciales] en [repositorio] y deja activo el primero, como
/// hacía la pantalla de inicio cuando eran una constante.
///
/// Pasa por el repositorio, no por SQL directo: así los datos iniciales cumplen
/// las mismas validaciones que un perfil creado a mano.
Future<void> sembrarPerfilesIniciales(
  RepositorioPerfiles repositorio, {
  bool activarPrimero = true,
}) async {
  final creados = <Perfil>[];
  for (final p in perfilesIniciales) {
    creados.add(await repositorio.crear(p));
  }
  if (activarPrimero) await repositorio.marcarActivos({creados.first.id});
}
