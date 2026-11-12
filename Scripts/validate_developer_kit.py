#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Read-only content checks for the agent developer kit.

Validates the plugin payload, both host manifests, the repository marketplace,
the skill's links and the compatibility map. Recipe source hashes are verified
against the pinned library commit when its Git objects are available locally.
--write-compatibility regenerates the compatibility map (an explicit write).
Optional --schema needs a local jsonschema install and never downloads it.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import zipfile

KIT_VERSION = "0.2.0"
LIBRARY_VERSION = "1.9.0"
STABLE = "f2a0d12da7028edfbcb0cb307f19a921a3a12d03"
TREE = "6b5438751352e0e424b133e79d40d32d6f8c8dd7"
REPOSITORY = "https://github.com/ThorFuchs/Swift-JSON"
PRODUCTS = {"JSON", "JSONSchema", "JSONSchemaExamples", "JSONStreaming", "JSONPatch", "JSONHTML", "JSONBridges",
            "JSONNavigation", "JSONInspection", "JSONTransform", "JSONValueDSL", "JSONSchemaDSL"}
PRODUCT_ORDER = ["JSON", "JSONSchema", "JSONSchemaExamples", "JSONStreaming", "JSONPatch", "JSONHTML", "JSONBridges",
                 "JSONNavigation", "JSONInspection", "JSONTransform", "JSONValueDSL", "JSONSchemaDSL"]
DESCRIPTION = "Version-aware consumer assistance for ThorFuchs/Swift-JSON, validated against library " + LIBRARY_VERSION + "."
SKILL_FILES = {"SKILL.md", "LICENSE", "references/versions.md", "references/semantics.md", "references/recipes.md",
               "references/troubleshooting.md", "references/installation.md", "references/compatibility.json",
               "assets/consumer/Package.swift", "assets/consumer/Sources/Consumer/Consumer.swift"}
