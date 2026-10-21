# SafeLabel — Contexto del proyecto

Aplicación móvil que lee la etiqueta física de un alimento con OCR y señala qué ingredientes chocan con las restricciones alimentarias del usuario, explicando por qué.

Mercado inicial: Argentina. Idioma: español.

---

## 1. Reglas no negociables

Estas reglas existen porque un falso negativo en esta aplicación puede provocar una reacción alérgica grave. Tienen prioridad sobre cualquier otra consideración de diseño o de código. Si una tarea parece requerir violar alguna, detenerse y preguntar.

**1.1. El LLM nunca decide si un ingrediente es un alérgeno.**
La determinación sale siempre de la base de conocimiento local. El LLM solo redacta explicaciones en lenguaje natural a partir de datos ya determinados, y puede proponer candidatos para ingredientes desconocidos marcados explícitamente como tentativos.

*Excepción (requisito del proyecto, 2026-10-09): sugerencias de reemplazo.* Cuando el análisis encuentra coincidencias con un perfil activo, un LLM puede sugerir alimentos de reemplazo. Condiciones, ver sección 5.6.

**1.2. El LLM nunca recibe la imagen de la etiqueta.**
Quien lee la imagen es el OCR en el dispositivo. El LLM solo recibe texto.

**1.3. "No encontrado" nunca significa "seguro".**
Si un ingrediente no está en la base, se muestra como no reconocido. Jamás se omite del resultado ni se interpreta como ausencia de alérgeno.

**1.4. La aplicación no emite veredicto de aptitud.**
Prohibido: "apto", "seguro", "podés consumirlo", semáforos verdes, tildes de aprobación. La app muestra hallazgos y deja la decisión en la persona.

Las sugerencias de reemplazo (sección 5.6) están permitidas, presentadas como ideas para buscar, nunca como alimentos aptos. Se disparan por "hay coincidencias con el perfil", no por "el alimento no es válido".

**1.5. Toda lectura parcial se declara.**
Si el OCR no leyó una porción de la etiqueta con confianza suficiente, el resultado lo informa e indica qué parte falló.

**1.6. Nada entra a la base de conocimiento sin revisión humana.**
Ni sugerencias del LLM, ni correcciones de usuarios, ni importaciones automáticas de fuentes externas. Todo pasa por una cola de revisión.

**1.7. Las "trazas" se reportan, no se interpretan.**
La leyenda "PUEDE CONTENER" es voluntaria y no está estandarizada. Se muestra textual, con una explicación de qué significa, sin convertirla en juicio de aptitud.

---

## 2. Arquitectura general

Dos flujos separados. No confundirlos.

### Flujo A — construcción de la base de conocimiento (offline, una vez, se repite periódicamente)

```
Fuentes abiertas
  · taxonomía de ingredientes de Open Food Facts (~80k líneas, multilingüe, ODbL)
  · Art. 235 séptimo del Código Alimentario Argentino + directrices de ANMAT
  · tabla INS de aditivos (Codex)
      ↓ importación (scripts Python)
lista cruda de términos
      ↓ el LLM propone: término → origen → explicación
      ↓ revisión humana (obligatoria)
base de conocimiento validada y versionada — JSON/CSV curado, versionado en git
      ↓ script de compilación
se empaqueta con la app (SQLite)
```

Aquí el LLM es una herramienta de autoría, no de runtime. Se ejecuta en scripts, no en la app. Única excepción: las sugerencias de reemplazo de la sección 5.6, que sí llaman a un LLM desde la app.

**Sin backend.** No hay servidor propio ni Postgres ni Supabase: la base validada vive
como archivo curado en el repositorio (el mismo git es el "versionado"), y un script la
compila directo a SQLite para embeber en la app. Decisión explícita para simplificar el
proyecto — no hace falta una base maestra con auditoría server-side (2026-09-16).

### Flujo B — análisis de una etiqueta (en el dispositivo, cada escaneo)

```
1. Cámara con guía activa de captura
2. OCR en el dispositivo → texto + bounding boxes + confidence por línea
3. Triage de confianza
     baja  → "no pude leer esta parte", pedir nueva foto
     alta  → continuar
4. Normalización del texto
5. Match contra la base local (exacto → difuso → desconocido)
6. Lectura de la línea "CONTIENE / PUEDE CONTENER" (verificación cruzada)
7. Cruce con los perfiles activos
8. Resultado en tres bloques
9. Explicación en lenguaje claro (texto pregenerado o cacheado)
10. Registro local de desconocidos y correcciones — queda en el dispositivo; sin
    backend no hay sincronización automática entre usuarios, se revisa a mano y se
    incorpora a la base en un próximo release de la app
11. Si hay coincidencias: botón "Sugerir sustitutos"; al tocarlo, sugerencias por LLM (sección 5.6)
```

