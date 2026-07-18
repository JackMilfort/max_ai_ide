#Requires -Version 5.1
<#
  Construye MAX.exe para Windows con actualizaciones automáticas activadas.
  Uso: powershell -ExecutionPolicy Bypass -File .\build-windows-portable.ps1
#>

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Write-Step($msg) { Write-Host ""; Write-Host ("==> " + $msg) -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host ("    [ok] " + $msg) -ForegroundColor Green }
function Fail($msg) {
    Write-Host ("ERROR: " + $msg) -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Host ""
Write-Host "=============================" -ForegroundColor Magenta
Write-Host "   MAX — Build Portable EXE  " -ForegroundColor Magenta
Write-Host "=============================" -ForegroundColor Magenta

# ── Buscar Python ─────────────────────────────────────────────────────────────
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

# ── Dependencias ──────────────────────────────────────────────────────────────
Write-Step "Instalando dependencias de build"
& $pyExe -m pip install --upgrade pip --quiet
& $pyExe -m pip install -r requirements.txt pyinstaller pystray Pillow --quiet
if ($LASTEXITCODE -ne 0) { Fail "Error instalando dependencias." }
Write-OK "Dependencias listas"

# ── Compilar EXE ──────────────────────────────────────────────────────────────
Write-Step "Compilando MAX.exe con PyInstaller"
Remove-Item -Recurse -Force build, dist -ErrorAction SilentlyContinue

$dataArgs = @(
    "--add-data", "static;static",
    "--add-data", "scripts;scripts",
    "--add-data", "mcp_servers;mcp_servers",
    "--add-data", "services/hwfit/data;services/hwfit/data",
    "--add-data", "config;config",
    "--add-data", ".env.example;.env.example",
    "--add-data", "src;src"
)

& $pyExe -m PyInstaller --noconfirm --clean --onefile --noconsole `
    --icon=static/icon.ico --name MAX `
    @dataArgs launcher.py

if ($LASTEXITCODE -ne 0) { Fail "PyInstaller fallo." }
Write-OK "MAX.exe compilado"

# ── Generar MAX_launcher.bat ──────────────────────────────────────────────────
Write-Step "Generando MAX_launcher.bat"
& python .\generate_launcher_bat.py
if ($LASTEXITCODE -ne 0) {
    # Fallback: escribir bat directamente byte a byte
    $lines = @(
        "@echo off",
        "cd /d ""%~dp0""",
        ":: MAX Launcher - Abre siempre este archivo para usar MAX",
        "if exist ""MAX.exe.pending"" (",
        "    echo Aplicando actualizacion de MAX...",
        "    move /y ""MAX.exe.pending"" ""MAX.exe"" >nul 2>&1",
        "    if not exist ""%USERPROFILE%\.max"" mkdir ""%USERPROFILE%\.max""",
        "    timeout /t 1 /nobreak > nul",
        ")",
        "start """" ""MAX.exe"""
    )
    [System.IO.File]::WriteAllLines("$PSScriptRoot\dist\MAX_launcher.bat", $lines, [System.Text.Encoding]::ASCII)
}
Write-OK "MAX_launcher.bat creado en dist\"

# ── Copiar .env si existe ──────────────────────────────────────────────────────
Write-Step "Copiando configuracion"
if (Test-Path ".\.env") {
    Copy-Item ".\.env" ".\dist\.env"
    Write-OK ".env copiado al paquete"
}

# ── Generar LEEME.txt ─────────────────────────────────────────────────────────
Write-Step "Generando LEEME.txt"
$readme = @(
    "MAX - Instrucciones de instalacion",
    "==================================",
    "",
    "PARA USAR MAX:",
    "  Abre siempre: MAX_launcher.bat",
    "  Este archivo aplica actualizaciones automaticas",
    "  antes de iniciar la aplicacion.",
    "",
    "ACTUALIZACIONES AUTOMATICAS:",
    "  MAX descarga nuevas versiones en segundo plano.",
    "  La proxima vez que abras MAX_launcher.bat,",
    "  la actualizacion se aplica sola, sin que hagas nada.",
    "  Tus conversaciones, memorias y configuracion",
    "  NUNCA se pierden con las actualizaciones.",
    "",
    "REQUISITOS:",
    "  Windows 10/11",
    "  Conexion a Internet (para el AI y las actualizaciones)",
    "",
    "NO NECESITAS instalar Python, Node.js ni nada mas.",
    "",
    "Desarrollado por Jack Milfort"
)
[System.IO.File]::WriteAllLines("$PSScriptRoot\dist\LEEME.txt", $readme, [System.Text.Encoding]::UTF8)
Write-OK "LEEME.txt creado"

# ── Resumen final ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Build completado exitosamente" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Archivos para distribuir (carpeta dist\):"
Write-Host "    MAX.exe              - la app principal"
Write-Host "    MAX_launcher.bat     - los amigos abren ESTE"
Write-Host "    LEEME.txt            - instrucciones"
Write-Host ""
Write-Host "  Repositorio: https://github.com/JackMilfort/max_ai_ide"
Write-Host "  Para publicar actualizaciones: crea un GitHub Release"
Write-Host "  y adjunta MAX.exe -- los amigos se actualizan solos."
Write-Host ""