PLUGIN_FILES = {"plugin.json", ".claude-plugin/plugin.json", "LICENSE"} | {"skills/swift-json/" + p for p in SKILL_FILES}
PORTABLE_KEYS = {"$schema", "name", "version", "description", "author", "repository", "license", "keywords"}
CLAUDE_KEYS = {"$schema", "name", "version", "description", "author", "homepage", "repository", "license", "keywords"}
MARKETPLACE = ".claude-plugin/marketplace.json"
MARKETPLACE_NAME = "swift-json"
# Each executable recipe marker binds to the tagged public declarations/DocC it relies on.
RECIPES = {
    "exact-presence": ["Sources/JSON/Codec/JSONParser.swift", "Sources/JSON/Codec/JSONWriter.swift",
                       "Sources/JSON/Documentation.docc/QuickEntryPoints.md", "Sources/JSON/Value/JSON.swift",
                       "Sources/JSON/Value/JSONObject.swift", "Sources/JSON/Reading/JSONReadCursor.swift"],
    "native-bridge": ["Sources/JSONBridges/DoubleConversions.swift", "Sources/JSONBridges/IntegerConversions.swift",
                      "Sources/JSONBridges/Documentation.docc/NumericFidelity.md"],
    "schema": ["Sources/JSONSchema/Compilation/JSONSchemaCompiler.swift",
               "Sources/JSONSchema/Evaluation/JSONSchemaValidator.swift",
               "Sources/JSONSchema/Output/JSONValidationResult.swift", "Sources/JSONSchema/Limits/JSONSchemaOptions.swift",
               "Sources/JSONSchema/Document/JSONSchemaRegistry.swift"],
    "examples": ["Sources/JSONSchemaExamples/JSONSchemaExampleGenerator.swift",
                 "Sources/JSONSchemaExamples/JSONSchemaExampleResult.swift",
                 "Sources/JSONSchemaExamples/Documentation.docc/VerifiedCandidates.md"],
    "streaming": ["Sources/JSONStreaming/NDJSON/NDJSONValueSequence.swift",
                  "Sources/JSONStreaming/Documentation.docc/CompletionAndBackpressure.md"],
    "navigation": ["Sources/JSONNavigation/JSONTraversal.swift", "Sources/JSONNavigation/JSONTraversalTypes.swift",
                   "Sources/JSONNavigation/Documentation.docc/Traversal.md"],
    "patch": ["Sources/JSONPatch/JSONPatch.swift", "Sources/JSONPatch/JSONPatchResult.swift",
              "Sources/JSONPatch/JSONMergePatch.swift"],
    "html": ["Sources/JSONHTML/JSONHTMLRenderer.swift", "Sources/JSONHTML/Documentation.docc/FormattedRendering.md"],
    "located-stream": ["Sources/JSONStreaming/JSONLocatedTopLevelArraySequence.swift",
                       "Sources/JSON/Document/JSONSourceMap.swift",
                       "Sources/JSONStreaming/Documentation.docc/CompletionAndBackpressure.md"],
    "shape-snapshot": ["Sources/JSONInspection/JSONShapeInspector.swift", "Sources/JSONInspection/JSONShapeEvidence.swift",
                       "Sources/JSONInspection/JSONStructuralSnapshot.swift",
                       "Sources/JSONInspection/Documentation.docc/StructuralSnapshots.md"],
    "batch": ["Sources/JSONInspection/JSONInspectionBatch.swift",
              "Sources/JSONInspection/Documentation.docc/BoundedWorkflows.md"],
    "store": ["Sources/JSONInspection/Store/JSONConfiguredStore.swift", "Sources/JSONInspection/Store/JSONStoreProfile.swift",
              "Sources/JSONInspection/Store/JSONStoreQueries.swift",
              "Sources/JSONInspection/Documentation.docc/BoundedWorkflows.md"],
    "transform": ["Sources/JSONTransform/JSONTransformProgram.swift", "Sources/JSONTransform/JSONTransformExecution.swift",
                  "Sources/JSONTransform/JSONTransformLimits.swift", "Sources/JSONTransform/JSONTransformFailure.swift",
                  "Sources/JSONTransform/JSONTransformProgramDefinition.swift",
                  "Sources/JSONTransform/JSONTransformSelection.swift",
                  "Sources/JSONTransform/Documentation.docc/IndexedSelection.md"],
    "dsl": ["Sources/JSONValueDSL/JSONValueDSL.swift", "Sources/JSONSchemaDSL/JSONSchemaDSL.swift",
            "Sources/JSONSchemaDSL/Documentation.docc/AuthoredSchemas.md"],
}
CONSUMER = "assets/consumer/Sources/Consumer/Consumer.swift"
AUTHORING_SOURCES = [
    {"url": "https://developers.openai.com/plugins/build/plugins", "observed": "2026-10-18"},
    {"url": "https://developers.openai.com/plugins/build/skills", "observed": "2026-10-18"},
    {"url": "https://learn.chatgpt.com/docs/build-skills", "observed": "2026-10-18"},
    {"url": "https://code.claude.com/docs/en/plugins/manifest-reference", "observed": "2026-11-11"},
    {"url": "https://code.claude.com/docs/en/plugins/marketplace-reference", "observed": "2026-11-11"},
    {"url": "https://code.claude.com/docs/en/skills", "observed": "2026-11-11"},
]


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


def check_identity(manifest, keys, label):
    require(set(manifest) <= keys, "unexpected " + label + " plugin component")
    require(manifest.get("name") == "swift-json" and manifest.get("version") == KIT_VERSION, label + " plugin identity mismatch")
    require(manifest.get("description") == DESCRIPTION, label + " plugin description mismatch")
    require(manifest.get("license") == "Apache-2.0" and manifest.get("repository") == REPOSITORY, label + " origin/license mismatch")


