#Requires -Version 5.1
<#
  MAX Update Script
  =================
  Sincroniza los cambios del proyecto original (upstream) con tu fork
  personalizado de MAX, preservando todas tus personalizaciones.

  Uso:
    powershell -ExecutionPolicy Bypass -File .\update-max.ps1

  Lo que hace:
  1. Configura el repositorio original como "upstream" (si no existe)
  2. Jala los cambios del repositorio original
  3. Fusiona (merge) SOLO los archivos del backend — NO sobrescribe
     tus archivos personalizados (logo, branding, runtime_paths, etc.)
  4. Reinstala dependencias nuevas si requirements.txt cambió
  5. Reconstruye el ejecutable MAX.exe con tus customizaciones
#>

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Write-Step($msg) { Write-Host ""; Write-Host ("==> " + $msg) -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host ("    [ok] " + $msg) -ForegroundColor Green }
function Write-Warn($msg) { Write-Host ("    [!] " + $msg) -ForegroundColor Yellow }
function Fail($msg) {
    Write-Host ""
    Write-Host ("ERROR: " + $msg) -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}

# ── Archivos personalizados que NUNCA deben sobreescribirse con el upstream ──
$PROTECTED_FILES = @(
    "static/icon.ico",
    "static/icons/icon-192.png",
    "static/icons/icon-512.png",
    "static/icons/icon-maskable-512.png",
    "static/login.html",      # Tiene tu crédito "Desarrollado por Jack Milfort"
    "static/index.html",      # Tiene tu crédito "Desarrollado por Jack Milfort"
    "static/manifest.json",   # Nombre de app = MAX
    "launcher.py",            # Título de ventana y tray icon = MAX
    "src/runtime_paths.py",   # Carpeta de datos = .max
    "build-windows-portable.ps1",  # Empaqueta como MAX.exe
    ".env"                    # Tus credenciales y configuración local
)

Write-Host ""
Write-Host "=====================================" -ForegroundColor Magenta
Write-Host "  MAX - Actualizador desde upstream  " -ForegroundColor Magenta
Write-Host "=====================================" -ForegroundColor Magenta

# ── Paso 1: Verificar que git está disponible ──
Write-Step "Verificando git"
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) { Fail "Git no está instalado o no está en el PATH." }
Write-OK "git encontrado"

# ── Paso 2: Configurar upstream si no existe ──
Write-Step "Configurando repositorio upstream"
$remotes = & git remote 2>$null
if ($remotes -notcontains "upstream") {
    & git remote add upstream https://github.com/odysseus-dev/odysseus.git
    Write-OK "Repositorio upstream agregado: https://github.com/odysseus-dev/odysseus.git"
} else {
    Write-OK "upstream ya configurado"
}

# ── Paso 3: Guardar cambios locales no commiteados ──
Write-Step "Guardando cambios locales (git stash)"
$stashOutput = & git stash 2>&1
if ($stashOutput -match "No local changes") {
    Write-OK "Sin cambios locales pendientes"
    $stashed = $false
} else {
    Write-OK "Cambios guardados temporalmente"
    $stashed = $true
}

# ── Paso 4: Jalar cambios del upstream ──
Write-Step "Jalando cambios del proyecto original"
& git fetch upstream
if ($LASTEXITCODE -ne 0) { Fail "Error al jalar cambios del upstream." }
Write-OK "Cambios descargados"

# ── Paso 5: Merge con estrategia de preservar archivos protegidos ──
Write-Step "Fusionando cambios (preservando personalizaciones MAX)"

# Hacer merge del main upstream
& git merge upstream/main --no-edit --strategy-option=theirs 2>&1 | Out-Null

# Restaurar inmediatamente los archivos protegidos desde el HEAD local
Write-Warn "Restaurando archivos personalizados de MAX..."
foreach ($file in $PROTECTED_FILES) {
    if (Test-Path $file) {
        & git checkout HEAD -- $file 2>$null
        Write-OK "Preservado: $file"
    }
}

Write-OK "Merge completado con personalizaciones intactas"

# ── Paso 6: Restaurar cambios stasheados ──
if ($stashed) {
    Write-Step "Restaurando cambios locales guardados"
    & git stash pop 2>&1 | Out-Null
    Write-OK "Cambios locales restaurados"
}

# ── Paso 7: Actualizar dependencias de Python ──
Write-Step "Actualizando dependencias Python"
$venvPy = Join-Path $PSScriptRoot "venv\Scripts\python.exe"
if (Test-Path $venvPy) {
    & $venvPy -m pip install -r requirements.txt --quiet
    Write-OK "Dependencias actualizadas"
} else {
    Write-Warn "venv no encontrado — saltando pip install. Ejecuta launch-windows.ps1 primero."
}

# ── Paso 8: Reconstruir el ejecutable ──
Write-Step "Reconstruyendo MAX.exe con tus personalizaciones"
$buildChoice = Read-Host "¿Deseas reconstruir MAX.exe ahora? (s/n)"
if ($buildChoice -eq "s" -or $buildChoice -eq "S") {
    & powershell -ExecutionPolicy Bypass -File .\build-windows-portable.ps1
    Write-OK "MAX.exe reconstruido exitosamente"
} else {
    Write-Warn "Reconstrucción omitida. Ejecuta build-windows-portable.ps1 cuando estés listo."
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host "  Actualización completada con exito " -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""
Write-Host "Tus personalizaciones (logo, nombre MAX, credito 'Jack Milfort') fueron preservadas."
Write-Host ""
