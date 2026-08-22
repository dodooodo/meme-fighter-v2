from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.validate_task import git_paths, parse_packet, task_path_from_branch, validate_metadata


def packet_text(task_id: str, status: str = "ready", dependencies: str = "[]") -> str:
    return f"""---
id: {task_id}
stage: A
type: tooling
status: {status}
dependencies: {dependencies}
allowed_paths: [scripts/]
forbidden_paths: [battle/]
required_specs: [AGENTS.md]
required_checks: [python3 scripts/static_validate.py]
---
"""


class ValidateTaskTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        (self.root / "docs/tasks/active").mkdir(parents=True)
        (self.root / "docs/tasks/completed").mkdir(parents=True)
        (self.root / "AGENTS.md").write_text("rules", encoding="utf-8")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_packet(self, task_id: str, status: str = "ready", dependencies: str = "[]", completed: bool = False) -> Path:
        folder = "completed" if completed else "active"
        path = self.root / f"docs/tasks/{folder}/{task_id}.md"
        path.write_text(packet_text(task_id, status, dependencies), encoding="utf-8")
        return path

    def test_branch_resolves_exact_active_packet(self) -> None:
        expected = self.write_packet("A-GOV-001", status="in_progress")
        self.assertEqual(task_path_from_branch("task/A-GOV-001-enforcement-stabilization", self.root), expected)

    def test_branch_rejects_non_task_convention(self) -> None:
        with self.assertRaisesRegex(ValueError, "branch must match"):
            task_path_from_branch("feature/governance", self.root)

    def test_filename_must_match_frontmatter_id(self) -> None:
        path = self.root / "docs/tasks/active/A-GOV-999.md"
        path.write_text(packet_text("A-GOV-001"), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "does not match id"):
            validate_metadata(parse_packet(path), path, self.root)

    def test_ready_task_rejects_unfinished_dependency(self) -> None:
        self.write_packet("A-RUN-001", status="ready")
        path = self.write_packet("A-RUN-003", dependencies="[A-RUN-001]")
        with self.assertRaisesRegex(ValueError, "unfinished dependencies"):
            validate_metadata(parse_packet(path), path, self.root)

    def test_blocked_task_allows_unfinished_dependency(self) -> None:
        self.write_packet("A-RUN-001", status="ready")
        path = self.write_packet("A-RUN-003", status="blocked", dependencies="[A-RUN-001]")
        validate_metadata(parse_packet(path), path, self.root)

    def test_committed_diff_is_measured_from_base(self) -> None:
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "config", "user.email", "test@example.invalid"], cwd=self.root, check=True)
        subprocess.run(["git", "config", "user.name", "Task Test"], cwd=self.root, check=True)
        scripts = self.root / "scripts"
        scripts.mkdir()
        file_path = scripts / "example.py"
        file_path.write_text("before\n", encoding="utf-8")
        subprocess.run(["git", "add", "."], cwd=self.root, check=True)
        subprocess.run(["git", "commit", "-qm", "base"], cwd=self.root, check=True)
        base = subprocess.run(["git", "rev-parse", "HEAD"], cwd=self.root, check=True, text=True, capture_output=True).stdout.strip()
        file_path.write_text("after\n", encoding="utf-8")
        subprocess.run(["git", "add", "scripts/example.py"], cwd=self.root, check=True)
        subprocess.run(["git", "commit", "-qm", "change"], cwd=self.root, check=True)
        self.assertEqual(git_paths(base, self.root), ["scripts/example.py"])


if __name__ == "__main__":
    unittest.main()
