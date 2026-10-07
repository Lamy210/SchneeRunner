#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from bootstrap_release_provenance import validate_bootstrap_provenance


MAX_METADATA_BYTES = 64 * 1024


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify canonical v0.1.0 bootstrap release provenance.")
    parser.add_argument("--metadata", required=True, type=Path)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--dmg-path", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.metadata.is_symlink() or not args.metadata.is_file():
            raise ValueError("metadata must be a regular non-symlink file")
        if args.metadata.stat().st_size > MAX_METADATA_BYTES:
            raise ValueError("metadata exceeds size limit")
        document = json.loads(args.metadata.read_text(encoding="utf-8"))
        validate_bootstrap_provenance(
            document,
            expected_repository=args.repository,
            expected_source_sha=args.source_sha,
            expected_tag=args.tag,
            expected_version=args.version,
            dmg_path=args.dmg_path,
        )
    except (json.JSONDecodeError, OSError, ValueError) as error:
        print(f"bootstrap provenance verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
