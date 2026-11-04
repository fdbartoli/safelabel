# Configurar la API Key de Gemini

SafeLabel usa Gemini **solo** para sugerir alimentos sustitutos cuando el
análisis encuentra coincidencias con un perfil activo (CLAUDE.md, sección 5.6).
Sin la clave configurada, el resto de la app funciona igual; únicamente el botón
"Sugerir sustitutos" avisa que la función no está configurada.

La clave se inyecta en la compilación mediante `--dart-define` y **nunca** se
commitea al repositorio.

---

## Resumen rápido (lo esencial)

1. Generá tu clave en [Google AI Studio](https://aistudio.google.com/apikey).
2. En la **raíz del proyecto**, creá un archivo llamado exactamente
   **`gemini.env`** (extensión `.env`).
3. Ese archivo tiene que contener **una sola línea**:

   ```
   GEMINI_API_KEY=ponetuclaveaqui
   ```

   Reemplazá `ponetuclaveaqui` por tu clave real. Sin comillas, sin espacios
   antes del `=`.
4. Ejecutá `.\dev.ps1 run`.

Listo. Eso es todo lo necesario para que la app tome la clave.

---

## 1. Generar la clave

1. Entrá a [Google AI Studio](https://aistudio.google.com/apikey) con una cuenta
   de Google.
2. Aceptá los términos si es la primera vez.
3. Tocá **Create API key** (o **Crear clave de API**).
4. Si te pide elegir un proyecto de Google Cloud, podés crear uno nuevo o usar el
   que ofrece por defecto.
5. Copiá la clave generada. Se muestra una sola vez.

> El plan gratuito es suficiente para la demo. En ese plan Google puede usar lo
> enviado para mejorar sus productos: SafeLabel solo manda texto (ingredientes y
> grupos de alérgenos), nunca la foto ni datos personales.

---

## 2. Crear el archivo `gemini.env`

En la **raíz del proyecto** (la misma carpeta que `pubspec.yaml` y `dev.ps1`),
creá un archivo llamado exactamente:

```
gemini.env
```

La extensión es `.env`. El nombre completo del archivo es `gemini.env`, no
`gemini.env.txt`, ni `gemini.txt`, ni `gemini.env.example`.

La forma más simple es copiar la plantilla:

```powershell
Copy-Item gemini.env.example gemini.env
```

Después editá `gemini.env` y reemplazá el valor de ejemplo por tu clave real.

### Contenido del archivo

El archivo `gemini.env` tiene que contener **una sola línea** con este formato
exacto, cambiando `ponetuclaveaqui` por tu clave real:

```
GEMINI_API_KEY=ponetuclaveaqui
```

Por ejemplo, con una clave real (ficticia) quedaría así:

```
GEMINI_API_KEY=ClaveDeEjemploFicticia123456789
```

Reglas del formato:

- Sin espacios antes ni después del `=` en el nombre de la variable.
- Sin comillas alrededor de la clave.
- Sin espacios al principio de la línea.
- Podés dejar comentarios con `#` y líneas vacías; el script las ignora.
- Guardalo en UTF-8 (o ASCII). No uses formato "UTF-8 con BOM".

Ejemplo válido con comentarios:

```
# Mi clave de Gemini
GEMINI_API_KEY=ClaveDeEjemploFicticia123456789
```

El script lee únicamente la línea que empieza con `GEMINI_API_KEY=` y toma todo
lo que está después del `=`, quitando espacios sobrantes al final.

---

## 3. Ejecutar la app

Con el archivo creado, corré normalmente:

```powershell
.\dev.ps1 run
```

`dev.ps1` lee `gemini.env`, inyecta la clave con
`--dart-define=GEMINI_API_KEY=...` y arranca Flutter. No hace falta configurar
variables de entorno a mano.

Si PowerShell bloquea el script:

```powershell
powershell -ExecutionPolicy Bypass -File .\dev.ps1 run
```

Para una compilación:

```powershell
.\dev.ps1 build
```

---

## 4. Prioridad y alternativas

- Si la variable de entorno `GEMINI_API_KEY` ya está definida en la terminal,
  **tiene prioridad** sobre `gemini.env`:

  ```powershell
  $env:GEMINI_API_KEY = 'ponetuclaveaqui'
  .\dev.ps1 run
  ```

- Para usar otro modelo de Gemini sin tocar código:

  ```powershell
  $env:GEMINI_MODEL = 'gemini-3.8-flash'
  .\dev.ps1 run
  ```

  El modelo principal por defecto es `gemini-3.8-flash`. Si Gemini responde
  HTTP 503 (servicio no disponible), la app reintenta una vez con
  `gemini-3.5-flash-lite`. Ese respaldo es automático y no requiere configuración.

---

## 5. Seguridad

- `gemini.env` está en `.gitignore`: no lo commitees.
- No compartas la clave por chat, correo ni capturas de pantalla.
- No la subas a un repositorio público ni la incluyas en un APK de producción.
  En esta etapa la clave viaja dentro de la compilación porque es una demo.
- Si la clave se filtró, borrala en Google AI Studio y generá otra.
- Antes de commitear, verificá que el archivo no aparezca en `git status`. Si ya
  fue agregado por error:

  ```powershell
  git rm --cached gemini.env
  ```

---

## 6. Problemas comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| El botón dice que la función "todavía no está configurada" | No se encontró la clave | Verificá que `gemini.env` esté en la raíz y tenga la línea `GEMINI_API_KEY=...` |
| La clave no se toma | El archivo quedó como `gemini.env.txt` | Renombralo a `gemini.env` (activá "ver extensiones" en el Explorador de Windows) |
| La clave no se toma | Hay comillas o espacios antes del `=` | Usá exactamente `GEMINI_API_KEY=ponetuclaveaqui` |
| Funcionaba y dejó de andar | Cambiaste la clave y no recompilaste | Volvé a ejecutar `.\dev.ps1 run` (o `build`) para reinyectarla |
| Error de conexión o límite alcanzado | Sin internet o cuota gratuita agotada | Reintentá más tarde; el resultado en tres bloques nunca depende de Gemini |

Para comprobar qué contiene tu archivo (sin mostrarlo en público):

```powershell
Get-Content gemini.env
```
