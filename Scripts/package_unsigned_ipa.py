#!/usr/bin/env python3
"""Package an existing iOS .app bundle into an unsigned IPA container."""

from __future__ import annotations

import argparse
import os
import plistlib
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create an unsigned .ipa from an existing .app bundle."
    )
    parser.add_argument("--app", required=True, help="Path to the .app bundle.")
    parser.add_argument("--output", required=True, help="Output .ipa path.")
    parser.add_argument("--overwrite", action="store_true", help="Replace output if it exists.")
    return parser.parse_args()


def validate_app(app: Path) -> dict:
    if not app.exists():
        raise SystemExit(f"App bundle not found: {app}")
    if not app.is_dir():
        raise SystemExit(f"App path is not a directory: {app}")
    if app.suffix != ".app":
        raise SystemExit(f"App bundle must end with .app: {app}")

    info_plist = app / "Info.plist"
    if not info_plist.exists():
        raise SystemExit(f"Info.plist not found: {info_plist}")

    try:
        with info_plist.open("rb") as handle:
            info = plistlib.load(handle)
    except Exception as exc:
        raise SystemExit(f"Could not parse Info.plist: {exc}") from exc

    executable = info.get("CFBundleExecutable")
    if executable and not (app / executable).exists():
        raise SystemExit(f"CFBundleExecutable is missing from bundle: {executable}")

    return info


def copy_app(src: Path, dst: Path) -> None:
    shutil.copytree(
        src,
        dst,
        symlinks=True,
        ignore=shutil.ignore_patterns("*.dSYM", "*.xcarchive", "__MACOSX", ".DS_Store"),
    )


def zip_directory(source_dir: Path, output: Path) -> None:
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as ipa:
        for path in source_dir.rglob("*"):
            if path.is_dir():
                continue
            ipa.write(path, path.relative_to(source_dir).as_posix())


def main() -> int:
    args = parse_args()
    app = Path(args.app).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    info = validate_app(app)

    if output.exists() and not args.overwrite:
        raise SystemExit(f"Output already exists. Use --overwrite: {output}")

    output.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="ipa_payload_") as tmp:
        root = Path(tmp)
        payload = root / "Payload"
        payload.mkdir()
        copy_app(app, payload / app.name)

        temp_output = output.with_suffix(output.suffix + ".tmp")
        if temp_output.exists():
            temp_output.unlink()
        zip_directory(root, temp_output)
        os.replace(temp_output, output)

    print(f"Created unsigned IPA: {output}")
    print(f"Bundle ID: {info.get('CFBundleIdentifier', 'unknown')}")
    print(f"Version: {info.get('CFBundleShortVersionString', 'unknown')} ({info.get('CFBundleVersion', 'unknown')})")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Cancelled", file=sys.stderr)
        raise SystemExit(130)

