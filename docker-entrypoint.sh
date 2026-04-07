#!/usr/bin/env bash
set -euo pipefail

MODE="${BITNET_MODE:-server}"
REPO="${BITNET_REPO:-/opt/BitNet}"
MODEL_REPO="${BITNET_MODEL_REPO:-microsoft/bitnet-b1.58-2B-4T-gguf}"
MODEL_DIR="${BITNET_MODEL_DIR:-/models/bitnet}"
QUANT_TYPE="${BITNET_QUANT_TYPE:-i2_s}"
CTX_SIZE="${BITNET_CTX_SIZE:-2048}"
THREADS="${BITNET_THREADS:-4}"
N_PREDICT="${BITNET_N_PREDICT:-512}"
TEMPERATURE="${BITNET_TEMPERATURE:-0.8}"
HOST="${BITNET_HOST:-0.0.0.0}"
PORT="${BITNET_PORT:-8080}"
HEALTH_PORT="${BITNET_HEALTH_PORT:-8081}"
PROMPT="${BITNET_PROMPT:-You are a helpful assistant.}"
STATUS_FILE="${BITNET_STATUS_FILE:-/tmp/bitnet-status.json}"
export BITNET_STATUS_FILE="$STATUS_FILE"

cd "$REPO"

if [ ! -d "$MODEL_DIR" ]; then
  mkdir -p "$MODEL_DIR"
fi

write_status() {
  local status="$1"
  local detail="${2:-}"
  python3 - "$STATUS_FILE" "$status" "$detail" "$PORT" "$MODEL_REPO" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = {
    "status": sys.argv[2],
    "detail": sys.argv[3],
    "port": int(sys.argv[4]),
    "model_repo": sys.argv[5],
}
path.write_text(json.dumps(payload))
PY
}

write_status "starting" "container booting"

python3 - <<'PY' &
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import socket
from pathlib import Path

port = int(os.environ.get("BITNET_HEALTH_PORT", "8081"))
status_path = Path(os.environ.get("BITNET_STATUS_FILE", "/tmp/bitnet-status.json"))
server_port = int(os.environ.get("BITNET_PORT", "8080"))

def read_status():
    if not status_path.exists():
        return {"status": "starting", "detail": "status file missing", "port": server_port}
    try:
        return json.loads(status_path.read_text())
    except Exception:
        return {"status": "failed", "detail": "status file unreadable", "port": server_port}

def is_server_ready():
    try:
        with socket.create_connection(("127.0.0.1", server_port), timeout=1):
            return True
    except OSError:
        return False

class Handler(BaseHTTPRequestHandler):
    def _reply(self, code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        payload = read_status()
        if self.path in ("/", "/health"):
            code = 503 if payload.get("status") == "failed" else 200
            if payload.get("status") == "ready" and not is_server_ready():
                payload["status"] = "failed"
                payload["detail"] = "server port is not reachable"
                code = 503
            self._reply(code, payload)
        elif self.path == "/ready":
            ready = payload.get("status") == "ready" and is_server_ready()
            if ready:
                self._reply(200, payload)
            else:
                if payload.get("status") == "ready":
                    payload["status"] = "starting"
                    payload["detail"] = "server is still warming up"
                self._reply(503, payload)
        else:
            self._reply(404, {"error": "not found"})

    def log_message(self, format, *args):
        return

HTTPServer(("0.0.0.0", port), Handler).serve_forever()
PY
HEALTH_PID="$!"

cleanup() {
  kill "$HEALTH_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

MODEL_NAME="$(basename "$MODEL_REPO")"
MODEL_WORK_DIR="${MODEL_DIR}/${MODEL_NAME}"

if [ ! -d "$MODEL_WORK_DIR" ]; then
  mkdir -p "$MODEL_WORK_DIR"
fi

if printf '%s' "$MODEL_REPO" | grep -q -- '-gguf$'; then
  if [ ! -f "$MODEL_WORK_DIR/ggml-model-${QUANT_TYPE}.gguf" ]; then
    write_status "downloading" "fetching gguf model artifacts"
    echo "Downloading GGUF model artifacts for ${MODEL_REPO}"
    huggingface-cli download "$MODEL_REPO" --local-dir "$MODEL_WORK_DIR"
  fi
elif [ ! -f "$MODEL_WORK_DIR/ggml-model-${QUANT_TYPE}.gguf" ]; then
  write_status "preparing" "building model artifacts from hf repository"
  echo "Preparing BitNet model artifacts for ${MODEL_REPO}"
  python3 - <<PY
import argparse
from pathlib import Path
import setup_env

setup_env.args = argparse.Namespace(
    hf_repo="${MODEL_REPO}",
    model_dir="${MODEL_DIR}",
    log_dir="logs",
    quant_type="${QUANT_TYPE}",
    quant_embd=False,
    use_pretuned=False,
)
Path(setup_env.args.log_dir).mkdir(parents=True, exist_ok=True)
setup_env.logging.basicConfig(level=setup_env.logging.INFO)
setup_env.prepare_model()
PY
fi

MODEL_FILE="${MODEL_WORK_DIR}/ggml-model-${QUANT_TYPE}.gguf"

if [ "$MODE" = "server" ]; then
  write_status "starting_server" "launching inference server"
  python3 run_inference_server.py \
    -m "$MODEL_FILE" \
    -c "$CTX_SIZE" \
    -t "$THREADS" \
    -n "$N_PREDICT" \
    --temperature "$TEMPERATURE" \
    --host "$HOST" \
    --port "$PORT" \
    -p "$PROMPT" &
  SERVER_PID="$!"

  for _ in $(seq 1 180); do
    if python3 - "$PORT" <<'PY'
import socket
import sys

port = int(sys.argv[1])
try:
    with socket.create_connection(("127.0.0.1", port), timeout=1):
        sys.exit(0)
except OSError:
    sys.exit(1)
PY
    then
      write_status "ready" "inference server is accepting connections"
      wait "$SERVER_PID"
      exit $?
    fi
    if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
      wait "$SERVER_PID"
      exit_code=$?
      write_status "failed" "inference server exited during startup"
      exit "$exit_code"
    fi
    sleep 1
  done

  write_status "failed" "server did not become ready before timeout"
  kill "$SERVER_PID" >/dev/null 2>&1 || true
  wait "$SERVER_PID" >/dev/null 2>&1 || true
  exit 1
fi

if [ "$MODE" = "cli" ]; then
  write_status "cli" "running one-shot inference"
  exec python3 run_inference.py \
    -m "$MODEL_FILE" \
    -p "$PROMPT" \
    -n "$N_PREDICT" \
    -t "$THREADS" \
    -c "$CTX_SIZE"
fi

write_status "failed" "unknown runtime mode"
echo "Unknown BITNET_MODE: $MODE" >&2
exit 1
