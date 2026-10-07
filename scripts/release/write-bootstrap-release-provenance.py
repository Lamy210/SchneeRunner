#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from bootstrap_release_provenance import build_bootstrap_provenance


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Write canonical v0.1.0 bootstrap release provenance.")
    parser.add_argument("--repository", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--workflow-run-id", required=True, type=int)
    parser.add_argument("--workflow-run-attempt", required=True, type=int)
    parser.add_argument("--dmg-path", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        document = build_bootstrap_provenance(
            repository=args.repository,
            source_sha=args.source_sha,
            tag=args.tag,
            version=args.version,
            workflow_run_id=args.workflow_run_id,
            workflow_run_attempt=args.workflow_run_attempt,
            dmg_path=args.dmg_path,
        )
        if args.output.is_symlink():
            raise ValueError("output must not be a symlink")
        if args.output.exists() and not args.output.is_file():
            raise ValueError("output must be a regular file")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(document, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    except (OSError, ValueError) as error:
        print(f"bootstrap provenance write failed: {error}", file=__import__("sys").stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
