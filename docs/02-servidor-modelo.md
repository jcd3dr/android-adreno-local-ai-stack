# 2. Modelo, arranque de llama-server y GPU

## 1. Preparar el archivo GGUF

Descargar legalmente un GGUF compatible desde la fuente y licencia correspondientes. El modelo efectivamente validado fue **Qwen2.5-3B-Instruct**, cuantización **Q4_K_M**.

Guardarlo como:

```text
~/models/qwen2.5-3b-instruct-q4_k_m.gguf
```

La guía deliberadamente **no presupone una URL de descarga ni un nombre de repositorio Hugging Face específico que no se haya validado**. El GGUF es ~1.95 GiB y no se incluye en GitHub.

## 2. Arrancar el servidor GPU en Termux nativo

Desde Termux, **no desde Debian**:

```bash
LD_LIBRARY_PATH="$HOME/adreno-opencl:$PREFIX/lib" \
"$HOME/llama-adreno/src/build-opencl-static/bin/llama-server" \
  -m "$HOME/models/qwen2.5-3b-instruct-q4_k_m.gguf" \
  --device GPUOpenCL \
  --n-gpu-layers 99 \
  --host 127.0.0.1 \
  --port 8080 \
  --ctx-size 16384 \
  --parallel 1 \
  --threads 4 \
  --jinja \
  -lv 4
```

O bien utilizar `bash ~/android-adreno-local-ai-stack/scripts/start-llama-opencl.sh` después de clonar **este** repositorio en Termux.

El proceso permanece en primer plano y muestra `listening on http://127.0.0.1:8080`. **Dejar esa sesión abierta** y utilizar otra para FX/pruebas. Detener con `Ctrl+C`.

La combinación `--device GPUOpenCL` y `--n-gpu-layers 99` selecciona la GPU e intenta descargar todas las capas compatibles. No se garantiza disponibilidad de memoria en otros dispositivos. El contexto de 16K se verificó en el dispositivo de referencia.

## 3. Evidencia inequívoca de offload

Buscar líneas semejantes a:

```text
llama_prepare_model_devices: using device GPUOpenCL (QUALCOMM Adreno(TM) 830)
load_tensors: offloading output layer to GPU
load_tensors: offloading 35 repeating layers to GPU
load_tensors: offloaded 37/37 layers to GPU
OpenCL model buffer size = 1834.94 MiB
OpenCL KV buffer size = 288.00 MiB     # cifra de una sesión de 8192 tokens
ggml_opencl: OpenCL device: QUALCOMM Adreno(TM) 830
ggml_opencl: using kernels optimized for Adreno (GGML_OPENCL_USE_ADRENO_KERNELS)
llama_server: listening on http://127.0.0.1:8080
```

La memoria KV cambia con `--ctx-size`. En una sesión de 8192 tokens se midieron 288 MiB; no usar esa cifra como referencia obligatoria a 16K.

## 4. Verificar la API (otra sesión de Termux)

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen2.5-3b-instruct-q4_k_m.gguf",
    "messages": [{"role": "user", "content": "Responde únicamente: GPU funcionando"}],
    "max_tokens": 30
  }'
```

La prueba devolvió `"GPU funcionando"`; eso demuestra conectividad e inferencia, **no** uso de GPU por sí solo. El uso de GPU queda confirmado por el registro de offload anterior.

## 5. Conexión y seguridad

El endpoint es `http://127.0.0.1:8080/v1`; el bind a localhost limita el acceso de red. La compilación de referencia advierte cuando CORS permite todos los orígenes y no hay clave de API. No cambiar el host a `0.0.0.0` sin configurar autenticación, controles de origen y acceso de red.

El modelo puede generar errores y debe validarse para documentos financieros.
