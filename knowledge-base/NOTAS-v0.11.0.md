# Actualización propuesta de conocimiento 0.11.0

## Incorporaciones

- Leche: manteca, queso, yogur y crema de leche.
- Enfermedad celíaca: malta, extracto de malta y cuscús.
- Alias en español, inglés, francés y portugués cuando la equivalencia es inequívoca.

## Decisiones conservadoras

- No se incorpora `cerveza`: puede existir cerveza certificada sin gluten y el modelo actual no representa esa condición.
- No se incorpora `cuscuz` como alias portugués de cuscús: en Brasil también denomina preparaciones de maíz.
- Los términos se incorporan como conceptos relacionados con la restricción; no como reglas de reconocimiento textual.

## Nuevas fuentes manuales

Descargar y guardar antes de ejecutar el pipeline:

1. `https://inspection.canada.ca/en/food-labels/labelling/industry/food-allergen-labelling`
   en `data/manual/cfia-food-allergen-labelling.html`.
2. `https://www.argentina.gob.ar/sites/default/files/capitulo_xiii_beb_fermentadasactualiz_2025-04.pdf`
   en `data/manual/arg-caa-capitulo-xiii.pdf`.

Luego debe ejecutarse el pipeline normal, revisar las nuevas vinculaciones pendientes y recién entonces generar la SQLite.
