import os

def safe_replace(file_path):
    if not os.path.exists(file_path): return
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # HTML content replacements
    replacements = {
        '>New chat<': '>Nuevo chat<',
        '>Search<': '>Buscar<',
        '>Chats<': '>Chats<',
        '>Email<': '>Correo<',
        '>Tools<': '>Herramientas<',
        '>Brain<': '>Memoria<',
        '>Calendar<': '>Calendario<',
        '>Compare<': '>Comparar<',
        '>Cookbook<': '>Recetas<',
        '>Deep Research<': '>Investigación<',
        '>Gallery<': '>Galería<',
        '>Library<': '>Biblioteca<',
        '>Notes<': '>Notas<',
        '>Tasks<': '>Tareas<',
        '>Theme<': '>Tema<',
        '>Settings<': '>Configuración<',
        '>Select model<': '>Seleccionar modelo<',
        'Message Odysseus...': 'Escribe un mensaje a MAX...',
        'placeholder="Message Odysseus..."': 'placeholder="Escribe un mensaje a MAX..."',
        '>Login<': '>Iniciar sesión<',
        'lang="en"': 'lang="es"',
        'Odysseus Chat': 'MAX Chat',
        '>Odysseus<': '>MAX<'
    }

    for en, es in replacements.items():
        content = content.replace(en, es)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

safe_replace('static/index.html')
safe_replace('static/login.html')

# Also safely replace just the specific chat UI strings in JS without breaking keywords
def safe_js_replace(file_path):
    if not os.path.exists(file_path): return
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    js_repl = {
        "'Message Odysseus...'": "'Escribe un mensaje a MAX...'",
        '"Message Odysseus..."': '"Escribe un mensaje a MAX..."',
        "'Type a message...'": "'Escribe un mensaje...'",
        '"Type a message..."': '"Escribe un mensaje..."',
        "'Copied to clipboard'": "'Copiado al portapapeles'",
        '"Copied to clipboard"': '"Copiado al portapapeles"',
        "'Thinking...'": "'Pensando...'",
        '"Thinking..."': '"Pensando..."'
    }
    
    for en, es in js_repl.items():
        content = content.replace(en, es)
        
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

safe_js_replace('static/js/chat.js')
safe_js_replace('static/js/ui.js')

print('Safe translations applied.')
