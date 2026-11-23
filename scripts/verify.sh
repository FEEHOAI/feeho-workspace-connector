#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
EVIDENCE="$ROOT/evidence"
mkdir -p "$EVIDENCE"
export PYTHONDONTWRITEBYTECODE=1

REFERENCE="${FEEHO_EMPLOYEE_ROOT:-$ROOT/../feeho-next/work/feeho-runtime/feeho-employee}"
if [[ ! -f "$REFERENCE/tests/test_employee.py" ]]; then
  printf 'error: set FEEHO_EMPLOYEE_ROOT to the feeho-employee source directory\n' >&2
  exit 2
fi

if [[ -n "${FEEHO_TEST_PYTHON:-}" ]]; then
  PYTHON="$FEEHO_TEST_PYTHON"
elif [[ -x "$ROOT/.venv/bin/python" ]]; then
  PYTHON="$ROOT/.venv/bin/python"
else
  PYTHON="$REFERENCE/../.venv/bin/python"
fi
if [[ ! -x "$PYTHON" ]]; then
  printf 'error: test Python not found: %s\n' "$PYTHON" >&2
  exit 2
fi

printf '\n== 1. Upstream feeho-employee unit tests (9) ==\n'
"$PYTHON" -m unittest discover -s "$REFERENCE/tests" -v 2>&1 | tee "$EVIDENCE/upstream-unit-tests.log"

printf '\n== 2. Unmodified upstream example and sample-results ==\n'
"$PYTHON" -m feeho_employee.cli test "$REFERENCE/examples/inquiry-triage" \
  --results "$REFERENCE/examples/sample-results.json" \
  --report "$EVIDENCE/upstream-sample-report.json" 2>&1 | tee "$EVIDENCE/upstream-sample.log"

printf '\n== 3. Bundled MCP-safe example and sample-results ==\n'
"$PYTHON" -m feeho_employee.cli test "$ROOT/employee/inquiry-triage" \
  --results "$ROOT/examples/sample-results.mcp.json" \
  --report "$EVIDENCE/mcp-sample-report.json" 2>&1 | tee "$EVIDENCE/mcp-sample.log"

printf '\n== 4. MCP credential-isolation unit test ==\n'
"$PYTHON" "$ROOT/tests/test_server_unit.py" 2>&1 | tee "$EVIDENCE/mcp-unit-tests.log"

printf '\n== 5. Real stdio JSON-RPC initialize/tools/list/tools/call ==\n'
FEEHO_TEST_PYTHON="$PYTHON" "$PYTHON" "$ROOT/tests/test_mcp_e2e.py" 2>&1 | tee "$EVIDENCE/mcp-e2e.log"

printf '\n== 6. Custom requirement, isolated trials and real CLI acceptance ==\n'
FEEHO_TEST_PYTHON="$PYTHON" "$PYTHON" "$ROOT/tests/test_custom_trial_e2e.py" 2>&1 | tee "$EVIDENCE/custom-trial-e2e.log"

printf '\nAll local verification steps passed. No live LobeHub/model/cloud result is claimed.\n'
