"""Repeatable Godot QA. Uses isolated test saves, never the active campaign."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
SUITES = [
    "controls_integration", "physics", "combat", "presentation", "v2_integration",
    "save_compatibility", "smoke", "narrative", "refuge", "opening",
    "platforming", "premium",
]
VISUAL = ["production_preview", "preview", "v2_visual", "platform_preview", "restart", "render_benchmark"]


def main():
    parser = argparse.ArgumentParser(description="Verify Verdaria gameplay and optional rendered captures.")
    parser.add_argument("--visual", action="store_true", help="Also render captures, check sprite mirroring and measure frame times")
    args = parser.parse_args()
    engine = ROOT / "build/runtime/Verdaria_console.exe"
    if not engine.exists():
        # GODOT lo define comandos/_godot.cmd; también puede fijarse a mano.
        installed = os.environ.get("GODOT") or shutil.which("godot") or shutil.which("godot4")
        if not installed or not Path(installed).exists() and not shutil.which(installed):
            parser.error("Godot is missing. Set GODOT, restore build/runtime or install Godot 4.7.")
        engine = Path(installed)
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    results = []
    for name in SUITES + (VISUAL if args.visual else []):
        graphical = name in VISUAL
        command = [str(engine), "--path", str(ROOT), "--script", f"res://tests/{name}.gd"]
        command += ["--resolution", "1280x800"] if graphical else ["--headless", "--fixed-fps", "60"]
        started = time.monotonic()
        try:
            process = subprocess.run(
                command, cwd=ROOT, capture_output=True, encoding="utf-8", errors="replace",
                timeout=90, creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
            )
            output = process.stdout + process.stderr
            passed = process.returncode == 0 and not re.search(r"(?m)^(SCRIPT ERROR|ERROR):", output)
            result = {"suite": name, "passed": passed, "exit_code": process.returncode}
        except subprocess.TimeoutExpired:
            output = "TIMEOUT: Godot did not complete this suite in 90 seconds.\n"
            result = {"suite": name, "passed": False, "timeout": True}
        result["seconds"] = round(time.monotonic() - started, 2)
        (build / f"qa_{name}.log").write_text(output, encoding="utf-8")
        results.append(result)
        print(f"{'PASS' if result['passed'] else 'FAIL'}  {name}  ({result['seconds']} s)", flush=True)
    summary = {"all_passed": all(result["passed"] for result in results), "results": results}
    (build / "qa_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(f"\n{sum(result['passed'] for result in results)}/{len(results)} checks passed. Report: build/qa_summary.json")
    return 0 if summary["all_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
