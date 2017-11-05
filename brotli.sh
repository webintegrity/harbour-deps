#!/bin/sh -ex

# Copyright 2017 Viktor Szakats <https://github.com/vszakats>
# See LICENSE.md

export _NAM
export _VER
export _BAS
export _DST

_NAM="$(basename "$0")"
_NAM="$(echo "${_NAM}" | cut -f 1 -d '.')"
_VER="$1"
_cpu="$2"

(
  cd "${_NAM}" || exit

  # Build

  rm -fr CMakeFiles
  rm -f CMakeCache.txt

  find . -name '*.o'   -type f -delete
  find . -name '*.a'   -type f -delete
  find . -name '*.lo'  -type f -delete
  find . -name '*.la'  -type f -delete
  find . -name '*.lai' -type f -delete
  find . -name '*.Plo' -type f -delete
  find . -name '*.pc'  -type f -delete

  unset CC

  _CFLAGS="-static-libgcc -m${_cpu} -fno-ident -DMINGW_HAS_SECURE_API"
  [ "${_BRANCH#*extmingw*}" = "${_BRANCH}" ] && [ "${_cpu}" = '32' ] && _CFLAGS="${_CFLAGS} -fno-asynchronous-unwind-tables"

  cmake . \
    -DCMAKE_SYSTEM_NAME='Windows' \
    -DCMAKE_C_COMPILER="${_TRIPLET}-gcc" \
    -DCMAKE_CXX_COMPILER="${_TRIPLET}-g++" \
    -DCMAKE_C_FLAGS="${_CFLAGS}" \
    -DCMAKE_INSTALL_PREFIX='/usr/local' \
    -DCMAKE_INSTALL_LIBDIR='lib'
  make
  make install "DESTDIR=$(pwd)/pkg" > /dev/null

  # DESTDIR= + CMAKE_INSTALL_PREFIX
  _pkg='pkg/usr/local'

  # Remove '-static' suffixes from static lib names to make these behave
  # like other most other projects do.

  for fn in ${_pkg}/lib/*-static.a; do mv "${fn}" "$(echo "${fn}" | sed 's|-static||')"; done

  # Make steps for determinism

  readonly _ref='docs/brotli.1'

  "${_CCPREFIX}strip" -p --enable-deterministic-archives -g ${_pkg}/lib/*.a
  "${_CCPREFIX}strip" -p -s ${_pkg}/bin/*.exe
  "${_CCPREFIX}strip" -p -s ${_pkg}/bin/*.dll

  ../_peclean.py "${_ref}" './*.exe'
  ../_peclean.py "${_ref}" './*.dll'

  ../_sign.sh './*.exe'
  ../_sign.sh './*.dll'

  touch -c -r "${_ref}" ${_pkg}/bin/*.exe
  touch -c -r "${_ref}" ${_pkg}/bin/*.dll
  touch -c -r "${_ref}" ${_pkg}/lib/pkgconfig/*.pc
  touch -c -r "${_ref}" ${_pkg}/lib/*.a

  # Tests

  "${_CCPREFIX}objdump" -x ${_pkg}/bin/*.exe | grep -E -i "(file format|dll name)"
  "${_CCPREFIX}objdump" -x ${_pkg}/bin/*.dll | grep -E -i "(file format|dll name)"

  # Create package

  _BAS="${_NAM}-${_VER}-win${_cpu}-mingw"
  _DST="$(mktemp -d)/${_BAS}"

  mkdir -p "${_DST}"
  mkdir -p "${_DST}/bin"
  mkdir -p "${_DST}/lib/pkgconfig"
  mkdir -p "${_DST}/include/brotli"

  cp -f -p ${_pkg}/include/brotli/*.h "${_DST}/include/brotli/"
  cp -f -p ${_pkg}/bin/*.exe          "${_DST}/bin/"
  cp -f -p ${_pkg}/bin/*.dll          "${_DST}/bin/"
  cp -f -p ${_pkg}/lib/pkgconfig/*.pc "${_DST}/lib/pkgconfig/"
  cp -f -p ${_pkg}/lib/*.a            "${_DST}/lib/"
  cp -f -p README.md                  "${_DST}/README.md"

  unix2dos -k "${_DST}"/*.md

  ../_pack.sh "$(pwd)/${_ref}"
  ../_ul.sh
)
