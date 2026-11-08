# Etiquetas sintéticas para pruebas rápidas

Este directorio contiene imágenes generadas específicamente para SafeLabel.
No representan productos reales y pueden versionarse en el repositorio sin
depender de imágenes externas.

## Alcance

- Validar rápidamente la captura y extracción OCR durante el desarrollo.
- Comparar el texto extraído con los resultados esperados de la base local.
- Conservar casos positivos, negativos y pendientes conocidos.
- No se usan como certificación de precisión del OCR ni como prueba clínica.

Las expectativas corresponden a la base de conocimiento `0.9.0`. El archivo
`expected.json` diferencia el resultado del ingrediente de lo declarado en la
línea `CONTIENE`.

## Casos incluidos

| Archivo | Objetivo principal |
| --- | --- |
| `01_leche_directa.jpg` | Relación directa con `RES-MILK`. |
| `02_caseinato_sodio.jpg` | Derivado relacionado con `RES-MILK`. |
| `03_trigo_directo.jpg` | Relación con `RES-CELIAC`. |
| `04_harina_trigo.jpg` | Caso pendiente de regla composicional. |
| `05_leche_almendras.jpg` | Evitar un falso positivo por la palabra “leche”. |
| `06_sal_azucar.jpg` | Conceptos reconocidos sin relación registrada. |
| `07_desconocido.jpg` | Ingrediente ausente del catálogo actual. |

## Uso

Estas imágenes están pensadas como fixtures de desarrollo. Pueden abrirse en
otra pantalla para probar la cámara o utilizarse como entrada de pruebas del
servicio OCR. No deben establecerse umbrales estrictos de OCR en CI, porque el
resultado puede variar según plataforma y versión del motor.

Para agregar un caso:

1. Incorporar una imagen con un nombre descriptivo.
2. Agregar su expectativa a `expected.json`.
3. Indicar si representa el comportamiento actual o un caso pendiente.
4. Evitar afirmar aptitud o seguridad general del producto.

