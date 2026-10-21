#!/usr/bin/env python3
"""Compile and run every Verilog testbench in this repository.

The runner uses only the Python standard library plus the external Icarus
Verilog tools (iverilog and vvp). Each testbench is compiled with all RTL
sources, while ``-s`` selects the testbench module as the simulation top.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
RTL_DIRECTORY = REPOSITORY_ROOT / "rtl"
TESTBENCH_DIRECTORY = REPOSITORY_ROOT / "tb"
BUILD_DIRECTORY = REPOSITORY_ROOT / "build" / "regression"
PASS_PATTERN = re.compile(r"\bPASS(?:ED)?\b", re.IGNORECASE)
FAIL_PATTERN = re.compile(r"\bFAIL(?:ED|URE)?\b", re.IGNORECASE)


@dataclass
class TestResult:
    name: str
    status: str
    detail: str


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run the complete Icarus Verilog regression suite."
    )
    parser.add_argument(
        "tests",
        nargs="*",
        metavar="TEST",
        help="Run selected testbench names (with or without the .v suffix).",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List discovered testbenches without running them.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print complete compile and simulation output for every test.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=60.0,
        help="Simulation timeout per test in seconds (default: 60).",
    )
    return parser.parse_args()


def discover_testbenches() -> dict[str, Path]:
    testbenches = {}
    for path in sorted(TESTBENCH_DIRECTORY.rglob("*_tb.v")):
        testbenches[path.stem] = path
    return testbenches


def select_testbenches(
    discovered: dict[str, Path], requested: list[str]
) -> list[tuple[str, Path]]:
    if not requested:
        return sorted(discovered.items())

    selected = []
    unknown = []
    for raw_name in requested:
        name = Path(raw_name).stem
        path = discovered.get(name)
        if path is None:
            unknown.append(raw_name)
        else:
            selected.append((name, path))

    if unknown:
        available = ", ".join(sorted(discovered))
        raise ValueError(
            f"unknown testbench(s): {', '.join(unknown)}\nAvailable: {available}"
        )
    return selected


def run_process(command: list[str], timeout: float | None = None) -> tuple[int, str]:
    try:
        completed = subprocess.run(
            command,
            cwd=REPOSITORY_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            check=False,
        )
        return completed.returncode, completed.stdout
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        return 124, output + f"\nSimulation exceeded {timeout:g} seconds.\n"


def write_log(name: str, phase: str, output: str) -> Path:
    log_path = BUILD_DIRECTORY / f"{name}.{phase}.log"
    log_path.write_text(output, encoding="utf-8")
    return log_path


def run_testbench(
    name: str,
    testbench: Path,
    rtl_sources: list[Path],
    iverilog: str,
    vvp: str,
    timeout: float,
    verbose: bool,
) -> TestResult:
    executable = BUILD_DIRECTORY / f"{name}.vvp"
    compile_command = [
        iverilog,
        "-g2012",
        "-s",
        name,
        "-o",
        str(executable),
        *(str(path) for path in rtl_sources),
        str(testbench),
    ]

    compile_code, compile_output = run_process(compile_command)
    compile_log = write_log(name, "compile", compile_output)
    if verbose and compile_output:
        print(compile_output, end="" if compile_output.endswith("\n") else "\n")
    if compile_code != 0:
        return TestResult(name, "COMPILE-FAIL", str(compile_log.relative_to(REPOSITORY_ROOT)))

    simulation_code, simulation_output = run_process(
        [vvp, str(executable)], timeout=timeout
    )
    simulation_log = write_log(name, "simulation", simulation_output)
    if verbose and simulation_output:
        print(simulation_output, end="" if simulation_output.endswith("\n") else "\n")

    has_pass = PASS_PATTERN.search(simulation_output) is not None
    has_fail = FAIL_PATTERN.search(simulation_output) is not None
    if simulation_code == 124:
        status = "TIMEOUT"
    elif simulation_code != 0 or has_fail or not has_pass:
        status = "FAIL"
    else:
        status = "PASS"

    detail = "" if status == "PASS" else str(simulation_log.relative_to(REPOSITORY_ROOT))
    return TestResult(name, status, detail)


def main() -> int:
    arguments = parse_arguments()
    discovered = discover_testbenches()

    if arguments.list:
        for name, path in sorted(discovered.items()):
            print(f"{name:<40} {path.relative_to(REPOSITORY_ROOT)}")
        return 0

    try:
        selected = select_testbenches(discovered, arguments.tests)
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    if not selected:
        print("error: no testbenches were found", file=sys.stderr)
        return 2

    iverilog = shutil.which("iverilog")
    vvp = shutil.which("vvp")
    if not iverilog or not vvp:
        print(
            "error: iverilog and vvp must both be available on PATH",
            file=sys.stderr,
        )
        return 2

    rtl_sources = sorted(RTL_DIRECTORY.rglob("*.v"))
    if not rtl_sources:
        print("error: no RTL sources were found", file=sys.stderr)
        return 2

    if BUILD_DIRECTORY.exists():
        shutil.rmtree(BUILD_DIRECTORY)
    BUILD_DIRECTORY.mkdir(parents=True)

    results = []
    for name, path in selected:
        print(f"[RUN ] {name}")
        result = run_testbench(
            name,
            path,
            rtl_sources,
            iverilog,
            vvp,
            arguments.timeout,
            arguments.verbose,
        )
        results.append(result)
        suffix = f" ({result.detail})" if result.detail else ""
        status_label = f"[{result.status}]"
        print(f"{status_label:<15} {name}{suffix}")

    passed = sum(result.status == "PASS" for result in results)
    failed = len(results) - passed
    print("\nRegression summary")
    print(f"  Total : {len(results)}")
    print(f"  Passed: {passed}")
    print(f"  Failed: {failed}")
    print(f"  Logs  : {BUILD_DIRECTORY.relative_to(REPOSITORY_ROOT)}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
