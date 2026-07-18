#Requires -Version 5.1
<#
  publish-update.ps1 — MAX Update Publisher
  ==========================================
  Compila MAX.exe, sube el codigo a GitHub y publica un nuevo Release
  con un solo comando. Los amigos se actualizan automaticamente.

  Uso:
    powershell -ExecutionPolicy Bypass -File .\publish-update.ps1
    powershell -ExecutionPolicy Bypass -File .\publish-update.ps1 -Version "1.2.0" -Notes "Nuevas funciones"
#>

param(
    [string]$Version  = "",
    [string]$Notes    = ""
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot
$env:PATH = [System.Environment]::GetEnvironmentVariable('PATH','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH','User')

function Write-Step($msg) { Write-Host ""; Write-Host ("==> " + $msg) -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host ("    [ok] " + $msg) -ForegroundColor Green }
function Write-Warn($msg) { Write-Host ("    [!]  " + $msg) -ForegroundColor Yellow }
function Fail($msg) {
    Write-Host (""; "ERROR: $msg") -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Magenta
Write-Host "   MAX -- Publicador de Actualizaciones   " -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta

# ── Leer version actual del .env ──────────────────────────────────────────────
Write-Step "Leyendo version actual"
$envContent = Get-Content ".\.env" -Raw
$currentVersionMatch = [regex]::Match($envContent, 'MAX_CURRENT_VERSION=(.+)')
$currentVersion = if ($currentVersionMatch.Success) { $currentVersionMatch.Groups[1].Value.Trim() } else { "1.0.0" }
Write-OK "Version actual: $currentVersion"

# ── Determinar nueva version ──────────────────────────────────────────────────
if (-not $Version) {
    Write-Host ""
    Write-Host "  Version actual: $currentVersion" -ForegroundColor Yellow
    $Version = Read-Host "  Nueva version (Enter para auto-incrementar patch)"
    if (-not $Version) {
        # Auto-incrementar el patch (1.0.0 -> 1.0.1)
        $parts = $currentVersion -split '\.'
        if ($parts.Count -eq 3) {
            $patch = [int]$parts[2] + 1
            $Version = "$($parts[0]).$($parts[1]).$patch"
        } else {
            $Version = "1.0.1"
        }
    }
}
Write-OK "Nueva version: $Version"

# ── Pedir notas del release ───────────────────────────────────────────────────
if (-not $Notes) {
    Write-Host ""
    $Notes = Read-Host "  Describe los cambios de esta version (Enter para omitir)"
    if (-not $Notes) { $Notes = "Mejoras y correcciones de errores." }
}

# ── Confirmar antes de continuar ──────────────────────────────────────────────
Write-Host ""
Write-Host "  Se va a publicar:" -ForegroundColor White
Write-Host "    Version : v$Version" -ForegroundColor Cyan
Write-Host "    Cambios : $Notes" -ForegroundColor Cyan
Write-Host "    Release : https://github.com/JackMilfort/max_ai_ide/releases/tag/v$Version" -ForegroundColor Cyan
Write-Host ""
$confirm = Read-Host "  Continuar? (s/n)"
if ($confirm -ne "s" -and $confirm -ne "S") {
    Write-Host "Cancelado." -ForegroundColor Yellow
    exit 0
}

# ── Actualizar version en .env ────────────────────────────────────────────────
Write-Step "Actualizando version en .env"
$envContent = $envContent -replace 'MAX_CURRENT_VERSION=.+', "MAX_CURRENT_VERSION=$Version"
[System.IO.File]::WriteAllText("$PSScriptRoot\.env", $envContent, [System.Text.Encoding]::UTF8)
Write-OK ".env actualizado a v$Version"

# ── Compilar MAX.exe ──────────────────────────────────────────────────────────
Write-Step "Compilando MAX.exe v$Version"
& powershell -ExecutionPolicy Bypass -File .\build-windows-portable.ps1
if ($LASTEXITCODE -ne 0) { Fail "El build fallo. Revisa los errores arriba." }
Write-OK "MAX.exe v$Version compilado"

# ── Commit y push del codigo ──────────────────────────────────────────────────
Write-Step "Subiendo codigo a GitHub"
& git add -A
& git commit -m "release: MAX v$Version - $Notes"
& git push origin main
if ($LASTEXITCODE -ne 0) {
    Write-Warn "Push fallo, pero continuando con el release..."
}
Write-OK "Codigo subido"

# ── Crear GitHub Release con MAX.exe ─────────────────────────────────────────
Write-Step "Publicando GitHub Release v$Version"

$releaseNotes = @"
## MAX v$Version

$Notes

### Como instalar (primera vez):
1. Descarga **MAX.exe** y **MAX_launcher.bat**
2. Ponlos en la misma carpeta
3. Abre siempre **MAX_launcher.bat**

### Actualizacion automatica:
Si ya tienes MAX instalado, la proxima vez que abras MAX_launcher.bat
esta version se instalara sola. No necesitas hacer nada.

---
*Desarrollado por Jack Milfort*
"@

$tmpNotes = "$PSScriptRoot\.release_notes_tmp.md"
[System.IO.File]::WriteAllText($tmpNotes, $releaseNotes, [System.Text.Encoding]::UTF8)

& gh release create "v$Version" `
    ".\dist\MAX.exe" `
    ".\dist\MAX_launcher.bat" `
    ".\dist\LEEME.txt" `
    --repo JackMilfort/max_ai_ide `
    --title "MAX v$Version" `
    --notes-file $tmpNotes

Remove-Item $tmpNotes -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) { Fail "No se pudo crear el Release en GitHub." }
Write-OK "Release publicado"

# ── Resultado final ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  MAX v$Version publicado exitosamente!   " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Release: https://github.com/JackMilfort/max_ai_ide/releases/tag/v$Version"
Write-Host ""
Write-Host "  Tus amigos recibiran la actualizacion automaticamente"
Write-Host "  la proxima vez que abran MAX_launcher.bat."
Write-Host ""
