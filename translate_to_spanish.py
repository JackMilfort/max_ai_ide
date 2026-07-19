"""
Script to translate all visible UI strings in static files from English to Spanish.
This targets user-facing text only, NOT code identifiers or function names.
"""
import os
import re

# Map of English UI strings to Spanish translations
# Focus on user-visible text in HTML/JS
TRANSLATIONS = {
    # Chat interface
    'Message MAX...': 'Escribe un mensaje a MAX...',
    'Message MAX': 'Escribe un mensaje',
    'Send message': 'Enviar mensaje',
    'New conversation': 'Nueva conversación',
    'New Chat': 'Nuevo chat',
    'Search conversations': 'Buscar conversaciones',
    'Search messages': 'Buscar mensajes',
    'Search': 'Buscar',
    'Settings': 'Configuración',
    'Sign out': 'Cerrar sesión',
    'Sign in': 'Iniciar sesión',
    'Sign up': 'Registrarse',
    'Username': 'Usuario',
    'Password': 'Contraseña',
    'Login': 'Entrar',
    'Logout': 'Salir',
    'Loading...': 'Cargando...',
    'Copy': 'Copiar',
    'Copied!': '¡Copiado!',
    'Delete': 'Eliminar',
    'Edit': 'Editar',
    'Save': 'Guardar',
    'Cancel': 'Cancelar',
    'Close': 'Cerrar',
    'Confirm': 'Confirmar',
    'Yes': 'Sí',
    'No': 'No',
    'OK': 'OK',
    'Error': 'Error',
    'Success': 'Éxito',
    'Warning': 'Advertencia',
    # Sidebar & nav
    'Notes': 'Notas',
    'Tasks': 'Tareas',
    'Calendar': 'Calendario',
    'Email': 'Correo',
    'Gallery': 'Galería',
    'Documents': 'Documentos',
    'Research': 'Investigación',
    'Cookbook': 'Recetas',
    'Codex': 'Códex',
    'Groups': 'Grupos',
    # Settings
    'Model': 'Modelo',
    'Theme': 'Tema',
    'Language': 'Idioma',
    'General': 'General',
    'Voice': 'Voz',
    'Memory': 'Memoria',
    'Privacy': 'Privacidad',
    'About': 'Acerca de',
    # Common actions
    'Attach file': 'Adjuntar archivo',
    'Upload': 'Subir',
    'Download': 'Descargar',
    'Share': 'Compartir',
    'Rename': 'Renombrar',
    'Move': 'Mover',
    'Archive': 'Archivar',
    'Restore': 'Restaurar',
    'Add': 'Agregar',
    'Create': 'Crear',
    'Update': 'Actualizar',
    # Splash screen
    'Launching background services...': 'Iniciando servicios...',
    'Please wait, this will take a few seconds.': 'Por favor espera, esto tomará unos segundos.',
    # Tray
    'Open MAX': 'Abrir MAX',
    'Exit': 'Salir',
}

def translate_file(filepath, translations):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        for en, es in translations.items():
            content = content.replace(en, es)
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
    except Exception as e:
        print(f'  ERROR en {filepath}: {e}')
    return False

changed = []
dirs_to_scan = ['static', 'launcher.py']

for entry in dirs_to_scan:
    if os.path.isfile(entry):
        if translate_file(entry, TRANSLATIONS):
            changed.append(entry)
    else:
        for r, d, fs in os.walk(entry):
            for f in fs:
                if f.endswith(('.html', '.js', '.py')):
                    p = os.path.join(r, f)
                    if translate_file(p, TRANSLATIONS):
                        changed.append(p)

print(f'Traducidos {len(changed)} archivos:')
for c in changed:
    print(f'  {c}')
