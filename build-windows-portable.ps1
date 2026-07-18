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

# ── Copiar .env si existe ──────────────────────────────────────────────────────
Write-Step "Copiando configuracion"
if (Test-Path ".\.env") {
    Copy-Item ".\.env" ".\dist\.env"
    Write-OK ".env copiado al paquete"
}

# ── Resumen final ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Build completado exitosamente" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Archivo para distribuir (carpeta dist\):"
Write-Host "    MAX.exe              - la app principal (ahora se auto-actualiza!)"
Write-Host ""
Write-Host "  Repositorio: https://github.com/JackMilfort/max_ai_ide"
Write-Host "  Para publicar actualizaciones: crea un GitHub Release"
Write-Host "  y adjunta MAX.exe -- los amigos se actualizan solos."
Write-Host ""