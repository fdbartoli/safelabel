# SafeLabel

Lee la etiqueta física de un alimento con OCR y señala qué ingredientes chocan
con las restricciones alimentarias del perfil activo, explicando por qué.

Mercado inicial: Argentina · idioma: español. El contexto completo del proyecto
y las reglas no negociables están en [`CLAUDE.md`](CLAUDE.md).

## Estado: Etapa 1 — validar el OCR

Objetivo de esta etapa: comprobar que el OCR sirve sobre etiquetas argentinas
reales. Sin backend ni base de datos; la base de conocimiento es un JSON local.

Implementado:

| Paso del Flujo B | Módulo |
|---|---|
| 1. Guía de captura | `lib/ocr/guia_captura.dart` |
| 2. OCR en dispositivo | `lib/ocr/servicio_ocr_mlkit.dart` (ML Kit / Vision) |
| 3. Triage de confianza | `lib/ocr/triage_confianza.dart` |
| 4. Normalización | `lib/pipeline/normalizador.dart` |
| 5. Match exacto → difuso → desconocido | `lib/pipeline/matcher.dart`, `similitud.dart` |
| 6. Verificación cruzada con "CONTIENE" | `lib/pipeline/verificacion_cruzada.dart` |
| 7–8. Cruce con perfiles y resultado en 3 bloques | `lib/pipeline/analizador.dart`, `lib/modelo/resultado_analisis.dart` |

Datos: [`lib/datos/ingredientes.json`](lib/datos/ingredientes.json) — ~78
términos que cubren los 9 grupos del Art. 235 séptimo, más las excepciones del
CAA (maltodextrina / jarabe de glucosa). **Cada entrada tiene `fuente`.**

> ⚠️ El dataset de la Etapa 1 **no** es la base de conocimiento validada del
> proyecto. Ninguna entrada pasó por revisión humana (regla 1.6). No usar para
> decisiones reales.

### Convención de dominio

Identificadores de código en **español** (`ingrediente`, `alergeno`, `perfil`,
`normalizar`, `Emparejador`). Decidido en el primer commit, no se mezcla
(sección 11 del CLAUDE.md).

## Correr

Usá `dev.ps1` como punto de entrada: detecta Flutter desde el `PATH` o desde
`FLUTTER_PATH` y, al ejecutar `run` o `build`, pasa `gemini.env` completo a
Flutter con `--dart-define-from-file`. Así `GEMINI_API_KEY` y, si está,
`GEMINI_MODEL` llegan a Chrome y Android sin cargar variables a mano.

```powershell
.\dev.ps1 run          # elegí Chrome o un dispositivo Android
.\dev.ps1 test         # pipeline determinista: normalización, matcher, cruce, 3 bloques
.\dev.ps1 analyze
```

Para elegir Chrome directamente o compilar un APK:

```powershell
.\dev.ps1 run -d chrome
.\dev.ps1 build apk --debug
```

Si Flutter no está en el `PATH`, definí `FLUTTER_PATH` apuntando a su carpeta
`bin`. Si PowerShell bloquea el script:

```powershell
powershell -ExecutionPolicy Bypass -File .\dev.ps1 run
```

No uses `flutter run` directamente si necesitás las sugerencias de Gemini: ese
comando no lee `gemini.env`. En CI se pueden seguir usando los comandos
`flutter` directamente.

Sin cámara: en la app, "Analizar texto pegado" corre el mismo pipeline sobre
texto escrito a mano (útil para las fixtures de la Etapa 1).

### Sugerencias de sustitutos (Gemini)

Las sugerencias por IA necesitan una API Key de Google Gemini. La guía paso a
paso —cómo generarla, qué archivo crear y qué formato usar— está en
[`GEMINI_API_KEY.md`](GEMINI_API_KEY.md). En resumen: creá `gemini.env` en la
raíz con `GEMINI_API_KEY=ponetuclaveaqui` (tu clave real) y ejecutá
`.\dev.ps1 run`. Si querés fijar el modelo, agregá `GEMINI_MODEL=...` en el
mismo archivo.

`gemini.env` es local y está excluido de Git. Si ya tenés `GEMINI_API_KEY` o
`GEMINI_MODEL` en el entorno, conservan prioridad sobre el archivo por
compatibilidad; no hace falta definirlas para usar `dev.ps1`.

## Pendiente en esta etapa

- Fixtures de fotos reales (envase curvo, texto blanco sobre foto, letra chica,
  tres idiomas) con su texto esperado.
- Guía de captura en vivo sobre el frame de cámara (hoy se evalúa sobre la
  salida del OCR).
- Confianza por línea real en Android (ML Kit suele devolver `null`).
- Ampliar y **revisar** el dataset hacia ~200 términos.
