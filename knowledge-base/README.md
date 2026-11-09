# SafeLabel — Generación de la base de conocimiento

Este directorio contiene el procedimiento para generar la SQLite utilizada por SafeLabel.

La versión `0.10.1` contempla relaciones con dos restricciones alimentarias:

- leche;
- enfermedad celíaca / cereales con gluten.

Además, el catálogo puede contener ingredientes conocidos que todavía no están
relacionados con una restricción. Esto permite distinguir tres resultados:

- `MATCHED`: el ingrediente fue reconocido y tiene una relación aplicable con
  una restricción;
- `RECOGNIZED`: el ingrediente fue reconocido, pero no tiene una relación
  cargada con las restricciones disponibles;
- `UNKNOWN`: la denominación no existe en la base.

La base no emite un veredicto sobre la aptitud de un producto.

## Requisitos

- Python 3.
- Bash.
- `pdftotext`, incluido en `poppler-utils`.
- `grep`, utilizado por el smoke test.

Ejecutar los comandos desde la raíz de `knowledge-base`.

## Archivos de configuración principales

- `config/sources.json`: fuentes utilizadas por el pipeline.
- `config/compounds.json`: catálogo autoritativo de conceptos y sus
  denominaciones por idioma. También contiene los ingredientes que deben
  responder como `RECOGNIZED`, aunque no tengan relación con una restricción.
- `config/recognition_terms.json`: expresiones curadas que deben resolverse a
  un concepto existente, por ejemplo `harina enriquecida de trigo` → `trigo`.
- `config/restrictions/*/restriction.json`: definición y términos de extracción
  de cada restricción.

Las relaciones con restricciones se incorporan solamente después de revisar y
aprobar su evidencia. Los términos curados no crean nuevas relaciones: amplían
las denominaciones que permiten encontrar un concepto ya existente.

## Regeneración rápida desde el paso 70

