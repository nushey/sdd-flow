import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "skills" / "sdd" / "scripts"
SLUG = "demo"


def task_text(task_id, covers, context=1, reference=1, commit=None, acceptance=None, extra=""):
    context_lines = "\n".join(f"- src/context{i}.py — why" for i in range(context)) or "- none"
    reference_lines = "\n".join(f"- src/reference{i}.py — style" for i in range(reference)) or "- none"
    acceptance_lines = "\n".join(f"- [ ] {ac}: observable result" for ac in (acceptance or covers))
    log_commit = f"{commit} — feat(demo): work" if commit else "<hash> — <subject>"
    return f"""# {task_id} — Do the work

## Covers
{", ".join(covers)}

## Context files (read for understanding — do not modify)
{context_lines}

## Reference files (STRICT STYLE MATCH)
{reference_lines}
{extra}
## Files to create/modify (suggested)
- src/app.py — modify

## Description
Do it.

## Acceptance
{acceptance_lines}

## Needs tests
no

---

## Implementation log (filled by dev after successful commit)
- Commit: {log_commit}
- Files modified:
  - src/app.py (modified)
"""


class Repo:
    def __init__(self, root, env):
        self.root = root
        self.env = env
        self.spec = root / ".spec" / SLUG
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.com")
        self.git("config", "commit.gpgsign", "false")
        self.base = self.commit({"README.md": "base\n"}, "chore: base")

    def git(self, *args):
        result = subprocess.run(["git", *args], cwd=self.root, env=self.env, capture_output=True, text=True)
        if result.returncode != 0:
            raise AssertionError(result.stderr)
        return result.stdout.strip()

    def write(self, relative, text, newline="\n"):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8", newline=newline) as handle:
            handle.write(text)
        return path

    def commit(self, files, message):
        for relative, text in files.items():
            self.write(relative, text)
            self.git("add", "--", relative)
        self.git("commit", "-q", "-m", message)
        return self.git("rev-parse", "HEAD")

    def spec_write(self, name, text, newline="\n"):
        return self.write(f".spec/{SLUG}/{name}", text, newline)

    def intake(self, base=None):
        self.spec_write("intake.md", f"# Intake: Demo\n\n## Base commit\n{base or self.base}\n\n## Raw prompt\nDo it.\n")

    def scope(self, criteria=("AC-001: Returns ok", "AC-002: Rejects bad input")):
        lines = "\n".join(f"- [ ] {c}" for c in criteria)
        self.spec_write("scope.md", f"# Scope: Demo\n\n## Objective\nEnable users.\n\n## Acceptance criteria\n{lines}\n\n## Context\nWhy.\n")

    def index(self, rows, fixes=None):
        table = "\n".join(f"| {r[0]} | Work {r[0]} | {r[1]} | {r[2]} |" for r in rows)
        text = f"# Tasks: Demo\n\nProject has tests: no\n\n| ID | Title | Covers | Status |\n|---|---|---|---|\n{table}\n"
        if fixes is not None:
            fix_rows = "\n".join(f"| {f[0]} | Fix {f[0]} | {f[1]} | Verifier cycle 1 | src/app.py | {f[2]} |" for f in fixes)
            text += f"\n## Fixes\n\n| Fix ID | Title | Covers | Triggered by failure in | Files (suggested) | Status |\n|---|---|---|---|---|---|\n{fix_rows}\n"
        self.spec_write("tasks.index.md", text)

    def planned(self, done=True):
        self.intake()
        self.scope()
        self.spec_write("design.md", "# Design: Demo\n\n## Technical approach\nSimple.\n")
        rows = []
        for task_id, ac in (("001", "AC-001"), ("002", "AC-002")):
            commit = self.commit({f"src/{task_id}.py": "x = 1\n"}, f"feat(demo): {task_id}") if done else None
            self.spec_write(f"tasks/{task_id}-work.md", task_text(task_id, [ac], commit=commit))
            rows.append((task_id, ac, f"done ({commit})" if done else "pending"))
        self.index(rows)
        return rows

    def verify(self, status="PASS", ticks=("x", "x"), verified=None):
        verified = verified or self.git("rev-parse", "HEAD")
        criteria = "\n".join(f"- [{t}] AC-00{i}: criterion — evidence" for i, t in enumerate(ticks, start=1))
        self.spec_write("verify.md", f"# Verify: Demo\n\n## Status\n{status}\n\n## Acceptance criteria\n{criteria}\n\n## Local closure\n- Base commit: {self.base}\n- Verified commit: {verified}\n")


