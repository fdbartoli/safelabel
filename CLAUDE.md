# SafeLabel — Contexto del proyecto

Aplicación móvil que lee la etiqueta física de un alimento con OCR y señala qué ingredientes chocan con las restricciones alimentarias del usuario, explicando por qué.

Mercado inicial: Argentina. Idioma: español.

---

## 1. Reglas no negociables

Estas reglas existen porque un falso negativo en esta aplicación puede provocar una reacción alérgica grave. Tienen prioridad sobre cualquier otra consideración de diseño o de código. Si una tarea parece requerir violar alguna, detenerse y preguntar.

**1.1. El LLM nunca decide si un ingrediente es un alérgeno.**
La determinación sale siempre de la base de conocimiento local. El LLM solo redacta explicaciones en lenguaje natural a partir de datos ya determinados, y puede proponer candidatos para ingredientes desconocidos marcados explícitamente como tentativos.

**1.2. El LLM nunca recibe la imagen de la etiqueta.**
Quien lee la imagen es el OCR en el dispositivo. El LLM solo recibe texto.

**1.3. "No encontrado" nunca significa "seguro".**
Si un ingrediente no está en la base, se muestra como no reconocido. Jamás se omite del resultado ni se interpreta como ausencia de alérgeno.

**1.4. La aplicación no emite veredicto de aptitud.**
Prohibido: "apto", "seguro", "podés consumirlo", semáforos verdes, tildes de aprobación. La app muestra hallazgos y deja la decisión en la persona.

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
      ↓ importación
lista cruda de términos
      ↓ el LLM propone: término → origen → explicación
      ↓ revisión humana (obligatoria)
base de conocimiento validada y versionada
      ↓ export comprimido
se empaqueta con la app (SQLite)
```

Aquí el LLM es una herramienta de autoría, no de runtime. Se ejecuta en scripts, no en la app.

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
10. Registro local de desconocidos y correcciones → sincronización
```

Debe funcionar completo sin conexión. El supermercado es el lugar de uso y el lugar con peor señal.

---

## 3. Stack

| Capa | Elección | Notas |
|---|---|---|
| App | Flutter | La app oficial de Open Food Facts es Flutter y publican SDK en Dart |
| OCR | `google_mlkit_text_recognition` | Apple Vision en iOS, ML Kit en Android, todo en dispositivo |
| Código de barras | `mobile_scanner` | Solo como atajo, nunca como única vía |
| Base local | SQLite (`drift`) | Mirror versionado de la base de conocimiento |
| Base servidor | PostgreSQL | `pg_trgm` para similitud, `unaccent`, CTEs recursivas para la taxonomía |
| Backend / auth | Supabase | Row Level Security resuelve los perfiles compartidos en solo lectura |
| Scripts de Flujo A | Python | Importación, normalización, llamadas al LLM en batch |

No usar Tesseract: rinde mal con tipografías estilizadas, que abundan en etiquetas.
No usar Neo4j: la taxonomía es un DAG y Postgres la resuelve con CTEs recursivas.

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

### Perfiles y compartición

```
user
profile                   -- id, owner_user_id, display_name
profile_restriction       -- profile_id, allergen_group_id, severity
profile_share             -- profile_id, share_code, permission='read_only', expires_at
```

`severity` importa: un perfil con anafilaxia debe recibir advertencias más firmes ante ingredientes desconocidos que un perfil de intolerancia leve.

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

**Etapa 2 — la base de conocimiento.** Scripts de Flujo A: importación de Open Food Facts, codificación del Art. 235 séptimo, tabla INS, generación asistida por LLM, revisión. Postgres con `pg_trgm`. Export a SQLite.

**Etapa 3 — perfiles y compartición.** Supabase, auth, RLS, códigos de compartición, modo anfitrión con múltiples perfiles simultáneos.

**Etapa 4 — el bucle de mejora.** Cola de desconocidos, sincronización, correcciones de usuario, priorización por frecuencia.

**Etapa 5 — pulido.** Código de barras como atajo, historial, alertas por reformulación, versión para nutricionistas.

---

## 8. Antipatrones — no hacer esto

- Mandar la foto a un LLM multimodal y pedirle el análisis completo. Rápido de programar, imposible de testear, sin producto propio.
- Consultar una API externa en cada escaneo. Rompe el uso offline, que es el caso principal.
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

Ante una decisión ambigua, priorizar lo que ellos no pueden hacer: leer la etiqueta física, funcionar con productos regionales, y compartir el perfil sin ceder la cuenta.

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
