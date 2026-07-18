"""
MAX Auto-Updater
================
Descarga actualizaciones en segundo plano mientras la app está corriendo.
La actualización se aplica automáticamente en el siguiente inicio de MAX.

Configuración (vía .env):
  MAX_UPDATE_URL: URL de la API de GitHub Releases para verificar actualizaciones.
                  Ejemplo: https://api.github.com/repos/jackmilfort/max/releases/latest
  MAX_CURRENT_VERSION: Versión actual (se lee automáticamente desde el release tag).

Los datos del usuario en ~/.max/data NUNCA son tocados por las actualizaciones.
"""

import json
import logging
import os
import sys
import threading
import time
import urllib.request
from pathlib import Path

logger = logging.getLogger(__name__)

# Intervalo de verificación en segundos (default: cada 6 horas)
UPDATE_CHECK_INTERVAL = int(os.getenv("MAX_UPDATE_CHECK_INTERVAL", str(6 * 3600)))

_update_status = {
    "checking": False,
    "update_ready": False,
    "new_version": None,
    "current_version": None,
    "download_progress": 0,
    "applied_version": None,   # se llena si este inicio ya aplicó una actualización
}


def get_status() -> dict:
    """Retorna el estado actual del actualizador (para el endpoint de la API)."""
    return dict(_update_status)


def _get_exe_dir() -> str:
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _get_pending_path() -> str:
    return os.path.join(_get_exe_dir(), "MAX.new")


def _get_version_cache_path() -> str:
    data_dir = os.path.join(os.path.expanduser("~"), ".max")
    return os.path.join(data_dir, "updater_cache.json")


def _get_applied_flag_path() -> str:
    data_dir = os.path.join(os.path.expanduser("~"), ".max")
    return os.path.join(data_dir, "update_applied.json")


def _load_cache() -> dict:
    try:
        p = _get_version_cache_path()
        if os.path.exists(p):
            with open(p, encoding="utf-8") as f:
                return json.load(f)
    except Exception:
        pass
    return {}


def _save_cache(data: dict):
    try:
        p = _get_version_cache_path()
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as f:
            json.dump(data, f)
    except Exception:
        pass


def check_applied_on_startup() -> str | None:
    """
    Llama esto al inicio para ver si en ESTE inicio se aplicó una actualización.
    Retorna la versión aplicada o None.
    """
    flag = _get_applied_flag_path()
    if os.path.exists(flag):
        try:
            with open(flag, encoding="utf-8") as f:
                data = json.load(f)
            version = data.get("version")
            os.remove(flag)
            _update_status["applied_version"] = version
            logger.info(f"[AutoUpdater] Actualización {version} aplicada exitosamente en este inicio.")
            return version
        except Exception:
            pass
    return None


# Removed _write_launcher_bat logic
def _download_update(asset_url: str, version: str) -> bool:
    """Descarga la nueva versión a MAX.exe.pending. Retorna True si fue exitoso."""
    pending_path = _get_pending_path()
    tmp_path = pending_path + ".tmp"
    try:
        logger.info(f"[AutoUpdater] Descargando actualización {version} desde {asset_url}")
        req = urllib.request.Request(
            asset_url,
            headers={"User-Agent": "MAX-AutoUpdater/1.0", "Accept": "application/octet-stream"}
        )
        with urllib.request.urlopen(req, timeout=300) as response:
            total = int(response.headers.get("Content-Length", 0))
            downloaded = 0
            with open(tmp_path, "wb") as f:
                while True:
                    chunk = response.read(65536)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total > 0:
                        _update_status["download_progress"] = int(downloaded / total * 100)

        # Reemplazar archivo pending con el recién descargado
        if os.path.exists(pending_path):
            os.remove(pending_path)
        os.rename(tmp_path, pending_path)

        # Registrar version para el proximo inicio
        try:
            os.makedirs(os.path.join(os.path.expanduser("~"), ".max"), exist_ok=True)
            flag_path = os.path.join(os.path.expanduser("~"), ".max", "update_applied.json")
            with open(flag_path, "w", encoding="utf-8") as f:
                json.dump({"version": version}, f)
        except Exception:
            pass

        _update_status["update_ready"] = True
        _update_status["new_version"] = version
        _update_status["download_progress"] = 100
        logger.info(f"[AutoUpdater] ✓ Actualización {version} descargada. Se aplicará en el próximo inicio.")
        return True

    except Exception as e:
        logger.warning(f"[AutoUpdater] Error al descargar actualización: {e}")
        try:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)
        except Exception:
            pass
        return False


