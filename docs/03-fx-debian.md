# 3. FX CLI en Debian PRoot: por qué y cómo

## Por qué FX se ejecuta en Debian y no directamente en Termux

Esta separación **no es una preferencia arbitraria**. Resuelve una incompatibilidad real de formato y entorno de ejecución.

**Termux no es una distribución GNU/Linux convencional:** sus programas nativos se compilan para Android, usan la biblioteca C de Android (**Bionic**) y el cargador dinámico de Android. En cambio, los ejecutables Linux distribuidos para sistemas GNU/Linux suelen estar compilados para **glibc** y esperan el cargador y las rutas de un sistema Linux convencional. Compartir arquitectura **aarch64/ARM64 no garantiza compatibilidad binaria**.

En el dispositivo de referencia, al intentar iniciar el ejecutable Linux de **FX CLI** directamente desde Termux nativo, el resultado fue:

```text
unexpected e_type: 2
```

Esto es un **síntoma de incompatibilidad al cargar el ejecutable**, no un problema con Qwen, el endpoint HTTP o la GPU. No debe interpretarse como una limitación universal de FX: podría existir en el futuro una compilación FX específica para Android/Termux, pero **la distribución que probamos no funcionó directamente allí**.

**Debian mediante `proot-distro` proporciona un espacio de usuario GNU/Linux**, con sus bibliotecas, rutas y cargador compatibles con los ejecutables Linux correspondientes. PRoot permite utilizarlo **sin root de Android**. No es una máquina virtual ni convierte el kernel de Android en Linux de escritorio: crea un entorno de usuario emulado/interceptado sobre el mismo kernel. Por ello, un binario concreto puede tener limitaciones adicionales, pero **FX CLI v0.0.14 sí arrancó y funcionó dentro de Debian PRoot en este dispositivo**.

### Por qué llama.cpp con GPU permanece fuera de Debian

El servidor necesita llegar a las **bibliotecas OpenCL propietarias del firmware Qualcomm** y utilizar el backend Android nativo compilado en Termux. Esa ruta fue comprobada con `clinfo`, `--list-devices` y `offloaded 37/37 layers to GPU`.

Ejecutar el servidor dentro de Debian PRoot complicaría el acceso a esas bibliotecas y podría mezclar ABI/glibc con bibliotecas Android/Bionic. **No afirmamos que sea imposible habilitar GPU dentro de PRoot**; simplemente **no lo necesitamos y no fue el camino validado**. El diseño probado deja cada programa en su entorno compatible:

```text
Android (mismo dispositivo y kernel)
├── Termux nativo (binarios Android / Bionic)
│   ├── Qualcomm OpenCL → Adreno 830
│   └── llama-server: http://127.0.0.1:8080/v1
└── Termux → Debian PRoot (espacio de usuario GNU/Linux)
    └── FX CLI (binario Linux)
        └── peticiones HTTP → 127.0.0.1:8080/v1
```

**FX no necesita acceso directo a OpenCL.** Solo necesita comunicarse por HTTP con la API compatible con OpenAI que expone llama-server. Como ambos procesos residen en el mismo teléfono y comparten la red del sistema, se conectan por **localhost**, sin un servicio en la nube ni exposición del endpoint a internet.

Esta es la **razón técnica fundamental de la arquitectura híbrida**.

## 1. Preparar Debian

En **Termux nativo**, si aún no se dispone de Debian:

```bash
pkg install -y proot-distro
proot-distro install debian
proot-distro login debian
```

Para sesiones posteriores bastará con `proot-distro login debian`.

**FX CLI debe estar instalado dentro de Debian.** Se comprobó la ejecución de **FX v0.0.14** en `/root`. La obtención e instalación desde cero del binario FX no está documentada todavía porque no se validó su método de distribución en esta instalación; no usar un comando de descarga inventado.

## 2. Configurar el proveedor local de FX

Archivo **dentro de Debian**: `/root/.fx/settings.json`. Ejemplo operativo usado en la instalación de referencia:

```json
{
  "models": {
    "codex": "gpt-5.6-sol",
    "local": "qwen2.5-3b-instruct-q4_k_m.gguf"
  },
  "provider": "local",
  "statusLine": {
    "context": true,
    "session": true,
    "workspace": true
  },
  "effort": "auto",
  "providers": {
    "local": {
      "protocol": "openai-chat-completions",
      "base_url": "http://127.0.0.1:8080/v1",
      "auth": { "type": "none" },
      "model_metadata": {
        "qwen2.5-3b-instruct-q4_k_m.gguf": {
          "context_window": 16384,
          "max_output_tokens": 1024,
          "supports_tool_use": true
        }
      }
    }
  }
}
```

La clave `codex` es una opción alternativa que existía en esa configuración, **no un requisito**. Si FX ya tiene proveedores, claves u otros ajustes, no sobrescribirlos con este ejemplo: integrar solamente el proveedor `local` y establecer `provider: local`.

Se utiliza `auth.type=none` porque `llama-server` escucha únicamente en `127.0.0.1`; no exponer el endpoint públicamente sin autenticación y controles de acceso.

### Ajustar el contexto sin sustituir la configuración

Si existe `settings.json`, desde Debian:

```bash
python3 - <<'PY'
import json
from pathlib import Path
p = Path("/root/.fx/settings.json")
data = json.loads(p.read_text())
data["providers"]["local"]["model_metadata"]["qwen2.5-3b-instruct-q4_k_m.gguf"]["context_window"] = 16384
p.write_text(json.dumps(data, indent=2) + "\n")
PY
```

## 3. Por qué el contexto debe ser de 16 384 tokens

FX es un agente y prepara instrucciones, descripciones de herramientas y esquemas JSON incluso para mensajes breves. En la sesión de referencia, la petición de FX con el texto `hola` incluyó **7305 tokens de entrada**.

Con el contexto inicialmente configurado de `8192` tokens, FX devolvía `ContextCapacityExceeded` **antes de enviar la petición HTTP**. Al ampliar **ambos lados** a 16 384 — servidor con `--ctx-size 16384` y FX con `model_metadata.context_window: 16384` — una nueva sesión de FX pudo conversar con Qwen.

**Importante:** el contexto es un límite de tokens, **no es la cantidad de memoria GPU**. Al aumentarlo crece la memoria necesaria para la caché KV. Esto no garantiza compatibilidad con esquemas de herramientas complejos.

## 4. Arrancar FX y comprobar la conexión

Mantener `llama-server` funcionando en otra sesión de Termux, luego:

```bash
proot-distro login debian
fx
```

Enviar `hola`. En la prueba verificada, FX respondió en español, mostró `7k/16k` y el servidor registró una petición real de 7305 tokens. El tiempo total observado fue ~50.7 segundos en esa ejecución concreta, no un rendimiento garantizado.

## 5. Herramientas de FX: pendiente de validar

Que FX pueda conversar con Qwen **no significa** que pueda invocar sus herramientas de shell y archivos. La plantilla del modelo declara soporte de `tools`, pero la ejecución completa aún no está comprobada.

Prueba funcional sugerida (pendiente):

```text
Ejecuta el comando pwd usando tu herramienta de terminal y muestra únicamente el resultado.
```

Validar en la interfaz de FX una llamada real a la herramienta y su resultado. **Una ruta escrita directamente por el modelo no es prueba de ejecución.**

Las versiones de llama.cpp pueden presentar dificultades al generar gramáticas GBNF para esquemas JSON grandes. Si se reproduce un error así, tratar la compatibilidad de herramientas como un problema separado del hardware y del tamaño del contexto. No probar acciones destructivas ni datos financieros reales hasta validar las herramientas.
