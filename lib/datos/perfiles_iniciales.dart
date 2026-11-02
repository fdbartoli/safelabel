import '../modelo/perfil.dart';
import 'repositorio_perfiles.dart';

/// Perfiles que se siembran la primera vez que se crea la base local, para que
/// la app no arranque vacía en la demostración. Después son perfiles comunes:
/// se editan y se borran como cualquier otro, y no vuelven a sembrarse.
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
Future<void> sembrarPerfilesIniciales(RepositorioPerfiles repositorio) async {
  final creados = <Perfil>[];
  for (final p in perfilesIniciales) {
    creados.add(await repositorio.crear(p));
  }
  await repositorio.marcarActivos({creados.first.id});
}
