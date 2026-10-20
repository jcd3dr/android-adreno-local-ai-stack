# 4. Validación por capas y diagnóstico mínimo

Esta sección es una guía de interpretación y soluciones pertinentes, **no** una bitácora de todos los intentos realizados.

## Matriz de validación

| Comprobación | Prueba | Estado en el dispositivo de referencia |
| --- | --- | --- |
| Driver Qualcomm | `LD_LIBRARY_PATH="$HOME/adreno-opencl:$PREFIX/lib" clinfo -l` | Confirmado |
| Backend llama.cpp | `llama-server --list-devices` | GPUOpenCL Adreno 830 confirmado |
| Binario ARM Android | `llama-server --version` | Confirmado con compilación estática |
| Offload real | Registro `offloaded 37/37 layers to GPU` | Confirmado |
| GPU kernels | Registro `using kernels optimized for Adreno` | Confirmado |
| Servidor API | `listening on http://127.0.0.1:8080` | Confirmado |
| Solicitud OpenAI-compatible | `curl /v1/chat/completions` | Confirmado |
| FX conversación | `hola` con `7k/16k` | Confirmado |
| FX ejecución de shell | Ver llamada real a `pwd` | **Pendiente** |
| Procesamiento de PDF y datos financieros | Dataset de prueba + conciliación | **Pendiente** |

## Si hay fallo antes de `--version`

Si el ejecutable devuelve `Segmentation fault` antes incluso de procesar argumentos, revisar si fue construido con `BUILD_SHARED_LIBS=OFF`. En el caso de referencia, un binario compilado contra las bibliotecas internas compartidas se bloqueaba durante la carga de Android, mientras que la compilación con bibliotecas internas estáticas arrancó.

No reemplazar `$PREFIX/include/spawn.h`, no editar el firmware y no asumir que cualquier fallo previo al arranque sea OpenCL.

## Si `clinfo` no detecta plataformas

En algunos drivers Qualcomm, el paquete ICD de Termux no enumera la plataforma. Usar las bibliotecas originales del **propio teléfono** en `~/adreno-opencl` y ejecutar con:

```bash
LD_LIBRARY_PATH="$HOME/adreno-opencl:$PREFIX/lib" clinfo -l
```

Evitar `LD_LIBRARY_PATH=/vendor/lib64:$PREFIX/lib` como configuración general: podría anteponer bibliotecas incompatibles con procesos de Termux.

## Si detecta GPU pero no hace offload

Usar `--device GPUOpenCL --n-gpu-layers 99 -lv 4`. Confirmar en los registros tanto la detección como `offloaded N/N layers to GPU` y los buffers OpenCL. `--list-devices` por sí solo no confirma offload.

## Si FX muestra `ContextCapacityExceeded`

Comprobar que ambos lados usan `16384`: llama-server `--ctx-size 16384` y FX `model_metadata.context_window: 16384`. Reiniciar una sesión FX para reevaluar su prompt. FX puede preparar ~7.3K tokens de instrucciones/herramientas incluso ante `hola`. Si el modelo o una conversación requieren más, revisar uso real de tokens y memoria antes de aumentar nuevamente el contexto.

## Si FX conversa pero no invoca herramientas

Es otro problema: diferenciar **tool calling** y ejecución. Hay versiones de llama.cpp que pueden fallar al generar gramáticas de esquemas JSON especialmente amplios, por ejemplo herramientas con parámetros `char{0,65536}`. Consultar registros concretos de la petición, compatibilidad del chat template y parser de herramientas. No atribuir el error a GPU, al contexto o a una ejecución exitosa hasta contar con evidencia.

## Rendimiento observado, no benchmark universal

Una prueba HTTP corta con el modelo en un arranque anterior produjo ~166.57 tokens/s en procesamiento de prompt y ~22.12 tokens/s de generación sobre 4 tokens; este último número es poco representativo por tamaño de muestra. Una solicitud FX con ~7305 tokens tuvo ~154.55 tokens/s de evaluación de prompt y ~4.67 tokens/s de generación de 17 tokens. Son condiciones muy distintas y **no deben interpretarse como comparación CPU/GPU ni garantía de velocidad**.

## Privacidad y alcance

Con `--host 127.0.0.1` las solicitudes permanecen en la interfaz local del dispositivo. El trabajo puede implicar acceso a archivos sensibles a través de FX; las acciones del agente requerirán permisos y validación. **No guardar documentos bancarios, claves o datos personales reales en este repositorio público.**
