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
# Sustitutos por IA (Gemini, plan gratuito): copiá gemini.env.example a
# gemini.env y poné tu clave. dev.ps1 pasa el archivo completo a Flutter con
# --dart-define-from-file; no hace falta setear variables en PowerShell.
#
# Si PowerShell bloquea el script:
#   powershell -ExecutionPolicy Bypass -File .\dev.ps1 doctor

$ErrorActionPreference = 'Stop'

# Rutas: Flutter desde PATH o FLUTTER_PATH (carpeta bin o flutter.bat).
$FlutterExe = $null
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    $FlutterExe = $flutterCmd.Source
}
if (-not $FlutterExe -and $env:FLUTTER_PATH) {
    $candidato = $env:FLUTTER_PATH
    if (Test-Path -LiteralPath $candidato -PathType Leaf) {
        $FlutterExe = $candidato
    } else {
        foreach ($nombre in @('flutter.bat', 'flutter')) {
            $ruta = Join-Path $candidato $nombre
            if (Test-Path -LiteralPath $ruta -PathType Leaf) {
                $FlutterExe = $ruta
                break
            }
        }
    }
}
if (-not $FlutterExe -or -not (Test-Path -LiteralPath $FlutterExe -PathType Leaf)) {
    throw "No encuentro Flutter. Agregalo al PATH o definí FLUTTER_PATH apuntando a la carpeta bin del SDK."
}
$FlutterBin = Split-Path $FlutterExe -Parent

$SdkDir     = Join-Path $env:LOCALAPPDATA 'Android\Sdk'

# JAVA_HOME: solo si ya está configurado en el entorno (para compilaciones Android)
if ($env:JAVA_HOME) {
    $env:JAVA_HOME = $env:JAVA_HOME
}
$env:ANDROID_HOME     = $SdkDir
$env:ANDROID_SDK_ROOT = $SdkDir
$env:Path             = "$FlutterBin;$SdkDir\platform-tools;$env:Path"

if ($args.Count -ge 1 -and $args[0] -eq 'licenses') {
    $sdkmanager = Join-Path $SdkDir 'cmdline-tools\latest\bin\sdkmanager.bat'
    if (-not (Test-Path $sdkmanager)) { throw "No encuentro sdkmanager en $sdkmanager" }
    Write-Host "Aceptando licencias del Android SDK..." -ForegroundColor Cyan
    ("y`n" * 30) | & $sdkmanager --licenses
    return
}

# Sustitutos por IA (CLAUDE.md, seccion 5.6): gemini.env se pasa completo a
# Flutter con --dart-define-from-file. Funciona igual para Chrome y Android e
# incluye GEMINI_MODEL si está en el archivo. El archivo está en .gitignore.
# Las variables de entorno, si existen, mantienen prioridad (--dart-define).
$flutterArgs = @($args)
if ($flutterArgs.Count -ge 1 -and ($flutterArgs[0] -eq 'run' -or $flutterArgs[0] -eq 'build')) {
    $geminiEnv = Join-Path $PSScriptRoot 'gemini.env'
    if (Test-Path -LiteralPath $geminiEnv -PathType Leaf) {
        $flutterArgs += "--dart-define-from-file=$geminiEnv"
    } else {
        Write-Host "Aviso: no se encontró gemini.env; las sugerencias de IA quedarán sin configurar." -ForegroundColor Yellow
    }
    if ($env:GEMINI_API_KEY) { $flutterArgs += "--dart-define=GEMINI_API_KEY=$env:GEMINI_API_KEY" }
    if ($env:GEMINI_MODEL)   { $flutterArgs += "--dart-define=GEMINI_MODEL=$env:GEMINI_MODEL" }
}

& $FlutterExe @flutterArgs
