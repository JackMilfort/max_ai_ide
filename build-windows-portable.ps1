#Requires -Version 5.1
<#
  Construye el ejecutable portable MAX.exe para Windows.

  Salida:
    dist\MAX.exe            — El ejecutable principal de MAX
    dist\MAX_launcher.bat   — El lanzador que los usuarios usan (aplica updates auto)
    dist\README_distribución.txt — Instrucciones de distribución

  Para activar actualizaciones automáticas:
    1. Crea un repositorio en GitHub para MAX.
    2. Cuando quieras lanzar una actualización, crea un GitHub Release
       y adjunta MAX.exe como asset del release.
    3. Configura MAX_UPDATE_URL en .env ANTES de compilar:
       MAX_UPDATE_URL=https://api.github.com/repos/TU_USUARIO/max/releases/latest
    4. Recompila y distribuye la nueva versión a tus amigos.
       ¡Las versiones anteriores se actualizarán solas!

  Uso:
    powershell -ExecutionPolicy Bypass -File .\build-windows-portable.ps1
#>

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Write-Step($msg) { Write-Host ""; Write-Host ("==> " + $msg) -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host ("    [ok] " + $msg) -ForegroundColor Green }
function Fail($msg) {
    Write-Host ""
    Write-Host ("ERROR: " + $msg) -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Host ""
Write-Host "=============================" -ForegroundColor Magenta
Write-Host "   MAX — Build Portable EXE  " -ForegroundColor Magenta
Write-Host "=============================" -ForegroundColor Magenta

Write-Step "Verificando Python"
$pyExe = $null
if (Test-Path ".\venv\Scripts\python.exe") {
    $pyExe = (Resolve-Path ".\venv\Scripts\python.exe").Path
} else {
    foreach ($c in @("py", "python")) {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        if ($cmd) { $pyExe = $cmd.Source; break }
    }
    if ($pyExe -like "*WindowsApps*python.exe") {
        $pyCmd = Get-Command py -ErrorAction SilentlyContinue
        if ($pyCmd) { $pyExe = $pyCmd.Source }
    }
}
if (-not $pyExe) { Fail "Python no encontrado. Instala Python 3.11+ primero." }
Write-OK "Python: $pyExe"

Write-Step "Instalando dependencias de build"
& $pyExe -m pip install --upgrade pip --quiet
& $pyExe -m pip install -r requirements.txt pyinstaller pystray Pillow --quiet
if ($LASTEXITCODE -ne 0) { Fail "Error instalando dependencias." }
Write-OK "Dependencias listas"

Write-Step "Compilando MAX.exe con PyInstaller"
Remove-Item -Recurse -Force build, dist -ErrorAction SilentlyContinue

$dataArgs = @(
    "--add-data", "static;static",
    "--add-data", "scripts;scripts",
    "--add-data", "mcp_servers;mcp_servers",
    "--add-data", "services/hwfit/data;services/hwfit/data",
    "--add-data", "config;config",
    "--add-data", ".env.example;.env.example",
    "--add-data", "src;src"      # Incluye auto_updater.py y demás módulos src/
)

& $pyExe -m PyInstaller --noconfirm --clean --onefile --noconsole `
    --icon=static/icon.ico --name MAX `
    @dataArgs launcher.py

if ($LASTEXITCODE -ne 0) { Fail "PyInstaller falló." }
Write-OK "MAX.exe compilado"

# ── Crear MAX_launcher.bat (el que los usuarios abren) ──────────────────────
Write-Step "Generando MAX_launcher.bat"

$batContent = @"
@echo off
cd /d "%~dp0"
:: ============================================================
::  MAX Launcher  -  No borres ni muevas este archivo.
::  Este es el archivo que debes abrir siempre para usar MAX.
::  Aplica actualizaciones automáticas antes de iniciar la app.
:: ============================================================
if exist "MAX.exe.pending" (
    echo Aplicando actualizacion de MAX...
    move /y "MAX.exe.pending" "MAX.exe" >nul 2>&1
    if not exist "%USERPROFILE%\.max" mkdir "%USERPROFILE%\.max"
    echo {"version":"latest"} > "%USERPROFILE%\.max\update_applied.json"
    timeout /t 1 /nobreak > nul
)
start "" "MAX.exe"
"@

$batContent | Out-File -FilePath ".\dist\MAX_launcher.bat" -Encoding ASCII
Write-OK "MAX_launcher.bat creado en dist\"

# ── Crear README de distribución ─────────────────────────────────────────────
Write-Step "Generando instrucciones de distribución"

$readmeContent = @"
════════════════════════════════════════
  MAX — Instrucciones de instalación
════════════════════════════════════════

PARA USAR MAX:
  - Abre siempre: MAX_launcher.bat
  - Este archivo aplica actualizaciones automáticas
    antes de iniciar la aplicación.

ACTUALIZACIONES AUTOMÁTICAS:
  - MAX descarga nuevas versiones en segundo plano.
  - La próxima vez que abras MAX_launcher.bat,
    la actualización se aplica sola, sin que hagas nada.
  - Tus conversaciones, memorias y configuración
    NUNCA se pierden con las actualizaciones.

REQUISITOS:
  - Windows 10/11
  - Conexión a Internet (para el AI y las actualizaciones)

NO NECESITAS instalar Python, Node.js ni nada más.

═══════════════════════════════════════
  Desarrollado por Jack Milfort
═══════════════════════════════════════
"@

$readmeContent | Out-File -FilePath ".\dist\LEEME.txt" -Encoding UTF8
Write-OK "LEEME.txt creado"

Write-Host ""
Write-Host "══════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✓ Build completado exitosamente              " -ForegroundColor Green
Write-Host "══════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  Archivos para distribuir (carpeta dist\):"
Write-Host "    → MAX.exe              (la app principal)"
Write-Host "    → MAX_launcher.bat     (los amigos abren ESTE)"
Write-Host "    → LEEME.txt            (instrucciones)"
Write-Host ""
Write-Host "  Para ACTIVAR actualizaciones automáticas:"
Write-Host "    1. Crea un GitHub Release con MAX.exe como adjunto"
Write-Host "    2. Configura MAX_UPDATE_URL en .env antes de compilar"
Write-Host "       MAX_UPDATE_URL=https://api.github.com/repos/TU_USUARIO/max/releases/latest"
Write-Host "    3. Recompila y distribuye la nueva versión"
Write-Host ""