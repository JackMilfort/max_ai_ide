<div align="center">

# ⚡ MAX

**Personal AI Assistant — Desarrollado por Jack Milfort**

[![Release](https://img.shields.io/github/v/release/JackMilfort/max_ai_ide?style=flat-square&color=e06c75&label=version)](https://github.com/JackMilfort/max_ai_ide/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Windows-blue?style=flat-square)](https://github.com/JackMilfort/max_ai_ide/releases/latest)

</div>

---

## Que es MAX?

MAX es un asistente de IA personal que corre en tu computadora. Soporta modelos locales (Ollama, LM Studio) y APIs externas (OpenAI, etc.), con memoria persistente, investigacion web, y mucho mas.

- Memoria persistente - recuerda tus conversaciones
- Privado - corre localmente, tus datos no salen de tu PC
- Auto-actualizaciones - recibe nuevas versiones automaticamente
- Investigacion web integrada
- Notas, calendario, tareas integradas

---

## Instalacion (para amigos)

No necesitas instalar Python, Node.js ni nada mas.

1. Ve a [Releases](https://github.com/JackMilfort/max_ai_ide/releases/latest)
2. Descarga MAX.exe y MAX_launcher.bat
3. Ponlos en la misma carpeta
4. Abre siempre MAX_launcher.bat para usar MAX

---

## Actualizaciones automaticas

MAX se actualiza solo. Cuando hay una nueva version:

1. MAX la descarga en segundo plano mientras esta abierto
2. La proxima vez que abras MAX_launcher.bat, se instala silenciosamente
3. Aparece una notificacion en la interfaz confirmando la actualizacion

Tus conversaciones, memorias y configuracion NUNCA se pierden.

---

## Para publicar una actualizacion

```powershell
powershell -ExecutionPolicy Bypass -File .\publish-update.ps1
```

El script automaticamente compila MAX.exe, sube el codigo y crea el GitHub Release.
Los usuarios existentes se actualizan solos la proxima vez que abran MAX.

---

Desarrollado por Jack Milfort
