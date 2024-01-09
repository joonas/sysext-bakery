#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME [NATS_VERSION]"
  echo "The script will download the wasmcloud release (e.g. 0.80.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"
NATS_VERSION="${3-latest}"

# The github release uses different arch identifiers, we map them here
# and rely on bake.sh to map them back to what systemd expects
if [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "x86-64" ]; then
  ARCH="x86_64"
  GOARCH="amd64"
elif [ "${ARCH}" = "arm64" ]; then
  ARCH="aarch64"
  GOARCH="arm64"
fi

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"/usr/bin

VERSION="v${VERSION#v}"
curl -o "${SYSEXTNAME}"/usr/bin/wasmcloud -fvSL "https://github.com/wasmcloud/wasmcloud/releases/download/${VERSION}/wasmcloud-${ARCH}-unknown-linux-musl"
chmod +x "${SYSEXTNAME}"/usr/bin/wasmcloud

# Install NATS
version="${NATS_VERSION}"
if [[ "${NATS_VERSION}" == "latest" ]]; then
  version=$(curl -fvSL https://api.github.com/repos/nats-io/nats-server/releases/latest | jq -r .tag_name)
  echo "Using latest version: ${version} for NATS Server"
fi
version="v${version#v}"

rm -f "nats-server.tar.gz"
curl -o nats-server.tar.gz -fvSL "https://github.com/nats-io/nats-server/releases/download/${version}/nats-server-${version}-linux-${GOARCH}.tar.gz"
tar -xf "nats-server.tar.gz" -C "${SYSEXTNAME}/usr/bin"
rm  "nats-server.tar.gz"

"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"

