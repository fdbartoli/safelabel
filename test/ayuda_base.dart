import 'dart:io';

import 'package:safelabel/datos/base_conocimiento.dart';

/// Carga la base real empaquetada (`lib/datos/ingredientes.json`) para los tests
/// que necesitan datos representativos.
BaseConocimiento cargarBaseReal() {
  final archivo = File('lib/datos/ingredientes.json');
  return BaseConocimiento.desdeJsonString(archivo.readAsStringSync());
}

/// Base mínima y controlada para tests de lógica que no dependen del dataset.
BaseConocimiento baseMinima() {
  return BaseConocimiento.desdeJsonString('''
{
  "version": "test-min",
  "atribucion": "test",
  "grupos_alergenos": [
    { "id": "leche", "nombre": "leche", "caa_obligatorio": true, "texto_etiqueta": "leche" },
    { "id": "trigo", "nombre": "cereales con gluten", "caa_obligatorio": true, "texto_etiqueta": "trigo, avena, cebada y/o centeno" },
    { "id": "soja", "nombre": "soja", "caa_obligatorio": true, "texto_etiqueta": "soja" }
  ],
  "ingredientes": [
    {
      "nombre_canonico": "caseinato de sodio",
      "grupo_alergeno_id": "leche",
      "certeza": "certain",
      "explicacion": "Proteína de la leche.",
      "fuente": "test",
      "sinonimos": [
        { "texto": "caseinato sodico", "tipo": "technical" },
        { "texto": "INS 469", "tipo": "technical" }
      ]
    },
    {
      "nombre_canonico": "harina de trigo",
      "grupo_alergeno_id": "trigo",
      "certeza": "certain",
      "explicacion": "Contiene gluten.",
      "fuente": "test",
      "sinonimos": [ { "texto": "harina 000", "tipo": "commercial" } ]
    },
    {
      "nombre_canonico": "lecitina de soja",
      "grupo_alergeno_id": "soja",
      "certeza": "certain",
      "explicacion": "Emulsionante derivado de soja.",
      "fuente": "test",
      "sinonimos": [ { "texto": "INS 322", "tipo": "technical" } ]
    },
    {
      "nombre_canonico": "maltodextrina",
      "grupo_alergeno_id": "trigo",
      "certeza": "depends_on_source",
      "explicacion": "Puede derivar de maíz o de trigo.",
      "fuente": "test"
    },
    {
      "nombre_canonico": "sal",
      "certeza": "certain",
      "explicacion": "No está asociada a ningún alérgeno de declaración obligatoria.",
      "fuente": "test",
      "sinonimos": [ { "texto": "sal fina", "tipo": "commercial" } ]
    },
    {
      "nombre_canonico": "azucar",
      "certeza": "certain",
      "explicacion": "No está asociada a ningún alérgeno de declaración obligatoria.",
      "fuente": "test"
    },
    {
      "nombre_canonico": "agua",
      "certeza": "certain",
      "explicacion": "No está asociada a ningún alérgeno de declaración obligatoria.",
      "fuente": "test"
    }
  ],
  "excepciones": [
    {
      "nombre_ingrediente": "maltodextrina",
      "grupo_alergeno_id": "trigo",
      "regla": "Maltodextrina de trigo/cebada exenta de declarar gluten (CAA 235 séptimo).",
      "fuente": "CAA art. 235 séptimo"
    }
  ]
}
''');
}
