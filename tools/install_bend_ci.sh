#!/bin/sh
# Hermetic Bend install for CI: pinned version, pinned sha256, no telemetry.
# Mirrors https://bend-lang.com/install.sh but never floats to a newer release.
set -eu

VER="2.0.40"
SHA_LINUX_X64="c9ff8d67bd903fb6ad9a26b43d8a62c01021de82a44d55ce4a3dcd4732113d6b"
SHA_LINUX_ARM64="2f42a6fa34ecdaa71ae105e5fa734f9a07e129d333e45448ab6d2ff03a837570"
SHA_DARWIN_X64="9229c8bdd0a93f63fa45cc5af5e9e56389ebb620d655920915daf966c6ca561c"
SHA_DARWIN_ARM64="b2be003b041eb6cfc65326be18f79eb2e0bae2189be79a18c507e661b4b6900b"

case $(uname -s)-$(uname -m) in
  Linux-x86_64) os=linux; arch=x64; sum=$SHA_LINUX_X64;;
  Linux-aarch64|Linux-arm64) os=linux; arch=arm64; sum=$SHA_LINUX_ARM64;;
  Darwin-x86_64) os=darwin; arch=x64; sum=$SHA_DARWIN_X64;;
  Darwin-arm64) os=darwin; arch=arm64; sum=$SHA_DARWIN_ARM64;;
  *) echo "unsupported CI platform: $(uname -s)-$(uname -m)" >&2; exit 1;;
esac

home=${BEND_HOME:-$HOME/.bend}
name="bend-$VER-$os-$arch.tar.gz"
url="https://github.com/bendlang/bend/releases/download/v$VER/$name"

if [ -x "$home/bin/bend" ] && [ "$("$home/bin/bend" version 2>/dev/null | head -1)" != "" ]; then
  echo "bend already installed at $home/bin/bend"
else
  mkdir -p "$home/bin"
  tmp=$(mktemp -d "$home/tmp.XXXXXX")
  trap 'rm -rf "$tmp"' EXIT
  echo "downloading $url"
  curl --proto '=https' --tlsv1.2 -fsSL -o "$tmp/$name" "$url"
  echo "$sum  $tmp/$name" | sha256sum -c - >/dev/null 2>&1 \
    || echo "$sum  $tmp/$name" | shasum -a 256 -c -
  tar -xzf "$tmp/$name" -C "$tmp"
  rm -rf "$home/bend2" "$home/guide"
  mv "$tmp/bend/bend2" "$tmp/bend/guide" "$home/"
  mv -f "$tmp/bend/bin/bend" "$home/bin/bend"
fi

"$home/bin/bend" version 2>/dev/null || echo "bend $VER installed"
