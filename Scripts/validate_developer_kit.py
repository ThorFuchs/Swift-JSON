#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Read-only DK1 checks. Optional --schema needs local jsonschema, never downloads it."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import zipfile

BASE = "07912d8b28e186589e994e537b2485877a634a6b"
STABLE = "e431f157ececc0cf3d061192420b0e36a9062f83"
TREE = "9d4c3969fad53f4734265ff585dc482ebea943d3"
PRODUCTS = {"JSON", "JSONSchema", "JSONSchemaExamples", "JSONStreaming", "JSONPatch", "JSONHTML", "JSONBridges", "JSONNavigation"}
SKILL_FILES = {"SKILL.md", "LICENSE", "references/versions.md", "references/semantics.md", "references/recipes.md",
               "references/troubleshooting.md", "references/installation.md", "references/compatibility.json",
               "assets/consumer/Package.swift", "assets/consumer/Sources/Consumer/Consumer.swift"}
ALLOWED_EXACT = {"README.md", "CONTRIBUTING.md", "Documentation/AgentDeveloperKit.md",
                 "Scripts/validate_developer_kit.py", "Scripts/package_developer_kit.py"}
ALLOWED_PREFIX = ("plugins/swift-json/", "Tools/DeveloperKitAcceptance/")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def files(root):
    require(root.is_dir() and not root.is_symlink(), "ordinary directory required")
    result = {}
    for path in sorted(root.rglob("*")):
        require(not path.is_symlink(), "symlink refused: " + str(path))
        if path.is_file():
            result[path.relative_to(root).as_posix()] = path.read_bytes()
        else:
            require(path.is_dir(), "special file refused")
    return result


def safe_name(name):
    path = PurePosixPath(name)
    require(name and "\\" not in name and ":" not in name and not path.is_absolute()
            and all(p not in ("", ".", "..") for p in name.split("/")), "unsafe archive path: " + name)


def read_archive(path):
    result = {}
    with zipfile.ZipFile(path) as archive:
        require(len(archive.infolist()) <= 100, "too many archive members")
        total = 0
        for info in archive.infolist():
            safe_name(info.filename)
            require(info.filename not in result and info.filename.casefold() not in {x.casefold() for x in result}, "duplicate archive member")
            require(stat.S_IFMT(info.external_attr >> 16) == stat.S_IFREG, "non-regular archive member")
            require(info.file_size <= 1_048_576, "oversized member")
            total += info.file_size
            require(total <= 2_097_152, "oversized archive payload")
            result[info.filename] = archive.read(info)
    manifest_name = "swift-json/MANIFEST.json"
    require(manifest_name in result, "missing archive manifest")
    manifest = json.loads(result.pop(manifest_name))
    records = manifest["files"]
    require(len({r["path"] for r in records}) == len(records), "duplicate manifest record")
    require(set(result) == {r["path"] for r in records}, "manifest membership mismatch")
    for record in records:
        data = result[record["path"]]
        require(record["bytes"] == len(data) and record["sha256"] == sha(data), "manifest byte mismatch")
    return result


