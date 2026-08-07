#!/usr/bin/env bash
# Dispatch container commands for the Automated Pill Dispenser software stack.
set -euo pipefail

cmd="${1:-smoke}"
shift || true

cd /app

case "$cmd" in
  smoke|edge-smoke)
    echo "[apd] Running edge mock headless smoke..."
    cd /app/edge
    exec python pipeline.py --mode mock --headless "$@"
    ;;

  edge)
    echo "[apd] Running edge pipeline..."
    cd /app/edge
    # Default to mock if caller passes no args
    if [[ $# -eq 0 ]]; then
      exec python pipeline.py --mode mock --headless
    fi
    exec python pipeline.py "$@"
    ;;

  medallion)
    echo "[apd] Generating synthetic telemetry + local Bronze→Silver→Gold..."
    cd /app/databricks
    python generate_synthetic_telemetry.py "$@"
    exec python local_medallion.py
    ;;

  generate-telemetry)
    cd /app/databricks
    exec python generate_synthetic_telemetry.py "$@"
    ;;

  shell|bash)
    exec bash "$@"
    ;;

  python)
    exec python "$@"
    ;;

  help|-h|--help)
    cat <<'EOF'
Automated Pill Dispenser container commands:

  smoke              Edge mock headless smoke test (default)
  edge [args...]     Run edge/pipeline.py (pass --mode mock|serial etc.)
  medallion          Synthetic telemetry + local Bronze→Silver→Gold
  generate-telemetry Only write bronze JSONL sample data
  shell              Interactive bash in /app
  python [args...]   Run python in /app

Examples:
  docker compose run --rm app smoke
  docker compose run --rm app edge --mode mock --headless
  docker compose run --rm medallion
  docker compose run --rm app shell
EOF
    ;;

  *)
    echo "[apd] Unknown command: $cmd" >&2
    echo "Run with 'help' for usage." >&2
    exit 1
    ;;
esac