def _check_for_updates():
    """Verifica si hay una nueva versión disponible en GitHub Releases."""
    update_url = os.getenv("MAX_UPDATE_URL", "").strip()
    if not update_url:
        return

    _update_status["checking"] = True
    try:
        req = urllib.request.Request(
            update_url,
            headers={"User-Agent": "MAX-AutoUpdater/1.0", "Accept": "application/vnd.github.v3+json"}
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            data = json.loads(r.read())

        latest_tag = data.get("tag_name", "").strip()
        if not latest_tag:
            return

        # Comparar con lo que ya vimos
        cache = _load_cache()
        if latest_tag == cache.get("latest_seen"):
            return  # Ya sabemos de esta versión

        # Comparar con versión actual (puede venir del env o de los metadatos del exe)
        current = os.getenv("MAX_CURRENT_VERSION", cache.get("current_version", "")).strip()
        _update_status["current_version"] = current

        if latest_tag == current:
            _save_cache({**cache, "latest_seen": latest_tag})
            return

        # Encontrar el asset MAX.exe en el release
        asset_url = None
        for asset in data.get("assets", []):
            if asset.get("name", "").upper() in ("MAX.EXE", "MAX_WINDOWS.EXE"):
                asset_url = asset.get("browser_download_url")
                break

        if not asset_url:
            logger.info(f"[AutoUpdater] Nueva versión {latest_tag} disponible pero no hay asset MAX.exe")
            return

        logger.info(f"[AutoUpdater] Nueva versión disponible: {latest_tag} (actual: {current or 'desconocida'})")

        # Descargar en segundo plano (ya estamos en un thread)
        if _download_update(asset_url, latest_tag):
            _save_cache({**cache, "latest_seen": latest_tag, "downloaded_version": latest_tag})

    except Exception as e:
        logger.debug(f"[AutoUpdater] Verificación fallida (no crítico): {e}")
    finally:
        _update_status["checking"] = False


def start_background_updater():
    """
    Inicia el verificador de actualizaciones en segundo plano.
    Llamar UNA VEZ al inicio de la aplicación.
    """
    # Solo aplica al exe compilado con PyInstaller
    if not getattr(sys, "frozen", False):
        update_url = os.getenv("MAX_UPDATE_URL", "").strip()
        if not update_url:
            logger.debug("[AutoUpdater] Modo desarrollo: actualizaciones automáticas desactivadas.")
            return

    update_url = os.getenv("MAX_UPDATE_URL", "").strip()
    if not update_url:
        logger.debug("[AutoUpdater] MAX_UPDATE_URL no configurado — actualizaciones automáticas desactivadas.")
        return

    def _loop():
        # Esperar 60s después del inicio antes de verificar
        time.sleep(60)
        while True:
            try:
                _check_for_updates()
            except Exception as e:
                logger.debug(f"[AutoUpdater] Error inesperado: {e}")
            time.sleep(UPDATE_CHECK_INTERVAL)

    t = threading.Thread(target=_loop, daemon=True, name="max-auto-updater")
    t.start()
    logger.info(f"[AutoUpdater] Iniciado — verificará actualizaciones cada {UPDATE_CHECK_INTERVAL // 3600}h.")
