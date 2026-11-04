# dev.ps1 - entorno local para SafeLabel (Flutter + Android SDK).
# No es parte de la app. Podes borrarlo o agregarlo a .gitignore.
#
# Uso:
#   .\dev.ps1 doctor -v
#   .\dev.ps1 test
#   .\dev.ps1 run
#   .\dev.ps1 emulators --launch Pixel_3a_API_33_x86_64
#   .\dev.ps1 licenses      # acepta las licencias del Android SDK (una sola vez)
#
# Sustitutos por IA (Gemini, plan gratuito): antes de run/build, en la misma
# terminal:
#   $env:GEMINI_API_KEY = 'ponetuclaveaqui'
#
# Si PowerShell bloquea el script:
#   powershell -ExecutionPolicy Bypass -File .\dev.ps1 doctor

$ErrorActionPreference = 'Stop'

# Rutas: Flutter desde PATH o configurable
$FlutterBin = ''
if (Get-Command flutter -ErrorAction SilentlyContinue) {
    $FlutterBin = (Get-Command flutter).CommandPath
    $FlutterBin = Split-Path $FlutterBin -Parent
}
if (-not $FlutterBin) {
    $FlutterBin = $env:FLUTTER_PATH
}
if (-not $FlutterBin) {
    $FlutterBin = 'C:\dev\flutter\bin'
}

$SdkDir     = Join-Path $env:LOCALAPPDATA 'Android\Sdk'

# JAVA_HOME: solo si ya está configurado en el entorno (para compilaciones Android)
if ($env:JAVA_HOME) {
    $env:JAVA_HOME = $env:JAVA_HOME
}
$env:ANDROID_HOME     = $SdkDir
$env:ANDROID_SDK_ROOT = $SdkDir
$env:Path             = "$FlutterBin;$SdkDir\platform-tools;$env:Path"

if (-not (Test-Path (Join-Path $FlutterBin 'flutter.bat'))) {
    throw "No encuentro flutter en $FlutterBin"
}

if ($args.Count -ge 1 -and $args[0] -eq 'licenses') {
    $sdkmanager = Join-Path $SdkDir 'cmdline-tools\latest\bin\sdkmanager.bat'
    if (-not (Test-Path $sdkmanager)) { throw "No encuentro sdkmanager en $sdkmanager" }
    Write-Host "Aceptando licencias del Android SDK..." -ForegroundColor Cyan
    ("y`n" * 30) | & $sdkmanager --licenses
    return
}

# Sustitutos por IA (CLAUDE.md, seccion 5.6): la clave de Gemini se toma de la
# variable de entorno GEMINI_API_KEY y se inyecta en la compilacion. Nunca se
# escribe en el repositorio. GEMINI_MODEL es opcional.
# Intento cargar desde gemini.env si la variable no está seteada.
if (-not $env:GEMINI_API_KEY -and (Test-Path 'gemini.env')) {
    $env:GEMINI_API_KEY = ''
    foreach ($line in (Get-Content 'gemini.env')) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -match 'GEMINI_API_KEY=(.*)') {
            $env:GEMINI_API_KEY = $Matches[1].Trim()
            break
        }
    }
}
$flutterArgs = @($args)
if ($flutterArgs.Count -ge 1 -and ($flutterArgs[0] -eq 'run' -or $flutterArgs[0] -eq 'build')) {
    if ($env:GEMINI_API_KEY) { $flutterArgs += "--dart-define=GEMINI_API_KEY=$env:GEMINI_API_KEY" }
    if ($env:GEMINI_MODEL)   { $flutterArgs += "--dart-define=GEMINI_MODEL=$env:GEMINI_MODEL" }
}

& (Join-Path $FlutterBin 'flutter.bat') @flutterArgs
