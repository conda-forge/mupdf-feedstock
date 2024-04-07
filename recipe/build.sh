#!/usr/bin/env bash
set -ex

# build system uses non-standard env vars
uname=$(uname)
if [[ "$target_platform" == osx* ]]; then
  export OS="MACOS"
  #export LIBS="${LIBS} -L${PREFIX}/lib -v"
  #export LDFLAGS="${LDFLAGS} -L${PREFIX}/lib -v"
  export CFLAGS="${CFLAGS} -I ${PREFIX}/include/freetype2"
  export CFLAGS="${CFLAGS} -I $(ls -d ${PREFIX}/include/openjpeg-*)"
  #export SYS_FREETYPE_LIBS=" -lfreetype"
  #export SYS_FREETYPE_CFLAGS="${CFLAGS}"
else:
  export OS="Linux"
fi
export CFLAGS="${CFLAGS} -I ${PREFIX}/include/harfbuzz"
export XCFLAGS="${CFLAGS}"
export XLIBS="${LIBS} -lmujs -llcms2 -lgumbo"
export USE_SYSTEM_LIBS=yes
export USE_SYSTEM_JPEGXR=yes

# diagnostics
#ls -lh ${PREFIX}/lib

# build and install
make prefix="${PREFIX}" USE_SYSTEM_LIBS=yes -j ${CPU_COUNT} all
# no make check
make prefix="${PREFIX}" install
