#!/bin/sh -x

# Copyright 2015-2017 Viktor Szakats <https://github.com/vszakats>
# See LICENSE.md

export ZLIB_VER_='1.2.11'
export ZLIB_HASH=629380c90a77b964d896ed37163f5c3a34f6e6d897311f1df2a7016355c45eff
export BROTLI_VER_='1.0.1'
export BROTLI_HASH=6870f9c2c63ef58d7da36e5212a3e1358427572f6ac5a8b5a73a815cf3e0c4a6
export LIBIDN2_VER_='2.0.3'
export LIBIDN2_HASH=4335149ce7a5c615edb781574d38f658672780331064fb17354a10e11a5308cd
export NGHTTP2_VER_='1.27.0'
export NGHTTP2_HASH=e83819560952a3dc3c8d96c46f60745408f46f5f384168c90b9e3dfa53b2c2c8
export CARES_VER_='1.13.0'
export CARES_HASH=03f708f1b14a26ab26c38abd51137640cb444d3ec72380b21b20f1a8d2861da7
export LIBRESSL_VER_='2.5.5'
export LIBRESSL_HASH=e57f5e3d5842a81fe9351b6e817fcaf0a749ca4ef35a91465edba9e071dce7c4
export OPENSSL_VER_='1.1.0g'
export OPENSSL_HASH=de4d501267da39310905cb6dc8c6121f7a2cad45a7707f76df828fe1b85073af
export LIBRTMP_VER_='2.4+20151223'
export LIBRTMP_HASH=5c032f5c8cc2937eb55a81a94effdfed3b0a0304b6376147b86f951e225e3ab5
export LIBSSH2_VER_='1.8.0'
export LIBSSH2_HASH=39f34e2f6835f4b992cafe8625073a88e5a28ba78f83e8099610a7b3af4676d4
export CURL_VER_='7.56.1'
export CURL_HASH=8eed282cf3a0158d567a0feaa3c4619e8e847970597b5a2c81879e8f0d1a39d1

# Quit if any of the lines fail
set -e

# Detect host OS
case "$(uname)" in
  *_NT*)   os='win';;
  Linux*)  os='linux';;
  Darwin*) os='mac';;
  *BSD)    os='bsd';;
esac

unset _py
[ "${os}" = 'win' ] && _py='python -m'

# Install required component
# TODO: add `--progress-bar off` when pip 9.1.0 hits the drives
${_py} pip --disable-pip-version-check install --user --upgrade pip
${_py} pip install --user pefile

alias curl='curl -fsS --connect-timeout 15 --retry 3'
alias gpg='gpg --batch --keyserver-options timeout=15 --keyid-format LONG'

gpg_recv_keys() {
  req="pks/lookup?search=0x$1&op=get"
  if ! curl "https://pgp.mit.edu/${req}" | gpg --import --status-fd 1; then
    curl "https://sks-keyservers.net/${req}" | gpg --import --status-fd 1
  fi
}

gpg --version | grep gpg

if [ "${_BRANCH#*dev*}" != "${_BRANCH}" ]; then
   _patsuf='.dev'
elif [ "${_BRANCH#*master*}" = "${_BRANCH}" ]; then
   _patsuf='.test'
else
   _patsuf=''
fi

if [ "${os}" = 'win' ]; then
  if [ "${_BRANCH#*mingwext*}" != "${_BRANCH}" ]; then
    # mingw
    curl -o pack.bin -L 'https://downloads.sourceforge.net/mingw-w64/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/7.1.0/threads-posix/sjlj/x86_64-7.1.0-release-posix-sjlj-rt_v5-rev0.7z' || exit 1
    openssl dgst -sha256 pack.bin | grep -q a117ec6126c9cc31e89498441d66af3daef59439c36686e80cebf29786e17c13 || exit 1
    # Will unpack into './mingw64'
    7z x -y pack.bin > /dev/null || exit 1
    rm pack.bin
  fi
fi

# zlib
curl -o pack.bin -L --proto-redir =https "https://github.com/madler/zlib/archive/v${ZLIB_VER_}.tar.gz" || exit 1
openssl dgst -sha256 pack.bin | grep -q "${ZLIB_HASH}" || exit 1
tar -xvf pack.bin > /dev/null 2>&1 || exit 1
rm pack.bin
rm -f -r zlib && mv zlib-* zlib
[ -f "zlib${_patsuf}.patch" ] && dos2unix < "zlib${_patsuf}.patch" | patch -N -p1 -d zlib

# brotli
curl -o pack.bin -L --proto-redir =https "https://github.com/google/brotli/archive/v${BROTLI_VER_}.tar.gz" || exit 1
openssl dgst -sha256 pack.bin | grep -q "${BROTLI_HASH}" || exit 1
tar -xvf pack.bin > /dev/null 2>&1 || exit 1
rm pack.bin
rm -f -r brotli && mv brotli-* brotli
[ -f "brotli${_patsuf}.patch" ] && dos2unix < "brotli${_patsuf}.patch" | patch -N -p1 -d brotli

# curl
if [ "${_BRANCH#*dev*}" != "${_BRANCH}" ]; then
  CURL_VER_='7.57.0-dev'
  curl -o pack.bin -L --proto-redir =https https://github.com/curl/curl/archive/cc1f4436099decb9d1a7034b2bb773a9f8379d31.tar.gz || exit 1
else
  curl \
    -o pack.bin "https://curl.haxx.se/download/curl-${CURL_VER_}.tar.xz" \
    -o pack.sig "https://curl.haxx.se/download/curl-${CURL_VER_}.tar.xz.asc" || exit 1
  gpg_recv_keys 27EDEAF22F3ABCEB50DB9A125CC908FDB71E12C2
  gpg --verify-options show-primary-uid-only --verify pack.sig pack.bin || exit 1
  openssl dgst -sha256 pack.bin | grep -q "${CURL_HASH}" || exit 1
fi
tar -xvf pack.bin > /dev/null 2>&1 || exit 1
rm pack.bin
rm -f -r curl && mv curl-* curl
[ -f "curl${_patsuf}.patch" ] && dos2unix < "curl${_patsuf}.patch" | patch -N -p1 -d curl

set +e

rm -f pack.bin pack.sig
