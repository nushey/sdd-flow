#!/usr/bin/env python3
import re
import shutil
import subprocess
import sys
from pathlib import Path

PHASES = ("resume", "scope", "plan", "verify")
USAGE = "usage: sdd check <feature-slug> [--phase resume|scope|plan|verify]"
SLUG_RE = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
AC_RE = re.compile(r"AC-(\d{3})")
TASK_ID_RE = re.compile(r"\d{3}")
FIX_ID_RE = re.compile(r"fix-(\d{3})")
HASH_RE = re.compile(r"[0-9a-f]{7,64}")
DONE_RE = re.compile(r"done \((\S+)\)")
FENCE_RE = re.compile(r"^(```|~~~)")
CONTEXT_CAP = 5
REFERENCE_CAP = 3
MAX_FAILED_FIXES = 3
OPEN_FIX_STATUSES = ("pending", "in-progress")
INDEX_HEADER = ["ID", "Title", "Covers", "Status"]
FIXES_HEADER = ["Fix ID", "Title", "Covers", "Triggered by failure in", "Files (suggested)", "Status"]


class CheckError(Exception):
    pass


class Document:
    def __init__(self, path):
        self.path = path
        self.text = path.read_text(encoding="utf-8")
        self.lines = []
        fence = None
        for number, line in enumerate(self.text.splitlines(), start=1):
            marker = FENCE_RE.match(line)
            if fence:
                if marker and marker.group(1) == fence:
                    fence = None
                continue
            if marker:
                fence = marker.group(1)
                continue
            self.lines.append((number, line))

    def is_blank(self):
        return not self.text.strip()

    def first_line(self):
        return next(((n, l) for n, l in self.lines if l.strip()), (0, ""))

    def section(self, title, prefix=False):
        body = None
        for number, line in self.lines:
            if line.startswith("# ") or line.startswith("## "):
                if body is not None:
                    return body
                heading = line[3:].strip() if line.startswith("## ") else None
                if heading is not None and (heading.startswith(title) if prefix else heading == title):
                    body = []
                continue
            if body is not None:
                body.append((number, line))
        return body

    def lines_outside(self, title):
        result, inside = [], False
        for number, line in self.lines:
            if line.startswith("# ") or line.startswith("## "):
                inside = line.startswith("## ") and line[3:].strip() == title
                continue
            if not inside:
                result.append((number, line))
        return result


def entries(body):
    return [(n, l) for n, l in body if l.startswith("- ")]


def first_value(body):
    return next(((n, l.strip()) for n, l in body if l.strip()), None)


def split_row(line):
    cells = re.split(r"(?<!\\)\|", line.strip())
    if cells and cells[0] == "":
        cells = cells[1:]
    if cells and cells[-1] == "":
        cells = cells[:-1]
    return [cell.strip().replace("\\|", "|") for cell in cells]


def first_table(body):
    rows = []
    for number, line in body:
        if line.startswith("|"):
            rows.append((number, split_row(line)))
        elif rows:
            break
    return rows


def is_separator(cells, width):
    return len(cells) == width and all(re.fullmatch(r":?-+:?", cell) for cell in cells)


def valid_id(match):
    return match is not None and not match.group(0).endswith("000")