Debe funcionar completo sin conexión. El supermercado es el lugar de uso y el lugar con peor señal. El paso 11 es la única parte que necesita internet: sin conexión no aparece, y nada de los pasos 1–10 depende de él.

---

## 3. Stack

| Capa | Elección | Notas |
|---|---|---|
| App | Flutter | La app oficial de Open Food Facts es Flutter y publican SDK en Dart |
| OCR | `google_mlkit_text_recognition` | Apple Vision en iOS, ML Kit en Android, todo en dispositivo |
| Código de barras | `mobile_scanner` | Solo como atajo, nunca como única vía |
| Base local | SQLite (`drift`) | Única base de conocimiento; se compila desde el archivo curado y se empaqueta con la app |
| Sugerencias de reemplazo | Google Gemini (plan gratuito) vía API | Solo texto, solo con conexión (sección 5.6) |
| Scripts de Flujo A | Python | Importación, normalización (`unidecode`), similitud difusa (`rapidfuzz`) para dedupe, llamadas al LLM en batch, compilación a SQLite |

Sin backend: no hay servidor propio, ni Postgres, ni Supabase. Perfiles y base de
conocimiento son enteramente locales (ver sección 2). `rapidfuzz` + `unidecode` en los
scripts de Flujo A cumplen en Python el rol que `pg_trgm`/`unaccent` cumplían en Postgres.

No usar Tesseract: rinde mal con tipografías estilizadas, que abundan en etiquetas.
No usar Neo4j: la taxonomía es un DAG y SQLite la resuelve con CTEs recursivas (`WITH RECURSIVE`).

---

## 4. Modelo de datos

### Base de conocimiento

```
ingredient
  id
  canonical_name          -- "caseinato de sodio"
  normalized_name         -- "caseinato de sodio" sin acentos, minúsculas
  origin_id               -- FK → allergen_group
  certainty               -- 'certain' | 'possible' | 'depends_on_source'
  explanation             -- texto pregenerado en lenguaje claro
  source_ref              -- de dónde salió (OFF, CAA art. 235, curado manual)
  reviewed_by
  reviewed_at
  version

ingredient_synonym
  id
  ingredient_id           -- FK
  synonym                 -- "caseinato sódico", "sodium caseinate", "INS 469"
  normalized_synonym
  locale                  -- 'es-AR', 'en', ...
  kind                    -- 'commercial' | 'technical' | 'ocr_variant'

allergen_group
  id
  name                    -- "leche", "trigo", "maní"
  caa_mandatory           -- bool: está en el Art. 235 séptimo
  label_wording            -- cómo aparece en la etiqueta argentina

exemption
  id
  ingredient_id
  allergen_group_id
  rule                    -- "jarabe de glucosa derivado de trigo, exento por CAA 235 séptimo"
  source_ref
```

### Perfiles

Enteramente locales: sin cuentas, sin servidor. Viven en el SQLite del dispositivo.

```
profile                   -- id, display_name
profile_restriction       -- profile_id, allergen_group_id, severity
```

`severity` importa: un perfil con anafilaxia debe recibir advertencias más firmes ante ingredientes desconocidos que un perfil de intolerancia leve.

Sin compartir entre dispositivos por ahora (decisión 2026-09-16: se prioriza simplicidad
sobre ese diferencial). El "modo anfitrión" de la Etapa 3 es varios perfiles activos **en
el mismo dispositivo** a la vez, no sincronización entre celulares.

### Cola de desconocidos

```
unknown_term
  id
  raw_text                -- lo que leyó el OCR
  normalized_text
  occurrence_count
  first_seen_at
  sample_product_refs
  llm_suggestion          -- propuesta tentativa, NO autoritativa
  status                  -- 'pending' | 'resolved' | 'rejected' | 'not_an_ingredient'
```

Esta tabla es el motor de mejora del producto: prioriza qué ampliar según lo que realmente aparece en las góndolas locales.

---

## 5. Detalles críticos del pipeline

### 5.1. Los tres estados (paso 3 y 5)

Nunca colapsar a dos. El código debe distinguir:

- `UNREADABLE` — el OCR no leyó con confianza. Otra foto puede resolverlo.
- `UNKNOWN` — se leyó claro pero la base no lo tiene. Otra foto no cambia nada.
- `MATCHED` — caso normal.

Ambos primeros devuelven vacío desde la consulta, pero requieren respuestas opuestas al usuario. La similitud difusa ayuda a decidir: si el texto se parece mucho a algo de la base, probablemente sea error de OCR; si no se parece a nada, es un término desconocido real.

