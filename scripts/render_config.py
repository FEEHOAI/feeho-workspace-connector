#!/usr/bin/env python3
"""Render a machine-specific, secret-free LobeHub mcpServers configuration."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVER_ID = "feeho-employee-trial"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--python", default=str(ROOT / ".venv" / "bin" / "python"))
    parser.add_argument("--output", default=str(ROOT / "lobehub" / "mcpServers.local.json"))
    args = parser.parse_args()

    template_path = ROOT / "lobehub" / "mcpServers.template.json"
    config = json.loads(template_path.read_text(encoding="utf-8"))
    server = config["mcpServers"][SERVER_ID]
    server["command"] = str(Path(args.python).expanduser().absolute())
    server["args"] = [str(ROOT / "server.py")]
    server["env"]["FEEHO_EMPLOYEE_PACKAGE"] = str(ROOT / "employee" / "inquiry-triage")
    server["env"]["FEEHO_REPORT_DIR"] = str(ROOT / "reports")

    paths = [("command", server["command"])]
    paths.extend((f"args[{index}]", value) for index, value in enumerate(server["args"]))
    for label, value in paths:
        if not Path(value).is_absolute():
            raise ValueError(f"LobeHub {label} must be an absolute path: {value}")
    for name, value in server["env"].items():
        if name.startswith("FEEHO_") and not Path(value).is_absolute():
            raise ValueError(f"{name} must be an absolute path: {value}")

    output = Path(args.output).expanduser().absolute()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
