import importlib.util
import json
import subprocess
import sys
import tempfile
import tomllib
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location("build_openai", ROOT / "scripts/build-openai.py")
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


class OpenAIPackageTests(unittest.TestCase):
    def test_archive_preserves_runtime_and_roles_reproducibly(self):
        with tempfile.TemporaryDirectory() as directory:
            first, second = (Path(directory) / name for name in ("first.zip", "second.zip"))
            for output in (first, second):
                subprocess.run([sys.executable, str(ROOT / "scripts/build-openai.py"), "--output", str(output)], check=True, capture_output=True)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with zipfile.ZipFile(first) as archive:
                self.assertIsNone(archive.testzip())
                manifest = json.loads(archive.read("plugin.json"))
                source = json.loads((ROOT / ".claude-plugin/plugin.json").read_text())
                self.assertEqual(manifest["version"], source["version"])
                self.assertEqual(archive.read("LICENSE"), (ROOT / "LICENSE").read_bytes())
                for tree in ("skills", "agents", "integrations/codex/agents"):
                    for path in (ROOT / tree).rglob("*"):
                        if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc" and "evals" not in path.parts:
                            self.assertEqual(archive.read(path.relative_to(ROOT).as_posix()), path.read_bytes())
                for role in (ROOT / "agents").glob("*.md"):
                    adapter = tomllib.loads(archive.read(f"integrations/codex/agents/{role.stem}.toml").decode())
                    self.assertEqual(adapter["developer_instructions"].strip(), role.read_text().split("---", 2)[2].strip())
                names = archive.namelist()
                self.assertFalse(any("__pycache__" in name or "/evals/" in name or name.startswith(("scripts/", "tests/")) for name in names))
                self.assertEqual(archive.read("assets/icon.png"), (ROOT / ".claude-plugin/icon.png").read_bytes())
                self.assertEqual((archive.getinfo("skills/sdd/scripts/sdd").external_attr >> 16) & 0o777, 0o755)

    def test_submission_subtitle_limit_is_enforced(self):
        manifest, files = BUILDER.package_files()
        manifest["extensions"]["com.openai"]["interface"]["shortDescription"] = "x" * 31
        with self.assertRaisesRegex(ValueError, "shortDescription"):
            BUILDER.validate(manifest, files)

    def test_missing_runtime_reference_fails_validation(self):
        manifest, files = BUILDER.package_files()
        del files["skills/sdd/references/check-contract.md"]
        with self.assertRaises(KeyError):
            BUILDER.validate(manifest, files)


if __name__ == "__main__":
    unittest.main()