### 5.2. Normalización (paso 4)

- minúsculas, quitar acentos
- separar por comas, punto y coma, y saltos de línea
- resolver anidados: `chocolate (leche, lecitina de soja)` produce tres ítems, con el padre registrado
- detectar números INS y mapearlos
- descartar el bloque de tabla nutricional si aparece en la captura

### 5.3. Verificación cruzada con la línea de alérgenos (paso 6)

El Art. 235 séptimo obliga a declarar los alérgenos después de la lista de ingredientes con la fórmula `CONTIENE + alérgeno` o `CONTIENE DERIVADOS DE + alérgeno`. En etiquetas argentinas se declara "trigo, avena, cebada y/o centeno", **no "gluten"**. Buscar la palabra "gluten" es un error.

Esto da una segunda señal independiente. Tres cruces a implementar:

| Análisis de ingredientes | Línea CONTIENE | Acción |
|---|---|---|
| desconocido | declara alérgeno | usar la declaración; el hueco de la base queda cubierto |
| sin hallazgos | declara alérgeno | señal fuerte de hueco en la base → prioridad alta en la cola |
| detecta alérgeno | no lo declara | mostrar con aclaración: posible error de OCR, o excepción del CAA, o incumplimiento |

### 5.4. Excepciones del CAA a modelar explícitamente

Están exentos de la declaración de cereales con gluten:
- jarabes de glucosa derivados de trigo o cebada, incluida la dextrosa
- maltodextrinas derivadas de trigo o cebada
- cereales usados para destilados o alcohol etílico de origen agrícola para bebidas alcohólicas

Un LLM genérico marca "maltodextrina" como gluten porque estadísticamente suena bien. La base debe tener la excepción como regla.

### 5.5. Formato del resultado (paso 8)

Tres bloques, siempre, en este orden:

1. **Coincidencias con el perfil** — ingrediente, origen, por qué se señala, y a qué perfil afecta si hay varios activos
2. **No reconocidos** — visibles, nunca ocultos, con conteo ("11 de 12 ingredientes analizados")
3. **No legibles** — qué línea falló y sugerencia de recaptura

Sin bloque de "apto". Sin resumen verde.

### 5.6. Sugerencias de reemplazo por LLM (requisito agregado 2026-10-09)

Cuando el bloque 1 tiene coincidencias, dentro de ese bloque, debajo de las coincidencias, aparece el botón "Sugerir sustitutos" (en el verde pastel de la marca: es una acción, no un hallazgo). El LLM se llama recién cuando la persona lo toca. Es la excepción a las reglas 1.1 y 1.4 y a la sección 2, con estas condiciones:

- Al LLM se le manda solo texto: los grupos de alérgenos de los perfiles activos, los ingredientes que chocaron y la lista de ingredientes leída (para que infiera el tipo de producto). Nunca la imagen (la regla 1.2 sigue igual).
- Implementación: `lib/sugerencias/` (servicio, filtro, gestor) y `lib/ui/seccion_reemplazos.dart`. Proveedor: Google Gemini, plan gratuito (decisión 2026-10-10), modelo `gemini-3.8-flash` vía `generateContent` por HTTP directo, salida JSON con esquema. La clave se inyecta en la compilación con `--dart-define=GEMINI_API_KEY` (lo hace `dev.ps1` desde la variable de entorno; el modelo se puede cambiar con `GEMINI_MODEL`). Se puede extraer de un APK: aceptable para la demo, no para producción. En el plan gratuito Google puede usar lo enviado para mejorar sus productos: solo viajan ingredientes y grupos de alérgenos, nunca datos personales ni la foto.
- La respuesta son categorías genéricas ("bebida de avena"), no marcas: la base no puede verificar los ingredientes de una marca.
- Filtro determinista: cada sugerencia pasa por el matcher local y se descarta si choca con alguna restricción de un perfil activo.
- Se muestran en el bloque 1, debajo de las coincidencias, como sustitutos para buscar, con el aviso "escaneá la etiqueta del sustituto antes de consumirlo". Nunca como apto. Las tarjetas de hallazgos no llevan verde.
- Sin conexión o si la llamada falla, se avisa y se puede reintentar; si la conexión con el LLM no está configurada, el botón lo avisa. El resultado en tres bloques nunca espera al LLM.
- Las sugerencias no entran a la base de conocimiento (regla 1.6 sigue igual).
- La clave de la API no se commitea al repositorio.

---

## 6. Guía de captura (paso 1)

La calidad de la foto determina todo lo demás. Implementar guía activa, en positivo (hacia dónde ir, no dónde está el problema):

