#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${FEEHO_VENV:-$ROOT/.venv}"
if [[ "$VENV_DIR" != /* ]]; then
  VENV_DIR="$ROOT/$VENV_DIR"
fi

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  printf 'error: Python 3.10+ is required (PYTHON_BIN=%s)\n' "$PYTHON_BIN" >&2
  exit 2
fi

SOURCE="${FEEHO_EMPLOYEE_SOURCE:-}"
if [[ -z "$SOURCE" ]]; then
  candidates=(
    "$ROOT/../feeho-next/work/feeho-runtime/feeho-employee"
    "$ROOT/../feeho-employee"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate/pyproject.toml" && -f "$candidate/src/feeho_employee/cli.py" ]]; then
      SOURCE="$candidate"
      break
    fi
  done
fi

if [[ -n "$SOURCE" && "$SOURCE" != "github" && ! -f "$SOURCE/pyproject.toml" ]]; then
  printf 'error: FEEHO_EMPLOYEE_SOURCE is not a feeho-employee source directory: %s\n' "$SOURCE" >&2
  exit 2
fi

export PYTHONDONTWRITEBYTECODE=1
export PIP_DISABLE_PIP_VERSION_CHECK=1
if [[ -z "${PIP_CERT:-}" && -f /etc/ssl/cert.pem ]]; then
  export PIP_CERT=/etc/ssl/cert.pem
fi

printf 'Creating virtual environment: %s\n' "$VENV_DIR"
"$PYTHON_BIN" -m venv "$VENV_DIR"
VENV_PYTHON="$VENV_DIR/bin/python"
"$VENV_PYTHON" -m pip install -r "$ROOT/requirements.txt"

if [[ -n "$SOURCE" && "$SOURCE" != "github" ]]; then
  # setuptools can update egg-info even for non-editable installs; build from a copy.
  printf 'Installing local feeho-employee copy via an isolated build: %s\n' "$SOURCE"
  BUILD_COPY="$(mktemp -d "${TMPDIR:-/tmp}/feeho-employee-install.XXXXXX")"
  trap 'rm -rf "$BUILD_COPY"' EXIT
  cp -R "$SOURCE" "$BUILD_COPY/feeho-employee"
  "$VENV_PYTHON" -m pip install "$BUILD_COPY/feeho-employee"
else
  printf 'Installing feeho-employee from GitHub.\n'
  "$VENV_PYTHON" -m pip install 'feeho-employee @ git+https://github.com/ARAZERX/feeho-employee.git'
fi

"$VENV_DIR/bin/feeho" validate "$ROOT/employee/inquiry-triage"
"$VENV_PYTHON" "$ROOT/scripts/render_config.py" --python "$VENV_PYTHON"

cat <<EOF

FEEHO MCP installation is ready.
Import this file in LobeHub Desktop:
  $ROOT/lobehub/mcpServers.local.json
Then create an Agent with:
  $ROOT/agent/system-prompt.md

No model provider key was read or written. Configure your own key only in LobeHub.
EOF
