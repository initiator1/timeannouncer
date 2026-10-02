#!/usr/bin/env python3
"""Read candidate identity and reject stale source or packaged app versions."""

import argparse
import hashlib
import json
import plistlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def identity(root=ROOT):
    project = (root / "TimeAnnouncer.xcodeproj/project.pbxproj").read_text()
    result = {}
    for field, setting in (("version", "MARKETING_VERSION"), ("build", "CURRENT_PROJECT_VERSION")):
        values = {value.strip().strip('"') for value in re.findall(rf"\b{setting}\s*=\s*([^;]+);", project)}
        if len(values) != 1:
            raise ValueError(f"{setting} must have one consistent value in all configurations")
        result[field] = values.pop()
    return result


def source_digest(root=ROOT):
    paths = list((root / "TimeAnnouncer").rglob("*"))
    paths += [root / "TimeAnnouncer.xcodeproj/project.pbxproj", root / "scripts/setup-kokoro.sh"]
    digest = hashlib.sha256()
    for path in sorted(paths):
        if path.is_file() and path.name != ".DS_Store" and "__pycache__" not in path.parts:
            digest.update(path.relative_to(root).as_posix().encode() + b"\0")
            digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def receipt(root=ROOT):
    return {**identity(root), "source_sha256": source_digest(root)}


def check_receipt(path, root=ROOT):
    if json.loads(path.read_text()) != receipt(root):
        raise ValueError("release artifacts do not match current source/version; rebuild the candidate")


def check_app(path, root=ROOT):
    expected = identity(root)
    with (path / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    for key, field in (("CFBundleShortVersionString", "version"), ("CFBundleVersion", "build")):
        if str(info.get(key)) != expected[field]:
            raise ValueError(f"{path}: {key} is {info.get(key)!r}, expected {expected[field]}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("version", "build", "source-digest", "write-receipt", "check-receipt", "check-app"))
    parser.add_argument("path", type=Path, nargs="?")
    args = parser.parse_args()
    try:
        if args.action in ("version", "build"):
            print(identity()[args.action])
        elif args.action == "source-digest":
            print(source_digest())
        elif args.path is None:
            parser.error(f"{args.action} requires a path")
        elif args.action == "write-receipt":
            args.path.write_text(json.dumps(receipt(), indent=2) + "\n")
        elif args.action == "check-receipt":
            check_receipt(args.path)
        elif args.action == "check-app":
            check_app(args.path)
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        parser.exit(1, f"error: {error}\n")


if __name__ == "__main__":
    main()
