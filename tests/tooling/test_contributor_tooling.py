from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def load_script(name: str, relative_path: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {relative_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class ContributorGovernanceTests(unittest.TestCase):
    def test_codeowners_separates_required_domains(self) -> None:
        body = (ROOT / ".github/CODEOWNERS").read_text(encoding="utf-8")
        for path in ("/battle/", "/fighter/", "/frontend/", "/presentation/", "/assets/", "/content/characters/", "/server/"):
            self.assertIn(path, body)

    def test_role_templates_are_selectable_and_role_specific(self) -> None:
        template_root = ROOT / ".github/PULL_REQUEST_TEMPLATE"
        expected = {"balance", "art", "skill", "frontend", "backend"}
        self.assertEqual({path.stem for path in template_root.glob("*.md")}, expected)
        chooser = (ROOT / ".github/PULL_REQUEST_TEMPLATE.md").read_text(encoding="utf-8")
        for role in expected:
            self.assertIn(f"template={role}.md", chooser)
            body = (template_root / f"{role}.md").read_text(encoding="utf-8")
            self.assertIn("## Scope", body)
            self.assertIn("## Verification", body)
            self.assertIn("NOT EXECUTED", body)


class ArtManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.art = load_script("build_art_manifest", "scripts/build_art_manifest.py")

    def test_example_manifest_is_valid_and_deterministic(self) -> None:
        manifest = ROOT / "assets/presentation/examples/art_build.example.json"
        first = self.art.load_and_validate_manifest(manifest, ROOT)
        second = self.art.load_and_validate_manifest(manifest, ROOT)
        self.assertEqual(first, second)
        self.assertEqual(first["schema_version"], 1)
        self.assertEqual([job["id"] for job in first["jobs"]], sorted(job["id"] for job in first["jobs"]))

    def test_manifest_rejects_duplicate_ids_unknown_fields_and_path_escape(self) -> None:
        base_job = {
            "id": "projectile",
            "type": "effect",
            "spec": "assets/presentation/examples/projectile_pack.example.json",
        }
        cases = [
            {"schema_version": 1, "jobs": [base_job, dict(base_job)]},
            {"schema_version": 1, "jobs": [{**base_job, "surprise": True}]},
            {"schema_version": 1, "jobs": [{**base_job, "spec": "../outside.json"}]},
        ]
        for payload in cases:
            with self.subTest(payload=payload):
                with tempfile.TemporaryDirectory() as directory:
                    path = Path(directory) / "manifest.json"
                    path.write_text(json.dumps(payload), encoding="utf-8")
                    with self.assertRaises(ValueError):
                        self.art.load_and_validate_manifest(path, ROOT)

    def test_output_root_is_restricted_to_character_assets(self) -> None:
        with self.assertRaises(ValueError):
            self.art._contained_output_path(ROOT, "data", "unsafe output")
        allowed = self.art._contained_output_path(
            ROOT,
            "assets/characters/magic_orange_cat/effects/example",
            "safe output",
        )
        self.assertEqual(
            allowed,
            ROOT / "assets/characters/magic_orange_cat/effects/example",
        )


class MergeSimulationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.simulation = load_script("simulate_contributor_merges", "scripts/simulate_contributor_merges.py")

    def test_plan_targets_one_character_with_disjoint_paths(self) -> None:
        plan = self.simulation.simulation_plan(ROOT)
        self.assertEqual(plan["target_character"], "magic_orange_cat")
        roles = plan["roles"]
        self.assertEqual(set(roles), {"art", "balance", "frontend", "skill"})
        paths = [item["path"] for item in roles.values()]
        self.assertEqual(len(paths), len(set(paths)))
        self.simulation.validate_plan(plan, ROOT)

    def test_live_simulation_merges_all_roles(self) -> None:
        report = self.simulation.run_simulation(ROOT)
        self.assertEqual(report["status"], "PASS")
        self.assertEqual(report["merged_roles"], ["art", "balance", "frontend", "skill"])


class DocumentationContractTests(unittest.TestCase):
    def test_balance_strategy_contains_required_safety_gates(self) -> None:
        body = (ROOT / "docs/architecture/BALANCE_WORKFLOW.md").read_text(encoding="utf-8")
        for phrase in ("stable IDs", "schema validation", "diff preview", "raw overwrite", "export-only"):
            self.assertIn(phrase, body)

    def test_mechanic_guide_contains_required_decisions_and_state_checklist(self) -> None:
        body = (ROOT / "docs/contributors/MECHANIC_AUTHORING_GUIDE.md").read_text(encoding="utf-8")
        for phrase in ("GameplayEffectData", "CharacterMechanicsData", "runtime component", "snapshot", "restore", "hash", "replay"):
            self.assertIn(phrase, body)


if __name__ == "__main__":
    unittest.main()