def validate_plugin(root, schema=None):
    payload = files(root)
    require(set(payload) == {"plugin.json", "LICENSE"} | {"skills/swift-json/" + p for p in SKILL_FILES}, "unexpected/missing plugin files")
    manifest = json.loads(payload["plugin.json"])
    require(manifest["name"] == "swift-json" and manifest["version"] == "0.1.0", "plugin identity mismatch")
    require(manifest["$schema"] == "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json", "schema mismatch")
    require(set(manifest) <= {"$schema", "name", "version", "description", "author", "repository", "license", "keywords"}, "unexpected plugin component")
    require(manifest["license"] == "Apache-2.0" and manifest["repository"] == "https://github.com/ThorFuchs/Swift-JSON", "origin/license mismatch")
    if schema:
        import jsonschema
        jsonschema.Draft202012Validator(json.loads(Path(schema).read_text())).validate(manifest)
    skill = root / "skills/swift-json"
    sf = files(skill)
    header = sf["SKILL.md"].decode().split("---", 2)
    require(len(header) == 3 and header[0] == "", "missing skill frontmatter")
    metadata = {}
    for line in header[1].strip().splitlines():
        key, value = line.split(":", 1)
        require(key not in metadata, "duplicate skill metadata")
        metadata[key] = json.loads(value.strip()) if value.strip().startswith('"') else value.strip()
    require(metadata.get("name") == "swift-json" and set(metadata) == {"name", "description"}, "skill identity mismatch")
    require("ThorFuchs/Swift-JSON" in metadata["description"] and "Foundation.JSONSerialization" in metadata["description"], "ambiguous discovery scope")
    require(150 <= len(sf["SKILL.md"].splitlines()) <= 250, "entry point length outside intended range")
    for name, data in sf.items():
        text = data.decode()
        require(not any(p in text for p in ("/private/tmp/", "/Users/", "sk-proj-", "ghp_")), "private marker in " + name)
        if name.endswith(".md"):
            require("```swift" not in text.lower(), "untested duplicate Swift fence; use canonical asset source")
            for link in re.findall(r"\]\(([^\s)]+)\)", text):
                if re.match(r"https://", link):
                    continue
                require(not re.match(r"[a-zA-Z]+:", link), "unsupported link scheme")
                target = (skill / name).parent / link.split("#")[0]
                require(target.resolve().is_relative_to(skill.resolve()) and target.exists(), "broken/escaping internal link: " + link)
    compatibility = json.loads(sf["references/compatibility.json"])
    require(compatibility["kit_version"] == "0.1.0", "kit version mismatch")
    library = compatibility["validated_library"]
    require((library["version"], library["commit"], library["tree"]) == ("1.6.1", STABLE, TREE), "stable authority mismatch")
    require(set(compatibility["products"]) == PRODUCTS, "stable product mismatch")
    require(compatibility["unreleased"]["additional_library"] == "JSONInspection" and not compatibility["unreleased"]["validated_by_this_kit"], "development boundary missing")
    records = compatibility["local_files"]
    require(len(records) == len({r["path"] for r in records}) and {r["path"] for r in records} == SKILL_FILES - {"references/compatibility.json"}, "local source map incomplete")
    for record in records:
        data = sf[record["path"]]
        require(record["bytes"] == len(data) and record["sha256"] == sha(data), "stale local source map: " + record["path"])
    recipes = compatibility["recipes"]
    require({r["id"] for r in recipes} == {"exact-presence", "native-bridge", "schema", "examples", "streaming", "navigation", "patch", "html"} and len(recipes) == 8, "recipe coverage mismatch")
    code = sf["assets/consumer/Sources/Consumer/Consumer.swift"].decode()
    require(set(re.findall(r"^import (\w+)$", code, re.M)) == PRODUCTS, "consumer imports mismatch")
    for recipe in recipes:
        require(recipe["marker"] in code and recipe["sources"], "missing executable recipe/source")
        for source in recipe["sources"]:
            safe_name(source["path"])
            require(source["url"] == "https://github.com/ThorFuchs/Swift-JSON/blob/" + STABLE + "/" + source["path"] and re.fullmatch(r"[0-9a-f]{64}", source["sha256"]), "mutable/unhashed recipe source")
    return {"plugin_files": len(payload), "skill_files": len(sf), "recipes": len(recipes), "schema_validation": "passed" if schema else "not_run: supply current local --schema with jsonschema installed"}


def scope(repo, base=BASE):
    def git(*args):
        return subprocess.check_output(["git", *args], cwd=repo, text=True).strip().splitlines()
    commits = git("rev-list", "--reverse", base + "..HEAD")
    paths = set(git("diff", "--name-only", base)) | set(git("ls-files", "--others", "--exclude-standard"))
    for commit in commits:
        paths.update(git("diff-tree", "--no-commit-id", "--name-only", "-r", commit))
    require(all(p in ALLOWED_EXACT or p.startswith(ALLOWED_PREFIX) for p in paths), "out-of-scope edit")
    require(not git("diff", base, "--", "Package.swift", "Package.resolved", "Sources", "Tests", ".github", "AGENTS.md", "LICENSE", "NOTICE", "THIRD_PARTY_NOTICES.md"), "frozen source changed")
    return {"commits": commits, "changed_paths": sorted(paths), "frozen_paths": "unchanged"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plugin", type=Path)
    parser.add_argument("--schema", type=Path)
    parser.add_argument("--plugin-zip", type=Path)
    parser.add_argument("--skill-zip", type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    root = args.plugin or repo / "plugins/swift-json"
    result = validate_plugin(root, args.schema)
    result["scope"] = scope(repo)
    if args.plugin_zip or args.skill_zip:
        require(args.plugin_zip and args.skill_zip, "both archives required")
        plugin = read_archive(args.plugin_zip)
        standalone = read_archive(args.skill_zip)
        expected_plugin = {"swift-json/" + p: b for p, b in files(root).items()}
        expected_skill = {"swift-json/" + p: b for p, b in files(root / "skills/swift-json").items()}
        require(plugin == expected_plugin and standalone == expected_skill, "archive differs from canonical source")
        result["canonical_distributions"] = "byte-identical skill payload"
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
