#!/usr/bin/env bash
# uninstall-any-system-node + install Node.js v20.17.0 on Ubuntu 22.04
# - Removes APT and Snap installs of nodejs (and their config files)
# - Installs exact version 20.17.0 from nodejs.org binaries (x64/arm64/armv7l)
# - Verifies download via official SHASUMS
# - Creates /usr/local/bin symlinks for node, npm, npx, corepack

set -Eeuo pipefail

VERSION="20.17.0"

# Auto-escalate to root if needed
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

# Map machine arch to Node's archive naming
uname_arch="$(uname -m)"
case "$uname_arch" in
  x86_64)  NODE_ARCH="x64" ;;
  aarch64) NODE_ARCH="arm64" ;;
  armv7l)  NODE_ARCH="armv7l" ;;
  *)
    echo "Unsupported CPU architecture: ${uname_arch}. Supported: x86_64, aarch64, armv7l." >&2
    exit 1
    ;;
esac

echo "==> Purging any APT-installed Node.js/npm..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
# Purge removes packages + their config files
apt-get purge -y nodejs npm || true
apt-get autoremove -y
apt-get autoclean -y

echo "==> Removing Snap 'node' if present..."
if command -v snap >/dev/null 2>&1; then
  if snap list 2>/dev/null | awk '{print $1}' | grep -qx node; then
    snap remove --purge node || true
  fi
fi

echo "==> Cleaning old NodeSource or custom APT repo entries (if any)..."
if [[ -d /etc/apt/sources.list.d ]]; then
  find /etc/apt/sources.list.d -maxdepth 1 -type f \
    \( -iname '*nodesource*' -o -iname '*nodejs*' \) -print -exec rm -f {} \; || true
  apt-get update -y
fi

echo "==> Removing possible stale Node symlinks in /usr/local/bin..."
for bin in node npm npx corepack; do
  [[ -e "/usr/local/bin/$bin" || -L "/usr/local/bin/$bin" ]] && rm -f "/usr/local/bin/$bin"
done

echo "==> Ensuring required tools are installed (curl, xz, certs)..."
apt-get install -y curl xz-utils ca-certificates

echo "==> Downloading Node.js v${VERSION} for ${NODE_ARCH} from nodejs.org..."
TMPDIR="$(mktemp -d)"
cd "$TMPDIR"
TARBALL="node-v${VERSION}-linux-${NODE_ARCH}.tar.xz"
BASEURL="https://nodejs.org/dist/v${VERSION}"
curl -fsSLO "${BASEURL}/${TARBALL}"
curl -fsSLO "${BASEURL}/SHASUMS256.txt"

echo "==> Verifying SHA-256 checksum..."
grep " ${TARBALL}\$" SHASUMS256.txt | sha256sum -c -

echo "==> Installing to /usr/local/lib/nodejs..."
install -d -m 0755 /usr/local/lib/nodejs
tar -xJf "${TARBALL}" -C /usr/local/lib/nodejs

echo "==> Creating symlinks in /usr/local/bin (node, npm, npx, corepack)..."
NODE_DIR="/usr/local/lib/nodejs/node-v${VERSION}-linux-${NODE_ARCH}"
for bin in node npm npx corepack; do
  ln -sf "${NODE_DIR}/bin/${bin}" "/usr/local/bin/${bin}"
done

echo "==> Enabling Corepack (Yarn/pnpm shims)..."
corepack enable || true

echo "==> Verifying installation..."
hash -r || true
if /usr/local/bin/node -v | grep -qx "v${VERSION}"; then
  echo "Success: Node.js $(/usr/local/bin/node -v) installed at ${NODE_DIR}"
  echo "npm version: $(/usr/local/bin/npm -v)"
else
  echo "ERROR: Installed Node.js version does not match v${VERSION}" >&2
  exit 1
fi

echo
echo "Note: This script removes system-wide Node.js (APT/Snap)."
echo "If you use nvm (per-user), those installations are unaffected."
echo "Done."
