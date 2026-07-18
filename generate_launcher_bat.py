"""Genera MAX_launcher.bat en la carpeta dist\ con encoding ASCII correcto."""
import os

lines = [
    "@echo off\r\n",
    "cd /d \"%~dp0\"\r\n",
    ":: ============================================================\r\n",
    "::  MAX Launcher - No borres este archivo.\r\n",
    "::  Abre siempre ESTE archivo para usar MAX.\r\n",
    "::  Aplica actualizaciones automaticas antes de iniciar la app.\r\n",
    ":: ============================================================\r\n",
    "if exist \"MAX.exe.pending\" (\r\n",
    "    echo Aplicando actualizacion de MAX...\r\n",
    "    move /y \"MAX.exe.pending\" \"MAX.exe\" >nul 2>&1\r\n",
    "    if not exist \"%USERPROFILE%\\.max\" mkdir \"%USERPROFILE%\\.max\"\r\n",
    "    echo {\"version\":\"latest\"} > \"%USERPROFILE%\\.max\\update_applied.json\"\r\n",
    "    timeout /t 1 /nobreak > nul\r\n",
    ")\r\n",
    "start \"\" \"MAX.exe\"\r\n",
]

dist_dir = os.path.join(os.path.dirname(__file__), "dist")
os.makedirs(dist_dir, exist_ok=True)
bat_path = os.path.join(dist_dir, "MAX_launcher.bat")

with open(bat_path, "wb") as f:
    for line in lines:
        f.write(line.encode("ascii"))

print(f"MAX_launcher.bat creado en {bat_path}")
