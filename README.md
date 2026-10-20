# IA local en Android: Adreno OpenCL + llama.cpp + FX CLI

Documentación reproducible de un stack de inferencia **local** en un teléfono Android con GPU Qualcomm Adreno. El servidor de modelos se ejecuta en **Termux nativo** con **llama.cpp + OpenCL**; **FX CLI** se ejecuta dentro de **Debian PRoot** y se conecta al servidor HTTP local.

> **Estado verificado (2026-10-20):** Samsung Galaxy S25 / Adreno 830; modelo Qwen2.5-3B-Instruct Q4_K_M; 37/37 capas transferidas a GPU; API OpenAI-compatible operativa; FX CLI v0.0.14 conversando con el modelo mediante un contexto de 16 384 tokens. **La ejecución de herramientas de FX, el procesamiento de PDF y el pipeline financiero no se han validado todavía.**

## Arquitectura

```text
Android / Samsung Galaxy S25 (12 GB RAM)
│
├─ Termux nativo
│  ├─ Qualcomm OpenCL 3.0 → Adreno 830
│  ├─ llama.cpp compilado con OpenCL + kernels Adreno
│  ├─ Qwen2.5-3B-Instruct GGUF (Q4_K_M)
│  └─ llama-server → 127.0.0.1:8080/v1
│
└─ Termux → proot-distro → Debian
   └─ FX CLI v0.0.14
      └─ proveedor local (openai-chat-completions)
         └─ http://127.0.0.1:8080/v1
```

**Toda la inferencia corre en el dispositivo.** Las descargas iniciales de herramientas, código y modelo requieren red. Las tareas con herramientas de FX deben validarse antes de calificar el agente completo como operativo.

## Inicio rápido

1. Seguir **[Instalación y compilación](docs/01-instalacion-termux-opencl.md)** en Termux nativo.
2. Seguir **[Servidor local y comprobación GPU](docs/02-servidor-modelo.md)**.
3. Seguir **[FX CLI en Debian](docs/03-fx-debian.md)**.
4. Consultar **[Verificación, límites y diagnóstico](docs/04-verificacion-y-diagnostico.md)** cuando sea necesario.

Se incluye un script de arranque reproducible en [scripts/start-llama-opencl.sh](scripts/start-llama-opencl.sh). El script no instala ni descarga nada y presupone que la compilación y el GGUF ya existen.

## Stack verificado

| Capa | Implementación |
| --- | --- |
| Dispositivo de referencia | Samsung Galaxy S25, Snapdragon 8 Elite, Adreno 830, 12 GB RAM |
| Entorno de inferencia | Termux nativo (Android aarch64) |
| GPU | OpenCL 3.0 Qualcomm; driver de referencia reportado `0800.64.8` |
| Motor | [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp), compilado localmente, revisión verificada `839a572` (0.7.0-dev) |
| CMake | `BUILD_SHARED_LIBS=OFF`, `GGML_OPENCL=ON`, `GGML_OPENCL_USE_ADRENO_KERNELS=ON` |
| Modelo probado | `qwen2.5-3b-instruct-q4_k_m.gguf`, 3.40B, Q4_K_M, 1.95 GiB |
| API | OpenAI-compatible Chat Completions, `127.0.0.1:8080/v1` |
| Agente | FX CLI v0.0.14 en Debian PRoot |
| Contexto operativo probado con FX | 16 384 tokens |

Los nombres de modelos, drivers, revisiones y opciones pueden cambiar. La referencia de este repositorio describe **una combinación concreta que funcionó**, no una garantía universal para cualquier Android/Adreno.

## Qué está probado y qué no

**Confirmado:** la GPU aparece en `--list-devices`; `llama-server` inicia, carga el GGUF y registra `offloaded 37/37 layers to GPU`; una llamada `curl` a Chat Completions devuelve contenido; FX CLI obtiene una respuesta conversacional desde el endpoint local. En una solicitud simple de FX, el servidor recibió un prompt de **7305 tokens** con un contexto de **16 384**.

**Pendiente:** verificar llamadas reales a herramientas de FX (terminal/archivos), compatibilidad completa de sus esquemas JSON, exactitud y seguridad del agente, lectura de PDF, extracción de movimientos, SQLite/CSV y validación contable. **No confundir capacidad anunciada de tool calling con ejecución probada de herramientas.**

## Principios de instalación

- Conservar **Termux nativo para OpenCL** y usar Debian PRoot **solo para FX**.
- No copiar las bibliotecas propietarias Qualcomm al repositorio; se toman del propio dispositivo.
- No modificar globalmente archivos de cabecera de Termux (en particular `$PREFIX/include/spawn.h`).
- Compilar **con `BUILD_SHARED_LIBS=OFF`**, manteniendo OpenCL dinámico, para evitar problemas de arranque del cargador Android observados con la variante de bibliotecas compartidas.
- Nunca exponer por defecto el endpoint a toda la red: usar `--host 127.0.0.1`.
- No colocar estados de cuenta, datos financieros, claves o modelos de licencia restringida en commits.

## Fuentes y proyectos

- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [Termux](https://termux.dev/)
- [Termux PRoot-Distro](https://github.com/termux/proot-distro)
- [OpenCL Khronos](https://www.khronos.org/opencl/)
- [paragon83114/llama-adreno](https://github.com/paragon83114/llama-adreno) (referencia de técnicas Adreno; **no** ejecutar ciegamente su `setup.sh`)

**Licencia:** la documentación del repositorio se distribuye bajo [MIT](LICENSE); las bibliotecas Qualcomm, FX y los modelos conservan sus respectivas licencias.
