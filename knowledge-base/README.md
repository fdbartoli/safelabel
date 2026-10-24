# SafeLabel — Generación de la base de conocimiento

Este directorio contiene el procedimiento utilizado para generar la base SQLite consumida por SafeLabel. La versión actual contempla la restricción alimentaria por leche y sus derivados.

## Requisitos

- Python 3.
- Bash.
- `pdftotext`, incluido en el paquete `poppler-utils`.
- `grep`, utilizado por el smoke test.

Los comandos deben ejecutarse desde la raíz de `knowledge-base`.

## 1. Preparar las fuentes manuales

La definición completa de las fuentes se encuentra en `config/sources.json`.

Antes de ejecutar el pipeline, descargar estas fuentes desde el navegador y guardarlas con el nombre y ubicación indicados:

1. [Directrices para el rotulado de alérgenos — ANMAT](https://www.argentina.gob.ar/sites/default/files/alergenos_directrices_final.pdf)

   Guardar como:

   ```text
   data/manual/anmat-alergenos.pdf
   ```

2. [Guía para la Gestión de Alérgenos en la Industria — ANMAT](https://www.argentina.gob.ar/sites/default/files/alergenos.pdf)

   Guardar como:

   ```text
   data/manual/anmat-gestion-alergenos.pdf
   ```

3. [Milk: a priority food allergen — Health Canada](https://www.canada.ca/en/health-canada/services/food-nutrition/reports-publications/food-safety/milk-priority-food-allergen.html)

   Guardar la página como archivo HTML con el nombre:

   ```text
   data/manual/health-canada-milk.html
   ```

La fuente de FDA se descarga automáticamente durante el paso siguiente.

## 2. Preparar las fuentes

```bash
python3 scripts/10_download.py \
  --sources config/sources.json \
  --raw-dir data/raw
```

El comando copia las fuentes manuales, descarga las fuentes remotas y genera `data/raw/manifest.json` con sus datos de trazabilidad.

## 3. Extraer candidatos

```bash
python3 scripts/20_extract.py \
  --manifest data/raw/manifest.json \
  --compounds config/compounds.json \
  --output data/candidates/candidates.json
```

Genera las apariciones encontradas en las fuentes según los conceptos y denominaciones definidos en `config/compounds.json`.

## 4. Preparar la revisión

```bash
python3 scripts/30_prepare_review.py \
  --candidates data/candidates/candidates.json \
  --output data/reviewed/review.json
```

Agrupa los candidatos por concepto y fuente para su revisión.

## 5. Revisar las vinculaciones

```bash
python3 scripts/40_review_sources.py \
  --input data/reviewed/review.json \
  --output data/reviewed/reviewed.json \
  --reviewed-by "NOMBRE"
```

Opciones disponibles durante la revisión:

- `a`: aprobar.
- `r`: rechazar.
- `d`: diferir.
- `s`: guardar y salir.

Si `data/reviewed/reviewed.json` existe, el script continúa esa revisión. Actualmente no incorpora automáticamente cambios provenientes de un nuevo `review.json`. Para iniciar una revisión completa después de modificar fuentes o conceptos, versionar primero el archivo existente y eliminarlo antes de ejecutar el comando.

## 6. Consolidar el conocimiento

Las incorporaciones que no surgen de la extracción automática se registran en `data/reviewed/manual_additions.json`.

```bash
python3 scripts/60_build_knowledge.py \
  --compounds config/compounds.json \
  --reviewed data/reviewed/reviewed.json \
  --manual-additions data/reviewed/manual_additions.json \
  --output data/reviewed/knowledge.json \
  --restriction-id RES-MILK \
  --restriction-name Leche \
  --target-concept-id CMP-MILK
```

Genera `data/reviewed/knowledge.json`.

## 7. Generar SQLite

```bash
python3 scripts/80_build_sqlite.py \
  --knowledge data/reviewed/knowledge.json \
  --output data/output/safelabel.sqlite \
  --version 0.6.0
```

Genera `data/output/safelabel.sqlite`. Si existe una base en esa ubicación, el script la reemplaza.

## 8. Validar SQLite

```bash
python3 scripts/89_check_sqlite.py \
  data/output/safelabel.sqlite
```

Una ejecución correcta finaliza con:

```text
Validación SQLite: OK
```

## 9. Consultar un ingrediente

```bash
python3 scripts/90_query_ingredient.py \
  data/output/safelabel.sqlite \
  "caseinato de sodio"
```

La respuesta indica si se encontró una coincidencia y, cuando corresponde, el concepto y la restricción relacionados.

## Smoke test

El smoke test utiliza una fuente controlada incluida en `fixtures/`. No requiere descargar las fuentes oficiales y no modifica los datos de trabajo.

```bash
./tests/run_smoke.sh
```

Una ejecución correcta finaliza con:

```text
Smoke test: OK
```

## Archivos versionados

Se versionan los scripts, configuraciones, fixtures, pruebas, `data/reviewed/reviewed.json` y `data/reviewed/manual_additions.json`.

Las fuentes originales, los resultados intermedios, `knowledge.json` y la SQLite generada no se versionan en este repositorio.
