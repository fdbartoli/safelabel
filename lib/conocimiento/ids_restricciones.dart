/// Puente temporal entre los ids estables de la base consolidada y los ids que
/// hoy guardan los perfiles locales. Mantenerlo centralizado evita repartir la
/// compatibilidad por el pipeline.
const idPerfilPorRestriccion = <String, String>{
  'RES-MILK': 'leche',
  'RES-CELIAC': 'trigo',
};

String idPerfilParaRestriccion(String restrictionId) =>
    idPerfilPorRestriccion[restrictionId] ?? restrictionId;
