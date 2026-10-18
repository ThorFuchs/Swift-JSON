#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Build deterministic kit archives in a caller-chosen empty output directory."""
import argparse
import json
from pathlib import Path
import zipfile
from validate_developer_kit import files, require, safe_name, sha, validate_plugin


def archive(path, payload):
    require(not path.exists(), "refusing to replace existing archive")
    records = [{"path": p, "bytes": len(b), "sha256": sha(b)} for p, b in sorted(payload.items())]
    payload = {**payload, "swift-json/MANIFEST.json": (json.dumps({"schema_version": 1, "self_excluded": True, "files": records}, sort_keys=True, indent=2) + "\n").encode()}
    with zipfile.ZipFile(path, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as output:
        for name, data in sorted(payload.items()):
            safe_name(name)
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            output.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    require(path.stat().st_size < 1_048_576, "distribution exceeds one MiB")
    return {"name": path.name, "bytes": path.stat().st_size, "sha256": sha(path.read_bytes())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent / "plugins/swift-json"
    validate_plugin(root)
    require(not args.output.exists(), "choose a new output directory")
    args.output.mkdir(parents=True)
    result = []
    for kind, source in [("plugin", root), ("skill", root / "skills/swift-json")]:
        result.append(archive(args.output / ("swift-json-" + kind + "-0.1.0.zip"), {"swift-json/" + p: b for p, b in files(source).items()}))
    (args.output / "ASSETS.json").write_text(json.dumps({"kit_version": "0.1.0", "files": result}, sort_keys=True, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
