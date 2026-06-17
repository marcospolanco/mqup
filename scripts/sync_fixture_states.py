#!/usr/bin/env python3
"""Sync fixture expected states from live SearchCoordinator via MQUPEval."""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    eval_bin = ROOT / ".build" / "debug" / "MQUPEval"
    if not eval_bin.exists():
        subprocess.run(["swift", "build"], cwd=ROOT, check=True)
    subprocess.run([str(eval_bin), "--sync-fixtures"], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
