import argparse
import json
import struct
import zipfile
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parent.parent


def package_files():
    source = json.loads((ROOT / ".claude-plugin/plugin.json").read_text(encoding="utf-8"))
    interface = json.loads((ROOT / "integrations/openai/interface.json").read_text(encoding="utf-8"))
    manifest = {
        "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
        "name": source["name"],
        "version": source["version"],
        "description": "Spec-driven software development with structured planning, implementation, and independent verification.",
        "author": source["author"],
        "homepage": interface["websiteURL"],
        "license": source["license"],
        "extensions": {"com.openai": {
            "interface": interface,
            "requires_local_executor": True,
        }},
    }
    files = {"plugin.json": (json.dumps(manifest, indent=2) + "\n").encode()}
    for tree in ("skills", "agents", "integrations/codex/agents"):
        for path in sorted((ROOT / tree).rglob("*")):
            if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc" and "evals" not in path.parts:
                files[path.relative_to(ROOT).as_posix()] = path.read_bytes()
    files["assets/icon.png"] = (ROOT / ".claude-plugin/icon.png").read_bytes()
    files["LICENSE"] = (ROOT / "LICENSE").read_bytes()
    files["INSTALL.md"] = (ROOT / "INSTALL.md").read_bytes()
    return manifest, files


def validate(manifest, files):
    interface = manifest["extensions"]["com.openai"]["interface"]
    for key, limit in (("displayName", 30), ("shortDescription", 30), ("longDescription", 4000), ("developerName", 80)):
        value = interface[key]
        if not isinstance(value, str) or not value.strip() or len(value) > limit:
            raise ValueError(f"Invalid {key}: required string, at most {limit} characters")
    if "\n" in interface["shortDescription"] or interface["category"] != "Developer Tools":
        raise ValueError("Expected a single-line subtitle and Developer Tools category")
    for key in ("websiteURL", "supportURL", "privacyPolicyURL", "termsOfServiceURL"):
        url = urlsplit(interface[key])
        if url.scheme != "https" or not url.hostname or url.username is not None or url.password is not None or len(interface[key]) > 1024:
            raise ValueError(f"Invalid HTTPS URL: {key}")
    capabilities = interface["capabilities"]
    if not isinstance(capabilities, list) or len(capabilities) > 20:
        raise ValueError("Expected at most 20 capabilities")
    for capability in capabilities:
        if not isinstance(capability, str) or not capability.strip() or len(capability) > 120 or "\n" in capability:
            raise ValueError("Expected non-empty, single-line capabilities of at most 120 characters")
    for key in ("logo", "composerIcon"):
        data = files[interface[key].removeprefix("./")]
        width, height = struct.unpack(">II", data[16:24])
        if data[:8] != b"\x89PNG\r\n\x1a\n" or width != height or not 48 <= width <= 4096 or len(data) > 5 * 1024 * 1024:
            raise ValueError(f"Invalid PNG icon: {key}")
    for path in ("skills/sdd/scripts/sdd.py", "skills/sdd/scripts/sdd", "skills/sdd/scripts/sdd.cmd", "skills/sdd/references/check-contract.md"):
        files[path]


def main():
    parser = argparse.ArgumentParser(description="Build the OpenAI publication candidate; does not validate portal eligibility.")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    manifest, files = package_files()
    validate(manifest, files)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.output, "w", compression=zipfile.ZIP_STORED) as archive:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            mode = 0o755 if name == "skills/sdd/scripts/sdd" else 0o644
            info.external_attr = (0o100000 | mode) << 16
            archive.writestr(info, data)
    print(f"Built {args.output}: {manifest['name']} {manifest['version']}, {len(files)} files")
    print("Local checks passed. Directory eligibility, role registration, and public URLs require separate verification.")


if __name__ == "__main__":
    main()
