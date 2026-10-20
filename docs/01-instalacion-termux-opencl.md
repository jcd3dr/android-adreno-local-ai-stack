# 1. Termux nativo: dependencias, OpenCL Qualcomm y compilación

## Requisitos

- Android aarch64 con GPU Qualcomm Adreno y bibliotecas OpenCL disponibles en el firmware.
- Termux operativo y acceso a internet para paquetes, fuentes y modelo.
- Espacio de almacenamiento suficiente para compilar y guardar el GGUF.
- Esta guía se ejecuta **en Termux nativo**. No ejecutar estos comandos dentro de Debian PRoot.

Se probó sobre Galaxy S25 / Adreno 830. Otros dispositivos pueden tener nombres de bibliotecas, permisos o drivers diferentes.

## 1. Instalar dependencias

```bash
pkg update
pkg install -y \
  git clang cmake ninja make pkg-config python \
  opencl-headers opencl-vendor-driver ocl-icd clinfo
```

La disponibilidad de paquetes depende del repositorio Termux configurado.

## 2. Preparar las bibliotecas OpenCL del propio teléfono

En el dispositivo de referencia existen `/vendor/lib64/libOpenCL.so` y `/vendor/lib64/libOpenCL_adreno.so`. Copiarlas a una carpeta privada, **sin modificar `/system` ni `/vendor`**:

```bash
mkdir -p "$HOME/adreno-opencl"
cp /vendor/lib64/libOpenCL.so /vendor/lib64/libOpenCL_adreno.so "$HOME/adreno-opencl/"
```

Comprobar que la capa Qualcomm se detecta usando **este orden** de rutas:

```bash
LD_LIBRARY_PATH="$HOME/adreno-opencl:$PREFIX/lib" clinfo -l
```

En la referencia funcionó:

```text
Platform #0: QUALCOMM Snapdragon(TM)
 `-- Device #0: QUALCOMM Adreno(TM) 830
```

**Importante:** el cargador `$PREFIX/lib/libOpenCL.so` disponible mediante Termux no siempre detecta la plataforma Qualcomm por su mecanismo ICD: el driver del dispositivo puede no exponer `cl_khr_icd`. La carpeta privada y `LD_LIBRARY_PATH` permitieron la detección en este caso. **No anteponer `/vendor/lib64` a todas las bibliotecas del entorno**: puede introducir conflictos con binarios de Termux. Las bibliotecas del firmware no se deben redistribuir.

## 3. Obtener llama.cpp

```bash
mkdir -p "$HOME/llama-adreno"
cd "$HOME/llama-adreno"
git clone https://github.com/ggml-org/llama.cpp.git src
```

Para reproducir **exactamente la versión validada**:

```bash
git -C src checkout 839a572
```

Para probar una versión más reciente, omitir el checkout, teniendo presente que sus opciones de compilación y comportamiento pueden diferir.

## 4. Configurar y compilar el servidor

```bash
cd "$HOME/llama-adreno"
cmake -S src -B src/build-opencl-static -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DGGML_OPENCL=ON \
  -DGGML_OPENCL_USE_ADRENO_KERNELS=ON \
  -DOpenCL_INCLUDE_DIR="$PREFIX/include" \
  -DOpenCL_LIBRARY="$HOME/adreno-opencl/libOpenCL.so" \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_SERVER=ON \
  -DLLAMA_BUILD_UI=OFF

cmake --build src/build-opencl-static --target llama-server -j 4
```

La configuración `BUILD_SHARED_LIBS=OFF` fue esencial para obtener un ejecutable capaz de arrancar en el dispositivo de referencia. *No significa que todas las dependencias externas sean estáticas:* el driver Qualcomm OpenCL sigue cargándose dinámicamente.

Se conserva la compilación en una carpeta distinta de la de cualquier otro servidor. No es necesario instalar el binario sobre el sistema.

## 5. Verificar ejecutable y backend

```bash
"$HOME/llama-adreno/src/build-opencl-static/bin/llama-server" --version

LD_LIBRARY_PATH="$HOME/adreno-opencl:$PREFIX/lib" \
"$HOME/llama-adreno/src/build-opencl-static/bin/llama-server" --list-devices
```

Resultado de referencia:

```text
version: 0.7.0-dev (build 1, commit 839a572)
Available devices:
GPUOpenCL: QUALCOMM Adreno(TM) 830 (5556 MiB, 4532 MiB free)
```

**La lista de dispositivos solo demuestra detección; el offload real se verifica al iniciar el modelo** (capítulo 2).

## No ejecutar sin auditar

El proyecto `paragon83114/llama-adreno` sirvió como referencia, pero su `setup.sh` puede sustituir `$PREFIX/include/spawn.h` por una cabecera simplificada. Esta guía **no usa ese script ni altera cabeceras globales**.