- "acercate un poco más"
- "girá el envase a la derecha" cuando el texto se corta en superficie curva
- "hay reflejo, movete un poco"
- detección de encuadre incompleto de la lista de ingredientes

---

## 7. Etapas de desarrollo

**Etapa 1 — validar el OCR.** Tabla de ~200 ingredientes en un JSON local, sin backend ni base de datos. Cámara, OCR, normalización, match exacto y difuso, resultado en tres bloques. Objetivo: comprobar que el OCR sirve sobre etiquetas argentinas reales.

**Etapa 2 — la base de conocimiento.** Scripts de Flujo A en Python: importación de Open Food Facts, codificación del Art. 235 séptimo, tabla INS, generación asistida por LLM, revisión humana sobre el archivo curado en el repo (sin Postgres). Script de compilación a SQLite (`drift`) para reemplazar el JSON de la Etapa 1.

**Etapa 3 — perfiles locales.** Múltiples perfiles en el mismo dispositivo (SQLite), modo anfitrión para elegir cuáles están activos en un escaneo. Sin cuentas ni backend; sin compartir entre dispositivos por ahora.

**Etapa 4 — el bucle de mejora.** Cola de desconocidos y correcciones de usuario, local en el dispositivo. Sin sincronización automática entre usuarios (no hay backend): se revisan a mano y se incorporan a la base curada para el próximo release. Priorización por frecuencia de aparición.

**Etapa 5 — pulido.** Código de barras como atajo, historial, alertas por reformulación, versión para nutricionistas.

**Requisito agregado (2026-10-09) — sugerencias de reemplazo por LLM.** Fuera del orden de etapas; condiciones en la sección 5.6.

---

## 8. Antipatrones — no hacer esto

- Mandar la foto a un LLM multimodal y pedirle el análisis completo. Rápido de programar, imposible de testear, sin producto propio.
- Consultar una API externa en cada escaneo. Rompe el uso offline, que es el caso principal. (Excepción: la llamada de reemplazos de la sección 5.6, solo con coincidencias y conexión, y sin bloquear el resultado.)
- Colapsar `UNREADABLE` y `UNKNOWN` en un solo caso vacío.
- Buscar la palabra "gluten" en etiquetas argentinas.
- Match exacto por igualdad de strings. El OCR devuelve "caselnato de sodlo".
- Un símbolo o color que comunique aprobación.
- Escribir sugerencias del LLM directamente en la base de conocimiento.
- Cachear resultados de análisis por código de barras sin fecha de vigencia: las formulaciones cambian.
- Depender del código de barras como única vía de entrada. Es la limitación de todos los competidores.

---

## 9. Contexto competitivo

Diferenciales del proyecto, útiles para resolver dudas de diseño:

- **Fig** — código de barras únicamente, ~300.000 productos, solo Estados Unidos, hasta 5 perfiles, y compartir un perfil exige entregar usuario y contraseña con la suscripción activa en un solo dispositivo a la vez.
- **Yuka** — código de barras únicamente, sin OCR (su centro de ayuda confirma que un producto sin código no puede escanearse), catálogo de origen europeo, orientada a calidad nutricional más que a restricciones.
- **Spoonful** — nicho FODMAP y sin gluten, un perfil, código de barras.

Ante una decisión ambigua, priorizar lo que ellos no pueden hacer: leer la etiqueta física, funcionar con productos regionales, y varios perfiles en un mismo dispositivo sin necesidad de crear una cuenta. (Compartir un perfil entre dispositivos quedó fuera de alcance — sección 7, Etapa 3 — a cambio de no depender de ningún backend.)

---

## 10. Notas legales y de licencia

- La taxonomía de Open Food Facts es ODbL: exige atribución y compartir derivados de la base bajo la misma licencia. Revisar antes de cualquier plan comercial.
- Posicionamiento explícito de la app como herramienta informativa. No reemplaza la etiqueta oficial ni la indicación de un profesional de la salud. Esto debe figurar en la interfaz, no solo en los términos de uso.
- Identificación errónea de alérgenos implica responsabilidad. Registrar versión de la base de conocimiento usada en cada análisis, para trazabilidad.

---

## 11. Convenciones de código

- Todo el dominio en español (`ingrediente`, `alergeno`, `perfil`) o todo en inglés, sin mezclar. Elegir en el primer commit y respetarlo.
- Tests obligatorios para el pipeline de normalización y para el matcher: son deterministas, así que se testean con casos fijos de entrada y salida esperada.
- Fixtures de etiquetas reales (fotos y su texto esperado) en el repositorio, con casos difíciles: envase curvo, texto blanco sobre foto, letra chica, tres idiomas.
- Cada regla de la base de conocimiento debe poder rastrearse a su fuente. Sin `source_ref`, no entra.