def validate_marketplace(repo):
    """Checks the repository marketplace that lists the in-repo plugin for Claude Code."""
    marketplace = json.loads((repo / MARKETPLACE).read_text())
    require(set(marketplace) <= {"$schema", "name", "owner", "metadata", "plugins"}, "unexpected marketplace field")
    require(marketplace["name"] == MARKETPLACE_NAME and marketplace["owner"].get("name"), "marketplace identity mismatch")
    plugins = marketplace["plugins"]
    require(len(plugins) == 1, "marketplace must list exactly the swift-json plugin")
    entry = plugins[0]
    require(set(entry) <= {"name", "source", "description", "version", "author", "homepage", "repository", "license",
                           "keywords", "category"}, "unexpected marketplace entry field (components belong in the plugin)")
    require(entry["name"] == "swift-json" and entry["source"] == "./plugins/swift-json", "marketplace entry source mismatch")
    require(entry.get("version") == KIT_VERSION and entry.get("description") == DESCRIPTION, "marketplace entry drift")
    return {"marketplace": marketplace["name"], "install": "swift-json@" + marketplace["name"]}


def git_blob(repo, commit, path):
    return subprocess.run(["git", "show", commit + ":" + path], cwd=repo, capture_output=True, check=True).stdout


def has_commit(repo):
    return subprocess.run(["git", "cat-file", "-e", STABLE + "^{commit}"], cwd=repo, capture_output=True).returncode == 0


def compatibility_document(skill, repo):
    """Builds the canonical map from the pinned commit's bytes and the local kit files."""
    tree = subprocess.check_output(["git", "rev-parse", STABLE + "^{tree}"], cwd=repo, text=True).strip()
    require(tree == TREE, "pinned commit tree mismatch")
    sf = files(skill)
    recipes = [{"id": recipe, "executable": CONSUMER, "marker": "// RECIPE " + recipe,
                "sources": [{"path": path, "url": REPOSITORY + "/blob/" + STABLE + "/" + path,
                             "sha256": sha(git_blob(repo, STABLE, path))} for path in paths]}
               for recipe, paths in RECIPES.items()]
    local = [{"path": p, "sha256": sha(sf[p]), "bytes": len(sf[p])}
             for p in sorted(SKILL_FILES - {"references/compatibility.json"})]
    return {
        "schema_version": 1,
        "kit_version": KIT_VERSION,
        "validated_library": {"version": LIBRARY_VERSION, "commit": STABLE, "tree": TREE,
                              "repository": REPOSITORY + ".git"},
        "baseline": {
            "swift_tools_compiler": "6.4+",
            "swift_language_mode": "6",
            "apple_deployment": "macOS 15+; iOS/iPadOS 18+ (compile-time evidence below 27)",
            "apple_development": "Xcode 27 / macOS 27 SDK",
            "linux": "separately qualified 64-bit Ubuntu 24.04/glibc",
            "wasi": "separately qualified full-language wasm32-unknown-wasip1 core scope",
        },
        "products": PRODUCT_ORDER,
        "cli": "swift-json",
        "later_versions_validated_by_this_kit": False,
        "recipes": recipes,
        "local_files": local,
        "authoring_sources": AUTHORING_SOURCES,
    }


