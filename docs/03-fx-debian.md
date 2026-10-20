# 3. FX CLI en Debian PRoot y proveedor OpenAI-compatible

## 1. Separación de responsabilidades

- **Termux nativo:** servidor llama.cpp, OpenCL y GPU Qualcomm.
- **Debian PRoot:** FX CLI y, en el futuro, scripts de extracción y análisis de documentos.

En el dispositivo validado, el servidor de Termux fue accesible desde Debian PRoot usando `127.0.0.1:8080`.

Instalar y acceder a Debian con `proot-distro` según la documentación de Termux (si aún no está instalado):

```bash
pkg install -y proot-distro
proot-distro install debian
proot-distro login debian
```

**FX CLI debe estar instalado en Debian antes de este capítulo.** Se verificó FX v0.0.14 en `/root`. No incluimos aquí una instalación de FX no contrastada con una distribución/release concreta. Conservar la instalación existente.

## 2. Configuración conocida que funcionó

Archivo dentro de Debian: `/root/.fx/settings.json`.

La configuración de referencia incluye el proveedor Codex como alternativa y el proveedor local como activo. **No sobrescribir otros proveedores o secretos existentes:** incorporar el bloque `local` y ajustar `models.local`, `provider`.

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

La clave `codex` representa una alternativa del dispositivo de referencia; no es necesaria para ejecutar el proveedor local. `auth.type=none` es apropiado solo porque la API está limitada a localhost.

Si ya existe `settings.json`, actualizar **únicamente** el contexto conservando el resto:

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

## 3. Importancia de los 16 384 tokens

FX incluye instrucciones del agente y esquemas de herramientas. Incluso para el mensaje **`hola`**, el servidor recibió un prompt de **7305 tokens**. Con los **8192 tokens** que se habían configurado inicialmente, FX respondió `ContextCapacityExceeded` antes de enviar la solicitud HTTP. Al establecer **16 384 tokens tanto en llama-server como en FX**, una nueva sesión de FX recibió respuesta correctamente.

**Los valores de contexto deben coincidir** entre `--ctx-size` y `model_metadata.context_window`. Aumentarlos consume memoria y no corrige por sí solo un posible error de gramática o de esquemas de herramientas.

## 4. Abrir FX

Mientras el servidor Termux permanece activo, entrar en Debian en otra sesión:

```bash
proot-distro login debian
fx
```

Probar `hola` en una sesión nueva. La prueba verificada respondió en español y mostró `7k/16k` en la barra de estado. El servidor registró `task.n_tokens = 7305`, unos 50.7 s de duración total para aquella petición.

## 5. Tool calling: validación pendiente

El GGUF incorpora chat template con `tools` y el endpoint indica capacidades de tool calling, pero esto **no demuestra** que FX pueda ejecutar su herramienta de shell ni manejar todos sus esquemas.

Una prueba pendiente y de bajo riesgo es solicitar en FX:

```text
Ejecuta pwd usando tu herramienta de terminal y muestra el resultado.
```

Hay que observar una **invocación real** y su retorno; no basta con que el modelo escriba una ruta inventada. Los esquemas grandes pueden ocasionar errores de generación de gramática (GBNF) en ciertas versiones de llama.cpp. Si ocurre, consultar el diagnóstico y tratar la compatibilidad de herramientas como asunto separado del GPU.

**No ejecutar herramientas destructivas ni procesar documentos financieros reales** hasta completar esta validación.
