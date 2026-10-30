#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run_flutter.sh [--device <id>] [-- <flutter-run arguments>]

Runs this worktree's Flutter app with isolated local ports and --print-dtd.
The default device is Chrome.
EOF
}

device=chrome
while (( $# > 0 )); do
  case $1 in
    --device|-d)
      (( $# >= 2 )) || { usage >&2; exit 64; }
      device=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

repository_root=$(git rev-parse --show-toplevel)
app_directory="$repository_root/app"
[[ -d "$app_directory" ]] || {
  printf 'Flutter app directory not found: %s\n' "$app_directory" >&2
  exit 66
}

read -r web_port browser_debug_port vm_service_port dds_port < <(
  python3 - "$repository_root" <<'PY'
import hashlib
import socket
import sys

seed = int(hashlib.sha256(sys.argv[1].encode()).hexdigest()[:8], 16)
first = 20000 + (seed % 5000) * 4

for offset in range(0, 5000 * 4, 4):
    candidate = 20000 + ((first - 20000 + offset) % (5000 * 4))
    sockets = []
    try:
        for port in range(candidate, candidate + 4):
            listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            listener.bind(('127.0.0.1', port))
            sockets.append(listener)
    except OSError:
        pass
    else:
        print(candidate, candidate + 1, candidate + 2, candidate + 3)
        sys.exit(0)
    finally:
        for listener in sockets:
            listener.close()

raise SystemExit('No free port range is available between 20000 and 39999.')
PY
)

printf 'Worktree: %s\n' "$repository_root"
printf 'Ports: web=%s browser-debug=%s vm-service=%s dds=%s\n' \
  "$web_port" "$browser_debug_port" "$vm_service_port" "$dds_port"

arguments=(
  run
  --print-dtd
  --device-id "$device"
  --host-vmservice-port "$vm_service_port"
  --dds-port "$dds_port"
)

if [[ "$device" == chrome || "$device" == web-server ]]; then
  arguments+=(
    --web-hostname 127.0.0.1
    --web-port "$web_port"
  )
fi

if [[ "$device" == chrome ]]; then
  arguments+=(--web-browser-debug-port "$browser_debug_port")
fi

cd "$app_directory"
exec flutter "${arguments[@]}" "$@"
