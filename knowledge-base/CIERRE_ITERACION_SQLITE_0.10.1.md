# Cierre de la iteración SQLite 0.10.1

## Objetivo

Adaptar la base de conocimiento SQLite para reemplazar el catálogo JSON utilizado por la aplicación, conservando el comportamiento esperado para ingredientes relacionados con restricciones, ingredientes conocidos sin relación y términos desconocidos.

Esta iteración modifica el contenido y la generación de la base. No cambia el algoritmo de búsqueda ni el procesamiento del texto recibido desde OCR.

## Resultado alcanzado

La base distingue tres resultados:

- `MATCHED`: concepto conocido relacionado con una restricción activa.
- `RECOGNIZED`: concepto conocido sin relación con las restricciones disponibles.
- `UNKNOWN`: término ausente de la base.

Se incorporaron conceptos sin restricción para cubrir ingredientes que antes resolvía el JSON. La versión `0.10.1` agregó:

- agua;
- aceite de girasol;
- carbonato de calcio.

También se conservaron los términos curados incorporados en la versión anterior:

| Término leído | Concepto asociado | Resultado |
| --- | --- | --- |
| leche entera | leche | Relacionado con leche |
| harina de trigo | trigo | Relacionado con enfermedad celíaca |
| harina enriquecida de trigo | trigo | Relacionado con enfermedad celíaca |
| leche de almendras | almendra | Reconocido sin relación con leche |

## Criterio aplicado al catálogo

No se incorpora automáticamente todo término desconocido encontrado durante las pruebas. Para esta versión se priorizaron denominaciones específicas, estables y reutilizables.

Quedaron fuera del catálogo por ser genéricas, ambiguas o poco prioritarias:

- aceite vegetal;
- estabilizante;
- regulador de acidez;
- aroma natural;
- esencia natural;
- esencia natural de vainilla;
- extracto de achicoria.

Su ausencia no implica que sean peligrosas: indica que la base todavía no dispone de un concepto suficientemente preciso o priorizado para resolverlas.

## Validaciones realizadas

- Consolidación del conocimiento con el script `70_consolidate_knowledge.py`.
- Generación de la SQLite con versión `0.10.1`.
- Validación estructural mediante `89_check_sqlite.py`.
- Ejecución satisfactoria del smoke test.
- Test de integración actualizado para contemplar los nuevos conceptos y la versión `0.10.1`.
- Prueba funcional del caso:

  `Agua, leche de almendras, azúcar, carbonato de calcio, sal.`

  Los cinco ingredientes fueron reconocidos, sin coincidencias con los perfiles de leche y enfermedad celíaca.

- Verificación de que `carbonato de calcio` se resuelve exactamente y no se confunde con `caseinato de calcio` en este caso.

## Pendientes fuera de esta iteración

Los siguientes puntos corresponden al procesamiento y al motor de búsqueda de la aplicación. No deben resolverse mediante cambios en SQLite:

- interpretar cuándo `y` separa ingredientes y cuándo forma parte de una denominación;
- definir la prioridad entre coincidencias exactas y aproximadas;
- evitar que una coincidencia aproximada genere una alerta automática incorrecta;
- distinguir una sugerencia de corrección de una coincidencia efectiva;
- permitir la corrección manual del texto obtenido por OCR.

Estos temas deben coordinarse con quienes estén modificando el analizador para evitar cambios incompatibles en paralelo.

## Estado final

La versión `0.10.1` se considera cerrada para el objetivo de sustituir el catálogo JSON por la base SQLite. Las ampliaciones futuras del catálogo y los cambios en las reglas de búsqueda deben realizarse en iteraciones separadas.
