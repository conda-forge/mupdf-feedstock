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
fi
export CFLAGS="${CFLAGS} -I ${PREFIX}/include/harfbuzz"
export XCFLAGS="${CFLAGS}"
export XLIBS="${LIBS} -lmujs -llcms2 -lgumbo"
export USE_SYSTEM_LIBS=yes
export USE_SYSTEM_JPEGXR=yes
export VENV_FLAG=""

# diagnostics
#ls -lh ${PREFIX}/lib

# build and install
make prefix="${PREFIX}" -j ${CPU_COUNT} all

# no make check
make prefix="${PREFIX}" install

# build and install
make prefix="${PREFIX}" -j ${CPU_COUNT} c++

# build and install
# make prefix="${PREFIX}" install-shared-c++
