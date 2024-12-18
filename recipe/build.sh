#!/usr/bin/env bash
set -ex

# build system uses non-standard env vars
uname=$(uname)
if [[ "$target_platform" == osx* ]]; then
  #export LIBS="${LIBS} -L${PREFIX}/lib -v"
  #export LDFLAGS="${LDFLAGS} -L${PREFIX}/lib -v"
  export CFLAGS="${CFLAGS} -I ${PREFIX}/include/freetype2"
  export CFLAGS="${CFLAGS} -I $(ls -d ${PREFIX}/include/openjpeg-*)"
  #export SYS_FREETYPE_LIBS=" -lfreetype"
  #export SYS_FREETYPE_CFLAGS="${CFLAGS}"
  export TESSERACT=false
else
  export TESSERACT=yes
fi
if [[ "$target_platform" == osx-arm64 ]]; then
  export CFLAGS="${CFLAGS} -Wno-incompatible-function-pointer-types"
fi
export CFLAGS="${CFLAGS} -I ${PREFIX}/include/harfbuzz"
export XCFLAGS="${CFLAGS}"
export XLIBS="${LIBS}"
export USE_SYSTEM_LIBS=yes
export USE_SYSTEM_JPEGXR=yes
export VENV_FLAG=""

# diagnostics
#ls -lh ${PREFIX}/lib

# build and install
make prefix="${PREFIX}" pydir="${SP_DIR}" tesseract=${TESSERACT} shared=yes -j ${CPU_COUNT} all python

# no make check
make prefix="${PREFIX}" pydir="${SP_DIR}" tesseract=${TESSERACT} shared=yes install install-shared-python