def validate_plugin(root, schema=None):
    payload = files(root)
    require(set(payload) == PLUGIN_FILES, "unexpected/missing plugin files")
    manifest = json.loads(payload["plugin.json"])
    require(manifest["$schema"] == "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json", "schema mismatch")
    check_identity(manifest, PORTABLE_KEYS, "portable")
    claude = json.loads(payload[".claude-plugin/plugin.json"])
    check_identity(claude, CLAUDE_KEYS, "Claude Code")
    require({k: v for k, v in claude.items() if k != "homepage"} == {k: v for k, v in manifest.items() if k != "$schema"},
            "host manifests disagree")
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
    require(len(metadata["description"]) <= 1024, "skill description too long for portable hosts")
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
            require(LIBRARY_VERSION in text or name != "SKILL.md", "entry point does not name the validated library")
    compatibility = json.loads(sf["references/compatibility.json"])
    require(compatibility["kit_version"] == KIT_VERSION, "kit version mismatch")
    library = compatibility["validated_library"]
    require((library["version"], library["commit"], library["tree"]) == (LIBRARY_VERSION, STABLE, TREE), "stable authority mismatch")
    require(compatibility["products"] == PRODUCT_ORDER and set(PRODUCT_ORDER) == PRODUCTS, "stable product mismatch")
    require(compatibility["later_versions_validated_by_this_kit"] is False, "later-version boundary missing")
    records = compatibility["local_files"]
    require(len(records) == len({r["path"] for r in records}) and {r["path"] for r in records} == SKILL_FILES - {"references/compatibility.json"}, "local source map incomplete")
    for record in records:
        data = sf[record["path"]]
        require(record["bytes"] == len(data) and record["sha256"] == sha(data), "stale local source map: " + record["path"])
    recipes = compatibility["recipes"]
    require([r["id"] for r in recipes] == list(RECIPES), "recipe coverage mismatch")
    code = sf[CONSUMER].decode()
    require(set(re.findall(r"^import (\w+)$", code, re.M)) == PRODUCTS, "consumer imports mismatch")
    require(set(re.findall(r'\.product\(name: "(\w+)"', sf["assets/consumer/Package.swift"].decode())) == PRODUCTS, "consumer products mismatch")
    require('exact: "' + LIBRARY_VERSION + '"' in sf["assets/consumer/Package.swift"].decode(), "consumer pin mismatch")
    require(len(re.findall(r"^// RECIPE ", code, re.M)) == len(RECIPES), "unmapped recipe marker")
    require("KIT_RECIPES passed recipes=%d libraries=%d" % (len(RECIPES), len(PRODUCTS)) in code, "consumer completion line mismatch")
    for recipe in recipes:
        require(recipe["marker"] == "// RECIPE " + recipe["id"] and recipe["marker"] in code, "missing executable recipe: " + recipe["id"])
        require([s["path"] for s in recipe["sources"]] == RECIPES[recipe["id"]], "recipe source list drift: " + recipe["id"])
        for source in recipe["sources"]:
            safe_name(source["path"])
            require(source["url"] == REPOSITORY + "/blob/" + STABLE + "/" + source["path"] and re.fullmatch(r"[0-9a-f]{64}", source["sha256"]), "mutable/unhashed recipe source")
    return {"plugin_files": len(payload), "skill_files": len(sf), "recipes": len(recipes),
            "schema_validation": "passed" if schema else "not_run: supply current local --schema with jsonschema installed"}


def verify_sources(root, repo):
    """Compares the committed map with one regenerated from the pinned commit's bytes."""
    if not has_commit(repo):
        return "not_run: pinned commit " + STABLE + " is not available locally"
    expected = compatibility_document(root / "skills/swift-json", repo)
    actual = json.loads((root / "skills/swift-json/references/compatibility.json").read_text())
    require(actual == expected, "compatibility map differs from the pinned commit; run --write-compatibility")
    return "passed: %d source bindings at %s" % (sum(len(r["sources"]) for r in expected["recipes"]), STABLE)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--plugin", type=Path)
    parser.add_argument("--schema", type=Path)
    parser.add_argument("--plugin-zip", type=Path)
    parser.add_argument("--skill-zip", type=Path)
    parser.add_argument("--write-compatibility", action="store_true",
                        help="Regenerate references/compatibility.json from the pinned commit, then validate.")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    root = args.plugin or repo / "plugins/swift-json"
    if args.write_compatibility:
        path = root / "skills/swift-json/references/compatibility.json"
        path.write_text(json.dumps(compatibility_document(root / "skills/swift-json", repo), indent=2) + "\n")
    result = validate_plugin(root, args.schema)
    result["recipe_sources"] = verify_sources(root, repo)
    result.update(validate_marketplace(repo))
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