Si el cambio afecta únicamente a `config/compounds.json` o
`config/recognition_terms.json`, y no modifica fuentes ni relaciones aprobadas,
no es necesario repetir la extracción y la revisión. Se puede continuar desde
el [paso 7](#7-consolidar-el-conocimiento).

Si se agregan fuentes, conceptos relacionados o relaciones con restricciones,
hay que ejecutar los pasos anteriores que correspondan para generar y revisar
la nueva evidencia.

## 1. Preparar las fuentes manuales

Descargar desde el navegador y guardar con el nombre indicado:

1. [Directrices para el rotulado de alérgenos — ANMAT](https://www.argentina.gob.ar/sites/default/files/alergenos_directrices_final.pdf)

   ```text
   data/manual/anmat-alergenos.pdf
   ```

2. [Guía para la Gestión de Alérgenos en la Industria — ANMAT](https://www.argentina.gob.ar/sites/default/files/alergenos.pdf)

   ```text
   data/manual/anmat-gestion-alergenos.pdf
   ```

3. [Milk: a priority food allergen — Health Canada](https://www.canada.ca/en/health-canada/services/food-nutrition/reports-publications/food-safety/milk-priority-food-allergen.html)

   ```text
   data/manual/health-canada-milk.html
   ```

4. [Código Alimentario Argentino — artículo 1383 actualizado](https://www.argentina.gob.ar/normativa/nacional/norma-394181/texto)

   Guardar la página como HTML:

   ```text
   data/manual/arg-caa-1383.html
   ```

5. [Guía de Buenas Prácticas para Alimentos Libres de Gluten — ANMAT](https://www.anmat.gob.ar/Alimentos/Guia_BPM_ALG_formato_Web.pdf)

   ```text
   data/manual/anmat-bpm-alg.pdf
   ```

6. [Gluten — Health Canada, versión inglesa](https://www.canada.ca/en/health-canada/services/food-nutrition/reports-publications/food-safety/gluten-pamphlet.html)

   Guardar la página como HTML:

   ```text
   data/manual/health-canada-gluten-en.html
   ```

7. [Gluten — Santé Canada, versión francesa](https://www.canada.ca/fr/sante-canada/services/aliments-nutrition/rapports-publications/salubrite-aliments/gluten-brochure.html)

   Guardar la página como HTML:

   ```text
   data/manual/health-canada-gluten-fr.html
   ```

La definición completa se encuentra en `config/sources.json`. La fuente de FDA se descarga automáticamente.

## 2. Preparar las fuentes

```bash
python3 scripts/10_download.py \
  --sources config/sources.json \
  --raw-dir data/raw
```

Genera las fuentes procesables y `data/raw/manifest.json`.

## 3. Extraer candidatos

Leche:

```bash
python3 scripts/20_extract.py \
  --manifest data/raw/manifest.json \
  --compounds config/compounds.json \
  --restriction config/restrictions/milk/restriction.json \
  --output data/candidates/milk/candidates.json
```

Celiaquía:

```bash
python3 scripts/20_extract.py \
  --manifest data/raw/manifest.json \
  --compounds config/compounds.json \
  --restriction config/restrictions/celiac/restriction.json \
  --output data/candidates/celiac/candidates.json
```

## 4. Preparar la revisión

Leche:

```bash
python3 scripts/30_prepare_review.py \
  --candidates data/candidates/milk/candidates.json \
  --previous-reviewed data/reviewed/milk/reviewed.json \
  --output data/reviewed/milk/review.json
```

Celiaquía:

```bash
python3 scripts/30_prepare_review.py \
  --candidates data/candidates/celiac/candidates.json \
  --previous-reviewed data/reviewed/celiac/reviewed.json \
  --output data/reviewed/celiac/review.json
```

En la primera ejecución de una restricción se omite `--previous-reviewed`.
Cuando existe una revisión anterior, el script conserva las decisiones cuya
restricción, concepto, fuente y evidencia no cambiaron. Las vinculaciones
nuevas o modificadas quedan pendientes.

## 5. Revisar las vinculaciones

Leche:

```bash
python3 scripts/40_review_sources.py \
  --input data/reviewed/milk/review.json \
  --output data/reviewed/milk/reviewed.json \
  --reviewed-by "NOMBRE"
```

Celiaquía:

```bash
python3 scripts/40_review_sources.py \
  --input data/reviewed/celiac/review.json \
  --output data/reviewed/celiac/reviewed.json \
  --reviewed-by "NOMBRE"
```

Opciones:

- `a`: aprobar.
- `r`: rechazar.
- `d`: diferir.
- `s`: guardar y salir.

Si `reviewed.json` existe, el script incorpora el nuevo `review.json` y conserva
las decisiones en curso que correspondan exactamente a evidencias sin cambios.
Solo solicita las vinculaciones pendientes.

## 6. Construir el conocimiento de cada restricción

Leche:

```bash
python3 scripts/60_build_knowledge.py \
  --compounds config/compounds.json \
  --restriction config/restrictions/milk/restriction.json \
  --reviewed data/reviewed/milk/reviewed.json \
  --manual-additions data/reviewed/milk/manual_additions.json \
  --output data/knowledge/milk.json
```

Celiaquía:

```bash
python3 scripts/60_build_knowledge.py \
  --compounds config/compounds.json \
  --restriction config/restrictions/celiac/restriction.json \
  --reviewed data/reviewed/celiac/reviewed.json \
  --manual-additions data/reviewed/celiac/manual_additions.json \
  --output data/knowledge/celiac.json
```

## 7. Consolidar el conocimiento

```bash
python3 scripts/70_consolidate_knowledge.py \
  --catalog config/compounds.json \
  --recognition-terms config/recognition_terms.json \
  --inputs \
    data/knowledge/milk.json \
    data/knowledge/celiac.json \
  --output data/knowledge/knowledge.json
```

Este paso:

- incorpora todos los conceptos de `compounds.json`, incluso los que no tienen
  relación con una restricción y deben responder como `RECOGNIZED`;
- incorpora las expresiones curadas de `recognition_terms.json`;
- agrega las relaciones y evidencias aprobadas de los archivos indicados en
  `--inputs`.

Para construir una versión parcial, indicar solamente los archivos de
restricciones que deban incluirse. El catálogo de conceptos continúa siendo
global.

## 8. Generar SQLite

```bash
python3 scripts/80_build_sqlite.py \
  --knowledge data/knowledge/knowledge.json \
  --output data/output/safelabel.sqlite \
  --version 0.10.1
```

## 9. Validar SQLite

```bash
python3 scripts/89_check_sqlite.py \
  data/output/safelabel.sqlite
```

El resultado correcto finaliza con:

```text
Validación SQLite: OK
```

La validación comprueba el esquema, la integridad de las relaciones, la vista
de consulta y la existencia de conceptos sin restricción que puedan responder
como `RECOGNIZED`.

## 10. Consultar un ingrediente

```bash
python3 scripts/90_query_ingredient.py \
  data/output/safelabel.sqlite \
  "caseinato de sodio"

python3 scripts/90_query_ingredient.py \
  data/output/safelabel.sqlite \
  "carbonato de calcio"

python3 scripts/90_query_ingredient.py \
  data/output/safelabel.sqlite \
  "ingrediente inexistente"
```

Los resultados esperados son, respectivamente, `MATCHED`, `RECOGNIZED` y
`UNKNOWN`. Cuando corresponde, la respuesta incluye todas las restricciones
relacionadas con la denominación consultada.

## 11. Actualizar la base incluida en la aplicación

Después de validar la SQLite, copiarla al asset utilizado por Flutter. Si
`knowledge-base` está en la raíz del repositorio de SafeLabel:

```bash
cp data/output/safelabel.sqlite \
  ../assets/knowledge/safelabel.sqlite
```

Desde la raíz de la aplicación, ejecutar:

```bash
flutter analyze
flutter test
```

Al probar la aplicación, verificar que la pantalla de resultados informe la
versión `0.10.1` de la base de conocimiento.

## Smoke test

El smoke test valida conjuntamente leche y celiaquía mediante fuentes
controladas. También comprueba conceptos `RECOGNIZED`, términos curados y un
ingrediente `UNKNOWN`. No utiliza fuentes oficiales ni modifica datos de
trabajo.

```bash
./tests/run_smoke.sh
```

Una ejecución correcta finaliza con `Smoke test: OK`.

## Archivos versionados

Se versionan scripts, configuraciones, fixtures, pruebas, revisiones aprobadas
e incorporaciones manuales.

No se versionan dentro de `knowledge-base` las fuentes descargadas, los
resultados intermedios, el conocimiento consolidado ni la SQLite generada.

La copia `assets/knowledge/safelabel.sqlite` sí forma parte de la versión de la
aplicación y debe actualizarse cuando se publica una nueva base.

## Alcance funcional actual

De los perfiles de demostración actuales, la base `0.10.1` brinda soporte para:

- Sofía: leche;
- Mateo: enfermedad celíaca / cereales con gluten.

Todavía no contiene relaciones para los perfiles de frutos secos y maní ni de
sulfitos. Tampoco están implementadas las restantes restricciones visibles en
la pantalla de perfiles hasta que se incorporen sus fuentes, revisiones y
relaciones correspondientes.