class Checker:
    def __init__(self, root, slug):
        self.root = root
        self.slug = slug
        self.spec = root / ".spec" / slug
        self.findings = set()
        self.commits = {}
        self.base = None
        self.acs = set()
        self.main_tasks = []
        self.fixes = []
        self.stale = {}

    def add(self, code, path, line, message):
        relative = path.relative_to(self.root).as_posix() if isinstance(path, Path) else path
        self.findings.add((relative, line, code, message))

    def git(self, *args):
        return subprocess.run(
            ["git", "--no-optional-locks", *args],
            cwd=self.root, capture_output=True, text=True, encoding="utf-8",
        )

    def resolve(self, value):
        if not HASH_RE.fullmatch(value):
            return None
        if value not in self.commits:
            result = self.git("rev-parse", "--verify", "--quiet", f"{value}^{{commit}}")
            self.commits[value] = result.stdout.strip() if result.returncode == 0 else None
        return self.commits[value]

    def is_ancestor(self, older, newer):
        return self.git("merge-base", "--is-ancestor", older, newer).returncode == 0

    def feature_commit(self, value, path, line):
        full = self.resolve(value)
        if full is None:
            self.add("BAD_COMMIT", path, line, f"'{value}' is not a unique local commit")
            return None
        in_history = self.is_ancestor(full, "HEAD") and (self.base is None or self.is_ancestor(self.base, full))
        if not in_history:
            self.add("BAD_COMMIT", path, line, f"commit {value} is not in the feature history")
        return full

    def document(self, name):
        path = self.spec / name
        if not path.is_file():
            self.add("MISSING_FILE", path, 0, f"{name} is required")
            return None
        doc = Document(path)
        if doc.is_blank():
            self.add("EMPTY_FILE", path, 0, f"{name} is empty")
            return None
        return doc

    def required_section(self, doc, title, prefix=False):
        body = doc.section(title, prefix)
        if body is None or not any(l.strip() for _, l in body):
            self.add("MISSING_SECTION", doc.path, 0, f"section '## {title}' is missing or empty")
            return None
        return body

    def parse_covers(self, value, path, line):
        covers = []
        for item in (part.strip() for part in value.split(",")):
            match = AC_RE.fullmatch(item)
            if not valid_id(match):
                self.add("BAD_ID", path, line, f"'{item}' is not a valid AC ID")
            elif item in covers:
                self.add("BAD_ID", path, line, f"{item} is listed twice")
            else:
                covers.append(item)
                if self.acs and item not in self.acs:
                    self.add("UNKNOWN_AC", path, line, f"{item} is not defined in scope.md")
        return set(covers)

    def check_intake(self):
        doc = self.document("intake.md")
        if doc is None:
            return
        body = self.required_section(doc, "Base commit")
        if body is None:
            return
        line, value = first_value(body)
        full = self.resolve(value)
        if full is None or not self.is_ancestor(full, "HEAD"):
            self.add("BAD_COMMIT", doc.path, line, f"base commit '{value}' is not a local ancestor of HEAD")
            return
        self.base = full

    def check_scope(self):
        doc = self.document("scope.md")
        if doc is None:
            return
        self.required_section(doc, "Objective")
        body = self.required_section(doc, "Acceptance criteria")
        if body is None:
            return
        for line, text in entries(body):
            match = re.fullmatch(r"- \[[ x]\] (AC-(\d{3})): \S.*", text)
            if not match or match.group(2) == "000":
                self.add("BAD_ID", doc.path, line, "criterion must read '- [ ] AC-NNN: <text>'")
            elif match.group(1) in self.acs:
                self.add("DUPLICATE_ID", doc.path, line, f"{match.group(1)} is defined twice")
            else:
                self.acs.add(match.group(1))
        if not entries(body):
            self.add("MISSING_SECTION", doc.path, 0, "no acceptance criteria defined")

    def table(self, doc, body, header, label):
        rows = first_table(body)
        if not rows:
            return []
        number, cells = rows[0]
        if cells != header:
            self.add("BAD_TABLE", doc.path, number, f"{label} header must be: {' | '.join(header)}")
            return []
        if len(rows) < 2 or not is_separator(rows[1][1], len(header)):
            line = rows[1][0] if len(rows) > 1 else number
            self.add("BAD_TABLE", doc.path, line, f"{label} needs a separator row after its header")
            return []
        result = []
        for number, cells in rows[2:]:
            if len(cells) != len(header):
                self.add("BAD_TABLE", doc.path, number, f"{label} row has {len(cells)} cells, expected {len(header)}")
            else:
                result.append((number, dict(zip(header, cells))))
        return result

    def task_files(self, folder, pattern):
        files = {}
        directory = self.spec / folder
        if not directory.is_dir():
            return files
        for path in sorted(directory.glob("*.md")):
            match = re.fullmatch(pattern, path.name)
            if not match or match.group(1).endswith("000"):
                self.add("BAD_ID", path, 0, f"file name does not follow {folder}/<ID>-<slug>.md")
                continue
            files.setdefault(match.group(1), []).append(path)
        for paths in files.values():
            for path in paths[1:]:
                self.add("DUPLICATE_ID", path, 0, f"another file has the same ID as {paths[0].name}")
        return files

    def match_rows(self, rows, files, id_key, id_re, index_path):
        matched, seen = [], set()
        for number, row in rows:
            row_id = row[id_key]
            if not valid_id(id_re.fullmatch(row_id)):
                self.add("BAD_ID", index_path, number, f"'{row_id}' is not a valid ID")
                continue
            if row_id in seen:
                self.add("DUPLICATE_ID", index_path, number, f"{row_id} has more than one row")
                continue
            seen.add(row_id)
            if row_id not in files:
                self.add("ROW_WITHOUT_FILE", index_path, number, f"{row_id} has no file")
                continue
            matched.append((number, row, files[row_id][0]))
        for file_id, paths in files.items():
            if file_id not in seen:
                self.add("ORPHAN_FILE", paths[0], 0, f"{file_id} has no row in tasks.index.md")
        return matched

    def check_task_file(self, path, task_id):
        doc = Document(path)
        line, heading = doc.first_line()
        if not re.fullmatch(rf"# {re.escape(task_id)} — \S.*", heading):
            self.add("HEADING_MISMATCH", path, line, f"heading must start with '# {task_id} — '")
        covers = set()
        body = self.required_section(doc, "Covers")
        if body is not None:
            line, value = first_value(body)
            covers = self.parse_covers(value, path, line)
        for title, cap in (("Context files", CONTEXT_CAP), ("Reference files", REFERENCE_CAP)):
            body = self.required_section(doc, title, prefix=True)
            if body is None:
                continue
            listed = entries(body)
            if [l.strip() for _, l in listed] == ["- none"]:
                listed = []
            if len(listed) > cap:
                self.add("CAP_EXCEEDED", path, listed[cap][0], f"{len(listed)} {title} entries, maximum {cap}")
        body = self.required_section(doc, "Acceptance")
        described = set()
        for line, text in entries(body or []):
            match = re.fullmatch(r"- \[[ x]\] (AC-\d{3}): \S.*", text)
            if not match:
                self.add("BAD_ID", path, line, "acceptance entry must read '- [ ] AC-NNN: <result>'")
            elif match.group(1) not in covers:
                self.add("COVERS_MISMATCH", path, line, f"{match.group(1)} is not in this file's Covers")
            else:
                described.add(match.group(1))
        if body is not None and not entries(body):
            self.add("MISSING_SECTION", path, 0, "Acceptance has no '- [ ] AC-NNN: <result>' items")
        for ac in sorted(covers - described):
            self.add("COVERS_MISMATCH", path, 0, f"{ac} is in Covers but has no Acceptance item")
        log = None
        body = self.required_section(doc, "Implementation log", prefix=True)
        for line, text in entries(body or []):
            match = re.match(r"- Commit: (\S+)", text)
            if match and match.group(1) != "<hash>":
                log = (line, match.group(1))
        return covers, log

    def check_status(self, path, number, status, log, allowed, needs_log):
        done = DONE_RE.fullmatch(status)
        if not done and (status == "done" or status not in allowed):
            self.add("BAD_STATUS", self.spec / "tasks.index.md", number, f"status '{status}' is not one of {', '.join(allowed)}")
            return
        log_full = self.feature_commit(log[1], path, log[0]) if log else None
        if (done or status in needs_log) and log is None:
            self.add("LOG_MISSING", path, 0, f"status '{status}' requires a filled Implementation log")
        if not done:
            return None
        row_full = self.feature_commit(done.group(1), self.spec / "tasks.index.md", number)
        if row_full and log_full and row_full != log_full:
            self.add("HASH_MISMATCH", path, log[0], "Implementation log and index name different commits")
        return row_full

    def check_plan(self):
        self.document("design.md")
        doc = self.document("tasks.index.md")
        if doc is None:
            return
        index = doc.path
        main_rows = self.table(doc, doc.lines_outside("Fixes"), INDEX_HEADER, "task table")
        if not main_rows:
            self.add("MISSING_SECTION", index, 0, "task table is missing or has no rows")
        files = self.task_files("tasks", r"(\d{3})-.+\.md")
        covered = set()
        for number, row, path in self.match_rows(main_rows, files, "ID", TASK_ID_RE, index):
            covers, log = self.check_task_file(path, row["ID"])
            row_covers = self.parse_covers(row["Covers"], index, number)
            if row_covers != covers:
                self.add("COVERS_MISMATCH", index, number, f"{row['ID']} Covers differs from its file")
            covered |= row_covers
            self.check_status(path, number, row["Status"], log, ("pending", "done"), ())
            self.main_tasks.append((number, row["ID"], row["Status"]))
        scope = self.spec / "scope.md"
        for ac in sorted(self.acs - covered):
            self.add("UNCOVERED_AC", scope, 0, f"{ac} is not covered by any task")
        self.check_fixes(doc)

    def check_fixes(self, doc):
        body = doc.section("Fixes")
        rows = self.table(doc, body, FIXES_HEADER, "fixes table") if body is not None else []
        files = self.task_files("fixes", r"(fix-(\d{3}))-.+\.md")
        allowed = ("pending", "in-progress", "done", "passed", "failed")
        for number, row, path in self.match_rows(rows, files, "Fix ID", FIX_ID_RE, doc.path):
            covers, log = self.check_task_file(path, row["Fix ID"])
            if self.parse_covers(row["Covers"], doc.path, number) != covers:
                self.add("COVERS_MISMATCH", doc.path, number, f"{row['Fix ID']} Covers differs from its file")
            commit = self.check_status(path, number, row["Status"], log, allowed, ("passed", "failed"))
            self.fixes.append((number, row["Status"], commit))
        failed = 0
        for position, (number, status, _) in enumerate(self.fixes):
            if failed == MAX_FAILED_FIXES:
                self.add("FIX_SEQUENCE", doc.path, number, f"no fix may follow the {MAX_FAILED_FIXES}rd failed fix")
            failed += status == "failed"
            if self.is_open(status) and position != len(self.fixes) - 1:
                self.add("FIX_SEQUENCE", doc.path, number, "only the last fix may be open")

    @staticmethod
    def is_open(status):
        return status in OPEN_FIX_STATUSES or bool(DONE_RE.fullmatch(status))

    def require_tasks_done(self):
        for number, task_id, status in self.main_tasks:
            if not DONE_RE.fullmatch(status):
                self.add("BAD_STATUS", self.spec / "tasks.index.md", number, f"task {task_id} is not done")
        for number, status, _ in self.fixes:
            if status in OPEN_FIX_STATUSES:
                self.add("BAD_STATUS", self.spec / "tasks.index.md", number, f"fix is '{status}': implement it before verifying")

    def interrupted_fix_update(self, verified):
        if not self.fixes or not verified:
            return False
        _, status, commit = self.fixes[-1]
        if not DONE_RE.fullmatch(status) or commit is None:
            return False
        return self.is_ancestor(commit, verified) and not self.is_stale(verified)

    def check_verify(self):
        doc = self.document("verify.md")
        if doc is None:
            return None, None, False
        body = self.required_section(doc, "Status")
        status = first_value(body)[1] if body else None
        if status not in (None, "PASS", "FAIL"):
            self.add("BAD_STATUS", doc.path, first_value(body)[0], "status must be PASS or FAIL")
        ticked = {}
        for line, text in entries(self.required_section(doc, "Acceptance criteria") or []):
            match = re.match(r"- \[([ x])\] (AC-\d{3})\b", text)
            if not match:
                self.add("BAD_ID", doc.path, line, "entry must start with '- [x] AC-NNN' or '- [ ] AC-NNN'")
            elif match.group(2) in ticked:
                self.add("DUPLICATE_ID", doc.path, line, f"{match.group(2)} is listed twice")
            elif match.group(2) not in self.acs:
                self.add("UNKNOWN_AC", doc.path, line, f"{match.group(2)} is not defined in scope.md")
            else:
                ticked[match.group(2)] = match.group(1) == "x"
        for ac in sorted(self.acs - ticked.keys()):
            self.add("VERIFY_INCONSISTENT", doc.path, 0, f"{ac} is missing from verify.md")
        verified = self.check_closure(doc)
        reconcile = self.interrupted_fix_update(verified)
        if status == "PASS":
            if any(not DONE_RE.fullmatch(s) for _, _, s in self.main_tasks):
                self.add("VERIFY_INCONSISTENT", doc.path, 0, "PASS with tasks not done")
            if not all(ticked.values()):
                self.add("VERIFY_INCONSISTENT", doc.path, 0, "PASS with unmet acceptance criteria")
            if any(self.is_open(s) for _, s, _ in self.fixes) and not reconcile:
                self.add("VERIFY_INCONSISTENT", doc.path, 0, "PASS with an open fix")
        return status, verified, reconcile

    def check_closure(self, doc):
        body = self.required_section(doc, "Local closure")
        values = {}
        for line, text in entries(body or []):
            match = re.fullmatch(r"- (Base commit|Verified commit): (\S+)", text.strip())
            if match:
                values[match.group(1)] = (line, match.group(2))
        for key in ("Base commit", "Verified commit"):
            if key not in values and body is not None:
                self.add("MISSING_SECTION", doc.path, 0, f"'- {key}:' is missing from Local closure")
        if "Base commit" in values and self.base:
            line, value = values["Base commit"]
            if self.resolve(value) != self.base:
                self.add("VERIFY_INCONSISTENT", doc.path, line, "base commit differs from intake.md")
        if "Verified commit" in values:
            line, value = values["Verified commit"]
            return self.feature_commit(value, doc.path, line)
        return None

    def is_stale(self, verified):
        if verified not in self.stale:
            exclude = f":(exclude).spec/{self.slug}"
            outputs = []
            for args in (("diff", "--name-only", verified, "HEAD"), ("status", "--porcelain")):
                result = self.git(*args, "--", ".", exclude)
                if result.returncode != 0:
                    raise CheckError(f"git {args[0]} failed with exit code {result.returncode}")
                outputs.append(result.stdout.strip())
            self.stale[verified] = any(outputs)
        return self.stale[verified]

    def run(self, phase):
        if self.spec.is_dir() and (self.spec / "plan.md").exists() and not (self.spec / "intake.md").exists():
            raise CheckError("unsupported format: plan.md (Full SDD only)")
        if not self.spec.is_dir() or not any(self.spec.iterdir()):
            self.add("MISSING_FILE", self.spec, 0, "feature folder is missing or empty")
            return None
        if phase == "resume":
            return self.resume()
        self.check_intake()
        self.check_scope()
        if phase in ("plan", "verify"):
            self.check_plan()
        if phase == "verify":
            self.require_tasks_done()
            if (self.spec / "verify.md").exists():
                self.check_verify()
        return None

    def resume(self):
        has = {name: (self.spec / name).exists() for name in ("intake.md", "scope.md", "design.md", "tasks.index.md", "verify.md")}
        has_tasks = any((self.spec / "tasks").glob("*.md"))
        has_fixes = any((self.spec / "fixes").glob("*.md"))
        if has["verify.md"] and not (has["design.md"] and has["tasks.index.md"]):
            self.add("BAD_STATE", self.spec / "verify.md", 0, "verify.md exists without a complete plan")
        if has["tasks.index.md"] and not has["design.md"]:
            self.add("BAD_STATE", self.spec / "tasks.index.md", 0, "tasks.index.md exists without design.md")
        if (has["design.md"] or has_tasks) and not has["tasks.index.md"]:
            self.add("PLAN_INCOMPLETE", self.spec, 0, "planning was interrupted: tasks.index.md is missing")
        if has_fixes and not has["tasks.index.md"]:
            self.add("BAD_STATE", self.spec / "fixes", 0, "fix files exist without tasks.index.md")
        if (has["design.md"] or has["tasks.index.md"]) and not has["scope.md"]:
            self.add("BAD_STATE", self.spec, 0, "planning artifacts exist without scope.md")
        self.check_intake()
        if not has["scope.md"]:
            return "intake"
        self.check_scope()
        if not has["tasks.index.md"]:
            return "scope"
        self.check_plan()
        if not has["verify.md"]:
            return "plan"
        status, verified, reconcile = self.check_verify()
        if reconcile:
            return "verify-reconcile"
        if status != "PASS":
            return "verify-fail"
        return "verify-pass-stale" if verified and self.is_stale(verified) else "verify-pass"


def parse_args(argv):
    if len(argv) not in (2, 4) or argv[0] != "check":
        raise CheckError(USAGE)
    slug, phase = argv[1], "resume"
    if len(argv) == 4:
        if argv[2] != "--phase" or argv[3] not in PHASES:
            raise CheckError(USAGE)
        phase = argv[3]
    if not SLUG_RE.fullmatch(slug):
        raise CheckError(f"invalid feature slug '{slug}'")
    return slug, phase


def repository_root():
    if shutil.which("git") is None:
        raise CheckError("git is not available on PATH")
    result = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, encoding="utf-8")
    if result.returncode != 0:
        raise CheckError("not inside a git work tree")
    return Path(result.stdout.strip())


def main(argv):
    try:
        if sys.version_info < (3, 11):
            raise CheckError("Python 3.11+ is required")
        slug, phase = parse_args(argv)
        checker = Checker(repository_root(), slug)
        state = checker.run(phase)
    except (CheckError, UnicodeDecodeError) as error:
        print(f"ERROR {error}")
        return 2
    if checker.findings:
        for path, line, code, message in sorted(checker.findings):
            print(f"{code} {path}:{line}: {message}")
        return 1
    print(f"OK resume: {state}" if phase == "resume" else f"OK {phase}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
