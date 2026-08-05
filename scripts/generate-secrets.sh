#!/usr/bin/env bash
# Generate Syncthing device secrets (device certificate + key) for one or more
# devices and store them as plaintext PEM files.
#
# USAGE:
#   scripts/generate-secrets.sh [OPTIONS] DEVICE...
#
# OPTIONS:
#   --out-dir DIR   directory that receives DIR/<DEVICE>/{cert.pem,key.pem}
#                   (default: ./secrets)
#   --force         regenerate, overwriting existing secrets
#   -h, --help      show this help
#
# For every device the script prints one line:
#
#   <DEVICE> <DEVICE-ID>
#
# so the ids can be pasted into example/ids.nix.
#
# The https cert/key used by the syncthing web GUI are deliberately not
# generated here: syncthing creates them on first start if they are missing.
#
# Requires `syncthing` in PATH.
set -euo pipefail

out_dir="secrets"
force=0
devices=()

usage() {
  cat <<EOF
Generate Syncthing device secrets (device certificate + key) for one or more
devices and store them as plaintext PEM files.

USAGE:
  scripts/generate-secrets.sh [OPTIONS] DEVICE...

OPTIONS:
  --out-dir DIR   directory that receives DIR/<DEVICE>/{cert.pem,key.pem}
                  (default: ./secrets)
  --force         regenerate, overwriting existing secrets
  -h, --help      show this help

For every device the script prints one line:

  <DEVICE> <DEVICE-ID>

so the ids can be pasted into example/ids.nix.

The https cert/key used by the syncthing web GUI are deliberately not
generated here: syncthing creates them on first start if they are missing.

Requires 'syncthing' in PATH.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      [[ $# -ge 2 ]] || {
        echo "error: --out-dir requires an argument" >&2
        exit 1
      }
      out_dir="$2"
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      devices+=("$@")
      break
      ;;
    -?*)
      echo "error: unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      devices+=("$1")
      shift
      ;;
  esac
done

if [[ ${#devices[@]} -eq 0 ]]; then
  echo "error: at least one DEVICE name is required" >&2
  usage
  exit 1
fi

if ! command -v syncthing >/dev/null 2>&1; then
  echo "error: 'syncthing' was not found in PATH" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

for device in "${devices[@]}"; do
  target="${out_dir}/${device}"
  if [[ -f "${target}/cert.pem" && -f "${target}/key.pem" && ${force} -eq 0 ]]; then
    echo "skipping ${device}: secrets already exist in ${target} (use --force to regenerate)" >&2
    id="$(syncthing device-id -H "${target}")"
    echo "${device} ${id}"
    continue
  fi

  mkdir -p "${workdir}/${device}"
  syncthing generate -H "${workdir}/${device}" --no-port-probing >/dev/null
  mkdir -p "${target}"
  install -m 600 "${workdir}/${device}/cert.pem" "${target}/cert.pem"
  install -m 600 "${workdir}/${device}/key.pem" "${target}/key.pem"

  id="$(syncthing device-id -H "${target}")"
  echo "${device} ${id}"
done
