from __future__ import annotations

import argparse
from collections.abc import Callable
from pathlib import Path
import subprocess
import sys
import time


Runner = Callable[[list[str]], subprocess.CompletedProcess[bytes]]
Sleeper = Callable[[float], None]


def _run_gh(command: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def fetch_with_retry(
    endpoint: str,
    output: Path,
    *,
    attempts: int = 5,
    delay_seconds: float = 1.0,
    runner: Runner = _run_gh,
    sleeper: Sleeper = time.sleep,
) -> None:
    if attempts <= 0:
        raise ValueError("attempts must be positive")
    if delay_seconds < 0:
        raise ValueError("delay_seconds must not be negative")

    output.unlink(missing_ok=True)
    temporary_output = output.with_name(f".{output.name}.tmp")
    temporary_output.unlink(missing_ok=True)
    last_stderr = b""

    try:
        for attempt in range(1, attempts + 1):
            result = runner(["gh", "api", endpoint])
            if result.returncode == 0:
                temporary_output.write_bytes(result.stdout)
                temporary_output.replace(output)
                return

            last_stderr = result.stderr
            if attempt < attempts:
                sleeper(delay_seconds * attempt)
    finally:
        temporary_output.unlink(missing_ok=True)

    output.unlink(missing_ok=True)
    detail = last_stderr.decode("utf-8", errors="replace").strip()
    message = f"GitHub API fetch failed after {attempts} attempts: {endpoint}"
    if detail:
        message = f"{message}: {detail}"
    raise RuntimeError(message)


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fetch a GitHub Actions artifact API endpoint with bounded retry."
    )
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--attempts", type=int, default=5)
    parser.add_argument("--delay-seconds", type=float, default=1.0)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    try:
        fetch_with_retry(
            args.endpoint,
            args.output,
            attempts=args.attempts,
            delay_seconds=args.delay_seconds,
        )
    except (OSError, RuntimeError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
