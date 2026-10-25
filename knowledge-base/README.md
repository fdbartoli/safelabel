# SafeLabel — Generación de la base de conocimiento

Este directorio contiene el procedimiento para generar la SQLite utilizada por SafeLabel. La versión actual contempla leche y enfermedad celíaca.

## Requisitos

- Python 3.
- Bash.
- `pdftotext`, incluido en `poppler-utils`.
- `grep`, utilizado por el smoke test.

Ejecutar los comandos desde la raíz de `knowledge-base`.

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
  --output data/reviewed/milk/review.json
```

Celiaquía:

```bash
python3 scripts/30_prepare_review.py \
  --candidates data/candidates/celiac/candidates.json \
  --output data/reviewed/celiac/review.json
```

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

Si `reviewed.json` existe, el script continúa esa revisión. Actualmente no incorpora automáticamente cambios provenientes de un nuevo `review.json`.

Para rehacer una revisión después de modificar fuentes, conceptos o relaciones, primero debe conservarse mediante control de versiones la revisión existente y retirarse el `reviewed.json` anterior. En la siguiente ejecución, el script creará uno nuevo a partir de `review.json`.

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

## 7. Consolidar las restricciones

```bash
python3 scripts/70_consolidate_knowledge.py \
  --inputs \
    data/knowledge/milk.json \
    data/knowledge/celiac.json \
  --output data/knowledge/knowledge.json
```

Para construir una versión parcial, indicar solamente los archivos que deban incluirse.

## 8. Generar SQLite

```bash
python3 scripts/80_build_sqlite.py \
  --knowledge data/knowledge/knowledge.json \
  --output data/output/safelabel.sqlite \
  --version 0.7.0
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

## 10. Consultar un ingrediente

```bash
python3 scripts/90_query_ingredient.py \
  data/output/safelabel.sqlite \
  "trigo"
```

La respuesta incluye todas las restricciones relacionadas con la denominación consultada.

## Smoke test

El smoke test valida conjuntamente leche y celiaquía mediante fuentes controladas. No utiliza fuentes oficiales ni modifica datos de trabajo.

```bash
./tests/run_smoke.sh
```

Una ejecución correcta finaliza con `Smoke test: OK`.

## Archivos versionados

Se versionan scripts, configuraciones, fixtures, pruebas, revisiones aprobadas e incorporaciones manuales.

No se versionan las fuentes descargadas, los resultados intermedios, el conocimiento consolidado ni la SQLite generada.
