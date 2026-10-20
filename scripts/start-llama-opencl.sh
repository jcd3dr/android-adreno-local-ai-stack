#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Ejecutar en Termux nativo, no dentro de Debian PRoot.
# Variables opcionales: MODEL_PATH, LLAMA_SERVER, CTX_SIZE, PORT.
MODEL_PATH="${MODEL_PATH:-$HOME/models/qwen2.5-3b-instruct-q4_k_m.gguf}"
LLAMA_SERVER="${LLAMA_SERVER:-$HOME/llama-adreno/src/build-opencl-static/bin/llama-server}"
CTX_SIZE="${CTX_SIZE:-16384}"
PORT="${PORT:-8080}"

if [[ ! -f "$MODEL_PATH" ]]; then
  echo "No se encontró el modelo: $MODEL_PATH" >&2
  exit 1
fi
if [[ ! -x "$LLAMA_SERVER" ]]; then
  echo "No se encontró el servidor compilado: $LLAMA_SERVER" >&2
  exit 1
fi
if [[ ! -f "$HOME/adreno-opencl/libOpenCL.so" ]]; then
  echo "Falta ~/adreno-opencl/libOpenCL.so del propio dispositivo" >&2
  exit 1
fi

export LD_LIBRARY_PATH="$HOME/adreno-opencl:$PREFIX/lib"
exec "$LLAMA_SERVER" \
  -m "$MODEL_PATH" \
  --device GPUOpenCL \
  --n-gpu-layers 99 \
  --host 127.0.0.1 \
  --port "$PORT" \
  --ctx-size "$CTX_SIZE" \
  --parallel 1 \
  --threads 4 \
  --jinja \
  -lv 4
