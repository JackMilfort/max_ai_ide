"""Fix lang attribute to Spanish and add extra chat translations."""

extra_chat = {
    'Type a message...': 'Escribe un mensaje...',
    'Send': 'Enviar',
    'Regenerate': 'Regenerar',
    'Stop generating': 'Detener',
    'Copied to clipboard': 'Copiado al portapapeles',
    'Thinking...': 'Pensando...',
    'Searching...': 'Buscando...',
    'Attach': 'Adjuntar',
    'Record': 'Grabar',
    'Retry': 'Reintentar',
}

# Fix lang in HTML files
for f in ['static/index.html', 'static/login.html']:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    content = content.replace('lang="en"', 'lang="es"')
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
    print(f'Fixed lang in {f}')

# Extra chat strings
with open('static/js/chat.js', 'r', encoding='utf-8') as file:
    chatjs = file.read()
for en, es in extra_chat.items():
    chatjs = chatjs.replace(en, es)
with open('static/js/chat.js', 'w', encoding='utf-8') as file:
    file.write(chatjs)
print('Fixed chat.js')
