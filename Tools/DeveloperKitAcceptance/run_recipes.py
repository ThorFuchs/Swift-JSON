#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Copy canonical recipes to a NEW outside-checkout directory and run SwiftPM.

Writes: source copy, isolated cache/config/security/scratch, logs, receipt.json.
Resolves public HTTPS exact 1.6.1. No installation or personal settings edits.
Use the supported Swift toolchain in PATH/DEVELOPER_DIR before invoking.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts"))
from validate_developer_kit import PRODUCTS, STABLE, TREE, files, require, sha, validate_plugin


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    require(not output.exists(), "output must not exist")
    # Refuse ANY Git parent, including a linked checkout or unrelated consumer repo.
    for parent in (output, *output.parents):
        require(not (parent / ".git").exists(), "consumer must be outside every checkout")
    plugin = ROOT / "plugins/swift-json"
    validate_plugin(plugin)
    output.mkdir(parents=True)
    source = plugin / "skills/swift-json/assets/consumer"
    shutil.copytree(source, output / "Consumer")
    receipt = {"schema_version": 1, "status": "running", "commands": [], "environment": {
        key: os.environ[key] for key in ("DEVELOPER_DIR", "SDKROOT") if key in os.environ},
        "source": {p: sha(b) for p, b in files(source).items()}}
    def save():
        (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    def run(label, command, allowed=(0,), cwd=output):
        started = time.time()
        result = subprocess.run(command, cwd=cwd, capture_output=True)
        channels = []
        for suffix, data in [("stdout", result.stdout), ("stderr", result.stderr)]:
            path = output / (label + "." + suffix)
            path.write_bytes(data)
            channels.append({"path": path.name, "bytes": len(data), "sha256": sha(data)})
        receipt["commands"].append({"label": label, "command": command, "cwd": str(cwd),
            "started_unix": started, "duration_seconds": time.time() - started,
            "exit": result.returncode, "channels": channels})
        save()
        require(result.returncode in allowed, label + " failed; inspect retained logs")
        return result.stdout
    try:
        run("swift-version", ["swift", "--version"])
        run("native-preflight", [sys.executable, "-B", str(ROOT / "Scripts/preflight.py"),
            "--output", str(output / "preflight.json")], cwd=ROOT)
        flags = ["--package-path", str(output / "Consumer"), "--cache-path", str(output / "Cache"),
                 "--config-path", str(output / "Config"), "--security-path", str(output / "Security"),
                 "--scratch-path", str(output / "Scratch")]
        # The isolated config has no preexisting mirrors. Also query effective SwiftPM behavior.
        mirror = run("effective-mirror", ["swift", "package", *flags, "config", "get-mirror", "--original",
            "https://github.com/ThorFuchs/Swift-JSON.git"], allowed=(1,))
        require(not mirror.strip(), "unexpected effective mirror")
        run("resolve", ["swift", "package", *flags, "resolve"])
        resolved = json.loads((output / "Consumer/Package.resolved").read_text())
        pins = resolved["pins"]
        require(len(pins) == 1 and pins[0]["location"] == "https://github.com/ThorFuchs/Swift-JSON.git"
                and pins[0]["state"] == {"revision": STABLE, "version": "1.6.1"}, "resolved pin mismatch")
        checkout = next((output / "Scratch/checkouts").iterdir())
        identity = run("checkout-identity", ["git", "log", "-1", "--format=%H %T"], cwd=checkout).decode().strip()
        require(identity == STABLE + " " + TREE, "checkout identity mismatch")
        compatibility = json.loads((plugin / "skills/swift-json/references/compatibility.json").read_text())
        for recipe in compatibility["recipes"]:
            for source_record in recipe["sources"]:
                require(sha((checkout / source_record["path"]).read_bytes()) == source_record["sha256"],
                    "tagged source-map hash mismatch: " + source_record["path"])
        receipt["recipe_source_bindings"] = sum(len(r["sources"]) for r in compatibility["recipes"])
        graph = json.loads(run("package-inventory", ["swift", "package", "--package-path", str(checkout), "dump-package"]))
        require(not graph["dependencies"], "root graph is not empty")
        require({p["name"] for p in graph["products"]} == PRODUCTS | {"swift-json"}, "product inventory mismatch")
        run("tagged-cli-identity", ["python3", "-B", "Scripts/generate_cli_identity.py", "--check"], cwd=checkout)
        expected = None
        for configuration in ["debug", "release"]:
            text = run(configuration, ["swift", "run", *flags, "-c", configuration, "Consumer"]).decode()
            checks = [line for line in text.splitlines() if line.startswith("KIT_CHECK ")]
            require(len(checks) >= 40 and len(set(checks)) == len(checks) and "KIT_RECIPES passed recipes=8 libraries=8" in text,
                    "recipe completion/cardinality mismatch")
            if expected is not None:
                require(checks == expected, "Debug/Release witness mismatch")
            expected = checks
            receipt[configuration + "_checks"] = len(checks)
        receipt["resolved"] = resolved
        receipt["checkout"] = identity
        receipt["status"] = "passed"
    except Exception as error:
        receipt["status"] = "failed"
        receipt["error"] = str(error)
        raise
    finally:
        save()
    print(json.dumps({"status": receipt["status"], "receipt": str(output / "receipt.json"),
        "debug_checks": receipt["debug_checks"], "release_checks": receipt["release_checks"]}, indent=2))


if __name__ == "__main__":
    main()
