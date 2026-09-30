#!/usr/bin/env bash
set -euo pipefail

python -u /comfyui/main.py \
    --listen 127.0.0.1 \
    --port 8188 \
    --disable-auto-launch \
    --disable-metadata \
    --log-stdout &

comfy_pid=$!
echo "$comfy_pid" > /tmp/comfyui.pid

cleanup() {
    kill "$comfy_pid" 2>/dev/null || true
}
trap cleanup EXIT TERM INT

for attempt in $(seq 1 300); do
    if curl --fail --silent http://127.0.0.1:8188/ >/dev/null; then
        exec python -u /handler.py
    fi

    if ! kill -0 "$comfy_pid" 2>/dev/null; then
        wait "$comfy_pid"
    fi

    sleep 1
done

echo "ComfyUI did not become ready" >&2
exit 1
