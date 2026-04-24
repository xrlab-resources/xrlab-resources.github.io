# XRLab Events Web Server

Este servidor web Python automatiza el proceso de añadir eventos al sistema de log de eventos del laboratorio.

## Características

- **Interfaz web para añadir eventos**: Usa el mismo formulario que `newevent.html` pero con integración directa
- **Guardado automático**: Los eventos se guardan directamente en `events.json` sin necesidad de copiar y pegar
- **Servidor local**: Se ejecuta localmente para facilitar el uso
- **Compatibilidad total**: Compatible con el sistema existente de eventos

## Instalación

1. Asegúrate de tener Python 3.7+ instalado
2. Instala las dependencias:
   ```bash
   pip install -r requirements.txt
   ```

## Uso

1. Inicia el servidor:
   ```bash
   python app.py
   ```

2. Abre tu navegador y ve a:
   - `http://localhost:5000` - Para añadir nuevos eventos
   - `http://localhost:5000/events.html` - Para ver los eventos existentes

3. Rellena el formulario y haz clic en "Add to events list"
4. El evento se guardará automáticamente en `events.json`

## Características del servidor

### Endpoints

- `GET /` - Sirve el formulario para añadir eventos
- `GET /events.html` - Sirve la página de visualización de eventos
- `GET /events.json` - Sirve el archivo JSON de eventos
- `POST /add_event` - Procesa el formulario y añade el evento a events.json

### Funcionalidades

- **Validación**: Requiere campos obligatorios (título, fecha, ubicación)
- **Actualización**: Si un evento con el mismo ID ya existe, lo actualiza
- **Ordenación**: Los nuevos eventos se añaden al principio de la lista
- **Feedback**: Muestra mensajes de éxito/error con información útil

## Integración con Git

El servidor trabaja directamente con el archivo `events.json` en el repositorio. Después de añadir eventos:

1. Los cambios están listos para commit
2. Usa `git add events.json` y `git commit` para guardar los cambios
3. Usa `git push` para subir al repositorio

## Estructura de archivos

```
├── app.py              # Servidor web Flask
├── requirements.txt    # Dependencias Python
├── templates/
│   ├── newevent.html   # Formulario para añadir eventos
│   └── events.html     # Página para visualizar eventos
├── events.json         # Base de datos de eventos
└── README_SERVER.md    # Este archivo
```

## Personalización

- **Puerto**: Cambia la variable `PORT` en `app.py` (por defecto: 5000)
- **Debug**: Activa/desactiva el modo debug en `app.run()`
- **Archivo de eventos**: Cambia `EVENTS_FILE` para usar un archivo diferente

## Solución de problemas

### El servidor no inicia
- Verifica que Python esté instalado
- Instala las dependencias: `pip install -r requirements.txt`

### Los eventos no se guardan
- Verifica los permisos de escritura en el directorio
- Asegúrate que `events.json` no esté bloqueado por otro programa

### Error de CORS
- El servidor incluye Flask-CORS para manejar solicitudes cross-origin
- Si tienes problemas, verifica que las extensiones del navegador no interfieran

## Comparación con el método manual

| Método | Pasos | Ventajas |
|--------|-------|----------|
| **Manual** | 1. Rellenar formulario<br>2. Copiar JSON<br>3. Pegar en events.json<br>4. Guardar archivo | - Control total<br>- Sin dependencias |
| **Servidor** | 1. Rellenar formulario<br>2. Click en "Add" | - Automático<br>- Menos errores<br>- Validación<br>- Feedback inmediato |

## Seguridad

- El servidor se ejecuta localmente (`localhost`)
- No hay autenticación (diseñado para uso personal/local)
- Los datos se guardan directamente en el sistema de archivos

Para uso en producción, considera añadir:
- Autenticación de usuarios
- Validación adicional
- Backup automático
- Logging de eventos