class SddCheckTest(unittest.TestCase):
    def setUp(self):
        self.temp = Path(tempfile.mkdtemp(prefix="sdd check "))
        self.addCleanup(shutil.rmtree, self.temp, ignore_errors=True)
        home = self.temp / "home"
        home.mkdir()
        self.env = {**os.environ, "HOME": str(home), "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull}
        root = self.temp / "project"
        root.mkdir()
        self.repo = Repo(root, self.env)

    def check(self, *args, cwd=None):
        result = subprocess.run(
            [sys.executable, str(SCRIPTS / "sdd.py"), "check", SLUG, *args],
            cwd=cwd or self.repo.root, env=self.env, capture_output=True, text=True,
        )
        return result.returncode, result.stdout

    def assertFinding(self, code, *args):
        exit_code, output = self.check(*args)
        self.assertEqual(exit_code, 1, output)
        self.assertIn(f"{code} ", output)
        return output

    def assertOk(self, expected, *args):
        exit_code, output = self.check(*args)
        self.assertEqual((exit_code, output.strip()), (0, expected), output)


class FilesAndIds(SddCheckTest):
    def test_intake_only_is_a_valid_start(self):
        self.repo.intake()
        self.assertOk("OK resume: intake")

    def test_scope_without_tasks_passes_its_phase(self):
        self.repo.intake()
        self.repo.scope()
        self.assertOk("OK scope", "--phase", "scope")
        self.assertOk("OK resume: scope")

    def test_missing_scope(self):
        self.repo.intake()
        self.assertFinding("MISSING_FILE", "--phase", "scope")

    def test_empty_design(self):
        self.repo.planned()
        self.repo.spec_write("design.md", "  \n")
        self.assertFinding("EMPTY_FILE", "--phase", "plan")

    def test_index_without_design(self):
        self.repo.planned()
        (self.repo.spec / "design.md").unlink()
        self.assertFinding("BAD_STATE")

    def test_design_without_index_blocks_execution(self):
        self.repo.planned()
        (self.repo.spec / "tasks.index.md").unlink()
        self.assertFinding("PLAN_INCOMPLETE")

    def test_row_without_file(self):
        rows = self.repo.planned()
        (self.repo.spec / "tasks" / "002-work.md").unlink()
        self.assertFinding("ROW_WITHOUT_FILE", "--phase", "plan")
        self.assertTrue(rows)

    def test_orphan_file(self):
        self.repo.planned()
        self.repo.spec_write("tasks/003-extra.md", task_text("003", ["AC-001"]))
        self.assertFinding("ORPHAN_FILE", "--phase", "plan")

    def test_two_files_with_same_id(self):
        self.repo.planned()
        self.repo.spec_write("tasks/001-other.md", task_text("001", ["AC-001"]))
        self.assertFinding("DUPLICATE_ID", "--phase", "plan")

    def test_duplicate_ac(self):
        self.repo.intake()
        self.repo.scope(("AC-001: One", "AC-001: Two"))
        self.assertFinding("DUPLICATE_ID", "--phase", "scope")

    def test_zero_and_malformed_ac(self):
        for criterion in ("AC-000: Zero", "AC-1: Short", "Returns ok"):
            with self.subTest(criterion=criterion):
                self.repo.intake()
                self.repo.scope((criterion,))
                self.assertFinding("BAD_ID", "--phase", "scope")

    def test_heading_mismatch(self):
        self.repo.planned()
        path = self.repo.spec / "tasks" / "001-work.md"
        path.write_text(path.read_text().replace("# 001 —", "# 007 —"))
        self.assertFinding("HEADING_MISMATCH", "--phase", "plan")

    def test_invalid_base_commit(self):
        self.repo.intake(base="deadbeef")
        self.assertFinding("BAD_COMMIT")


class CoverageAndContext(SddCheckTest):
    def test_valid_plan_passes(self):
        self.repo.planned(done=False)
        self.assertOk("OK plan", "--phase", "plan")
        self.assertOk("OK resume: plan")

    def test_uncovered_ac(self):
        self.repo.planned()
        self.repo.scope(("AC-001: One", "AC-002: Two", "AC-003: Three"))
        output = self.assertFinding("UNCOVERED_AC", "--phase", "plan")
        self.assertIn("AC-003", output)

    def test_unknown_ac(self):
        self.repo.planned(done=False)
        self.repo.spec_write("tasks/002-work.md", task_text("002", ["AC-002", "AC-009"]))
        self.repo.index([("001", "AC-001", "pending"), ("002", "AC-002, AC-009", "pending")])
        self.assertFinding("UNKNOWN_AC", "--phase", "plan")

    def test_covers_differ_between_row_and_file(self):
        self.repo.planned(done=False)
        self.repo.index([("001", "AC-001, AC-002", "pending"), ("002", "AC-002", "pending")])
        self.assertFinding("COVERS_MISMATCH", "--phase", "plan")

    def test_acceptance_outside_covers(self):
        self.repo.planned(done=False)
        self.repo.spec_write("tasks/001-work.md", task_text("001", ["AC-001"], acceptance=["AC-002"]))
        self.assertFinding("COVERS_MISMATCH", "--phase", "plan")

    def test_caps_are_exact(self):
        self.repo.planned(done=False)
        self.repo.spec_write("tasks/001-work.md", task_text("001", ["AC-001"], context=5, reference=3))
        self.assertOk("OK plan", "--phase", "plan")
        for context, reference in ((6, 3), (5, 4)):
            with self.subTest(context=context, reference=reference):
                self.repo.spec_write("tasks/001-work.md", task_text("001", ["AC-001"], context=context, reference=reference))
                self.assertFinding("CAP_EXCEEDED", "--phase", "plan")

    def test_explicit_empty_lists(self):
        self.repo.planned(done=False)
        self.repo.spec_write("tasks/001-work.md", task_text("001", ["AC-001"], context=0, reference=0))
        self.assertOk("OK plan", "--phase", "plan")

    def test_fenced_examples_are_not_data(self):
        self.repo.planned(done=False)
        fence = "\n```markdown\n## Context files\n" + "".join(f"- e{i}.py\n" for i in range(9)) + "## Covers\nAC-999\n```\n"
        self.repo.spec_write("tasks/001-work.md", task_text("001", ["AC-001"], extra=fence))
        self.assertOk("OK plan", "--phase", "plan")

    def test_crlf_and_escaped_pipe(self):
        self.repo.planned(done=False)
        for name in ("scope.md", "tasks/001-work.md", "tasks.index.md"):
            path = self.repo.spec / name
            text = path.read_text().replace("Work 001", "Work a \\| b")
            self.repo.spec_write(name, text, newline="\r\n")
        self.assertOk("OK plan", "--phase", "plan")


class GitAndStates(SddCheckTest):
    def test_unknown_status(self):
        self.repo.planned(done=False)
        self.repo.index([("001", "AC-001", "started"), ("002", "AC-002", "pending")])
        self.assertFinding("BAD_STATUS", "--phase", "plan")

    def test_bare_done_is_rejected(self):
        self.repo.planned(done=False)
        self.repo.index([("001", "AC-001", "done"), ("002", "AC-002", "pending")])
        self.assertFinding("BAD_STATUS", "--phase", "plan")

    def test_missing_commit(self):
        rows = self.repo.planned()
        self.repo.index([("001", "AC-001", "done (abcdef1234)"), rows[1]])
        self.assertFinding("BAD_COMMIT", "--phase", "plan")

    def test_commit_from_other_history(self):
        rows = self.repo.planned()
        self.repo.git("checkout", "-q", "--orphan", "other")
        foreign = self.repo.commit({"other.txt": "x\n"}, "chore: other")
        self.repo.git("checkout", "-q", "main")
        self.repo.spec_write("tasks/001-work.md", task_text("001", ["AC-001"], commit=foreign))
        self.repo.index([("001", "AC-001", f"done ({foreign})"), rows[1]])
        self.assertFinding("BAD_COMMIT", "--phase", "plan")

    def test_commit_before_base(self):
        rows = self.repo.planned()
        old = self.repo.base
        self.repo.base = self.repo.git("rev-parse", "HEAD~1")
        self.repo.intake()
        self.repo.spec_write("tasks/001-work.md", task_text("001", ["AC-001"], commit=old))
        self.repo.index([("001", "AC-001", f"done ({old})"), rows[1]])
        self.assertFinding("BAD_COMMIT", "--phase", "plan")

    def test_row_and_log_name_different_commits(self):
        rows = self.repo.planned()
        self.repo.index([("001", "AC-001", rows[1][2]), rows[1]])
        self.assertFinding("HASH_MISMATCH", "--phase", "plan")

    def test_abbreviated_hash_is_accepted(self):
        rows = self.repo.planned()
        short = rows[0][2][6:13]
        self.repo.spec_write("tasks/001-work.md", task_text("001", ["AC-001"], commit=short))
        self.repo.index([("001", "AC-001", f"done ({short})"), rows[1]])
        self.assertOk("OK plan", "--phase", "plan")

    def test_pending_task_with_its_commit_is_reconcilable(self):
        rows = self.repo.planned()
        self.repo.index([rows[0], ("002", "AC-002", "pending")])
        self.assertOk("OK resume: plan")

    def test_terminal_fixes_keep_hash_in_log_only(self):
        rows = self.repo.planned()
        fixes = []
        for number, status in (("001", "failed"), ("002", "passed")):
            commit = self.repo.commit({f"src/fix{number}.py": "y = 2\n"}, f"fix(demo): {number}")
            self.repo.spec_write(f"fixes/fix-{number}-patch.md", task_text(f"fix-{number}", ["AC-001"], commit=commit))
            fixes.append((f"fix-{number}", "AC-001", status))
        self.repo.index(rows, fixes)
        self.assertOk("OK verify", "--phase", "verify")

    def test_terminal_fix_without_log(self):
        rows = self.repo.planned()
        self.repo.spec_write("fixes/fix-001-patch.md", task_text("fix-001", ["AC-001"]))
        self.repo.index(rows, [("fix-001", "AC-001", "failed")])
        self.assertFinding("LOG_MISSING", "--phase", "plan")

    def test_two_open_fixes(self):
        rows = self.repo.planned()
        for number in ("001", "002"):
            self.repo.spec_write(f"fixes/fix-{number}-patch.md", task_text(f"fix-{number}", ["AC-001"]))
        self.repo.index(rows, [("fix-001", "AC-001", "pending"), ("fix-002", "AC-001", "in-progress")])
        self.assertFinding("FIX_SEQUENCE", "--phase", "plan")

    def test_fourth_attempt_after_three_failures(self):
        rows = self.repo.planned()
        fixes = []
        for number in ("001", "002", "003"):
            commit = self.repo.commit({f"src/fix{number}.py": "y = 2\n"}, f"fix(demo): {number}")
            self.repo.spec_write(f"fixes/fix-{number}-patch.md", task_text(f"fix-{number}", ["AC-001"], commit=commit))
            fixes.append((f"fix-{number}", "AC-001", "failed"))
        self.repo.index(rows, fixes)
        self.assertOk("OK resume: plan")
        self.repo.spec_write("fixes/fix-004-patch.md", task_text("fix-004", ["AC-001"]))
        self.repo.index(rows, fixes + [("fix-004", "AC-001", "pending")])
        self.assertFinding("FIX_SEQUENCE", "--phase", "plan")


class ClosureAndRouting(SddCheckTest):
    def test_no_remote_is_required(self):
        self.repo.planned()
        self.repo.verify()
        self.assertEqual(self.repo.git("remote"), "")
        self.assertOk("OK resume: verify-pass")

    def test_functional_fail_with_open_fix_is_structurally_valid(self):
        rows = self.repo.planned()
        self.repo.verify(status="FAIL", ticks=("x", " "))
        self.repo.spec_write("fixes/fix-001-patch.md", task_text("fix-001", ["AC-002"]))
        self.repo.index(rows, [("fix-001", "AC-002", "pending")])
        self.assertOk("OK resume: verify-fail")

    def test_done_fix_awaiting_reverification(self):
        rows = self.repo.planned()
        self.repo.verify(status="FAIL", ticks=("x", " "))
        commit = self.repo.commit({"src/fix.py": "z = 3\n"}, "fix(demo): patch")
        self.repo.spec_write("fixes/fix-001-patch.md", task_text("fix-001", ["AC-002"], commit=commit))
        self.repo.index(rows, [("fix-001", "AC-002", f"done ({commit})")])
        self.assertOk("OK verify", "--phase", "verify")

    def test_verify_phase_requires_all_tasks_done(self):
        self.repo.planned(done=False)
        self.assertFinding("BAD_STATUS", "--phase", "verify")

    def test_pass_with_pending_task(self):
        rows = self.repo.planned()
        self.repo.index([rows[0], ("002", "AC-002", "pending")])
        self.repo.verify()
        self.assertFinding("VERIFY_INCONSISTENT")

    def test_pass_with_unmet_criterion(self):
        self.repo.planned()
        self.repo.verify(ticks=("x", " "))
        self.assertFinding("VERIFY_INCONSISTENT")

    def test_pass_followed_by_code_change_is_stale(self):
        self.repo.planned()
        self.repo.verify()
        self.repo.commit({"src/late.py": "late = 1\n"}, "feat(demo): late")
        self.assertOk("OK resume: verify-pass-stale")

    def test_pass_with_uncommitted_code_is_stale(self):
        self.repo.planned()
        self.repo.verify()
        self.repo.write("src/wip.py", "wip = 1\n")
        self.assertOk("OK resume: verify-pass-stale")

    def test_spec_only_commit_after_pass_keeps_it(self):
        self.repo.planned()
        self.repo.verify()
        self.repo.git("add", "--", ".spec")
        self.repo.git("commit", "-q", "-m", "docs(demo): record verification")
        self.assertOk("OK resume: verify-pass")

    def test_verify_without_plan(self):
        self.repo.intake()
        self.repo.scope()
        self.repo.verify()
        self.assertFinding("BAD_STATE")

    def test_plan_only_folder_is_unsupported(self):
        self.repo.spec_write("plan.md", "# Plan: Demo\n")
        exit_code, output = self.check()
        self.assertEqual(exit_code, 2)
        self.assertTrue(output.startswith("ERROR unsupported format"))

    def test_missing_or_empty_folder(self):
        self.assertFinding("MISSING_FILE")
        self.repo.spec.mkdir(parents=True)
        self.assertFinding("MISSING_FILE")


class ReviewRegressions(SddCheckTest):
    def fix(self, number, covers, status, commit=None):
        self.repo.spec_write(f"fixes/fix-{number}-patch.md", task_text(f"fix-{number}", [covers], commit=commit))
        return (f"fix-{number}", covers, status)

    def committed_fix(self, number, covers, status):
        commit = self.repo.commit({f"src/fix{number}.py": f"v = {number}\n"}, f"fix(demo): {number}")
        row_status = f"done ({commit})" if status == "done" else status
        return self.fix(number, covers, row_status, commit), commit

    def test_new_failure_after_a_passed_fix_routes_to_the_loop(self):
        rows = self.repo.planned()
        failed, _ = self.committed_fix("001", "AC-001", "failed")
        passed, _ = self.committed_fix("002", "AC-001", "passed")
        self.repo.index(rows, [failed, passed])
        self.repo.commit({"src/late.py": "late = 1\n"}, "feat(demo): late")
        self.repo.verify(status="FAIL", ticks=("x", " "))
        self.assertOk("OK resume: verify-fail")

    def test_interrupted_fix_update_after_pass_is_recoverable(self):
        rows = self.repo.planned()
        done, _ = self.committed_fix("001", "AC-002", "done")
        self.repo.index(rows, [done])
        self.repo.verify()
        self.assertOk("OK resume: verify-reconcile")
        self.assertOk("OK verify", "--phase", "verify")

    def test_interrupted_fix_update_after_fail_is_recoverable(self):
        rows = self.repo.planned()
        done, _ = self.committed_fix("001", "AC-002", "done")
        self.repo.index(rows, [done])
        self.repo.verify(status="FAIL", ticks=("x", " "))
        self.assertOk("OK resume: verify-reconcile")

    def test_pass_older_than_the_open_fix_is_an_error(self):
        rows = self.repo.planned()
        self.repo.verify()
        done, _ = self.committed_fix("001", "AC-002", "done")
        self.repo.index(rows, [done])
        self.assertFinding("VERIFY_INCONSISTENT")

    def test_fix_reported_after_reconciliation(self):
        rows = self.repo.planned()
        _, commit = self.committed_fix("001", "AC-002", "done")
        self.repo.index(rows, [self.fix("001", "AC-002", "passed", commit)])
        self.repo.verify()
        self.assertOk("OK resume: verify-pass")

    def test_git_failure_never_yields_pass(self):
        self.repo.planned()
        self.repo.verify()
        self.repo.git("add", "--", ".spec")
        self.repo.git("commit", "-q", "-m", "docs(demo): record verification")
        self.repo.write("README.md", "changed\n")
        index = self.repo.root / ".git" / "index"
        index.write_bytes(index.read_bytes()[:20])
        exit_code, output = self.check()
        self.assertEqual(exit_code, 2, output)
        self.assertTrue(output.startswith("ERROR git status failed"), output)

    def test_acceptance_without_items(self):
        self.repo.planned(done=False)
        text = task_text("001", ["AC-001"]).replace("- [ ] AC-001: observable result", "Pending definition")
        self.repo.spec_write("tasks/001-work.md", text)
        self.assertFinding("MISSING_SECTION", "--phase", "plan")

    def test_covered_ac_without_acceptance_item(self):
        self.repo.planned(done=False)
        self.repo.scope(("AC-001: One", "AC-002: Two", "AC-003: Three"))
        self.repo.spec_write("tasks/001-work.md", task_text("001", ["AC-001", "AC-003"], acceptance=["AC-001"]))
        self.repo.index([("001", "AC-001, AC-003", "pending"), ("002", "AC-002", "pending")])
        output = self.assertFinding("COVERS_MISMATCH", "--phase", "plan")
        self.assertIn("AC-003 is in Covers but has no Acceptance item", output)

    def test_several_results_for_one_ac(self):
        self.repo.planned(done=False)
        self.repo.spec_write("tasks/001-work.md", task_text("001", ["AC-001"], acceptance=["AC-001", "AC-001"]))
        self.assertOk("OK plan", "--phase", "plan")

    def test_row_in_place_of_separator(self):
        self.repo.planned(done=False)
        path = self.repo.spec / "tasks.index.md"
        path.write_text(path.read_text().replace("|---|---|---|---|", "| 001 | Duplicate | AC-999 | invalid |"))
        self.assertFinding("BAD_TABLE", "--phase", "plan")

    def test_missing_separator(self):
        self.repo.planned(done=False)
        path = self.repo.spec / "tasks.index.md"
        path.write_text(path.read_text().replace("|---|---|---|---|\n", ""))
        self.assertFinding("BAD_TABLE", "--phase", "plan")

    def test_fix_files_without_plan(self):
        self.repo.intake()
        self.repo.scope()
        self.fix("001", "AC-001", "pending")
        self.assertFinding("BAD_STATE")

    def test_verify_phase_rejects_unimplemented_fix(self):
        rows = self.repo.planned()
        self.repo.verify(status="FAIL", ticks=("x", " "))
        for status in ("pending", "in-progress"):
            with self.subTest(status=status):
                self.repo.index(rows, [self.fix("001", "AC-002", status)])
                self.assertOk("OK resume: verify-fail")
                self.assertFinding("BAD_STATUS", "--phase", "verify")

    def test_other_spec_changes_are_foreign(self):
        self.repo.planned()
        self.repo.verify()
        self.repo.git("add", "--", ".spec")
        self.repo.git("commit", "-q", "-m", "docs(demo): record verification")
        self.assertOk("OK resume: verify-pass")
        self.repo.write(".spec/other/scope.md", "# Scope: Other\n")
        self.assertOk("OK resume: verify-pass-stale")


class DeterminismAndDistribution(SddCheckTest):
    def snapshot(self):
        return {
            path.relative_to(self.repo.root).as_posix(): (path.read_bytes(), path.stat().st_mtime_ns)
            for path in sorted(self.repo.root.rglob("*")) if path.is_file()
        }

    def test_read_only_and_deterministic(self):
        self.repo.planned()
        self.repo.verify()
        self.repo.scope(("AC-001: One", "AC-002: Two", "AC-003: Three"))
        before = self.snapshot()
        first = self.check()
        second = self.check()
        self.assertEqual(first, second)
        self.assertEqual(first[0], 1)
        self.assertEqual(before, self.snapshot())

    def test_runs_from_a_subdirectory(self):
        self.repo.intake()
        (self.repo.root / "src").mkdir(exist_ok=True)
        exit_code, output = self.check(cwd=self.repo.root / "src")
        self.assertEqual((exit_code, output.strip()), (0, "OK resume: intake"))

    def test_invalid_usage(self):
        for args in (["check"], ["check", "../demo"], ["check", SLUG, "--phase", "deliver"], ["lint", SLUG]):
            with self.subTest(args=args):
                result = subprocess.run([sys.executable, str(SCRIPTS / "sdd.py"), *args], cwd=self.repo.root, env=self.env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertTrue(result.stdout.startswith("ERROR "))

    def test_outside_a_git_work_tree(self):
        outside = self.temp / "outside"
        outside.mkdir()
        exit_code, output = self.check(cwd=outside)
        self.assertEqual(exit_code, 2, output)

    @unittest.skipIf(os.name == "nt", "POSIX launcher")
    def test_posix_launcher_from_path_with_spaces(self):
        copy = self.temp / "installed skills" / "sdd" / "scripts"
        shutil.copytree(SCRIPTS, copy)
        self.repo.intake()
        result = subprocess.run([str(copy / "sdd"), "check", SLUG], cwd=self.repo.root, env=self.env, capture_output=True, text=True)
        self.assertEqual((result.returncode, result.stdout.strip()), (0, "OK resume: intake"))

    @unittest.skipUnless(os.name == "nt", "Windows launcher")
    def test_windows_launcher(self):
        self.repo.intake()
        result = subprocess.run(["cmd", "/c", str(SCRIPTS / "sdd.cmd"), "check", SLUG], cwd=self.repo.root, env=self.env, capture_output=True, text=True)
        self.assertEqual((result.returncode, result.stdout.strip()), (0, "OK resume: intake"))


if __name__ == "__main__":
    unittest.main()
