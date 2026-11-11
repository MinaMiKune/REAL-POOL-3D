#!/usr/bin/env python3
"""Static Stage 1 documentation, link, requirement, ADR, and scope checks."""

from __future__ import annotations

import argparse
import json
import platform
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

HERE = Path(__file__).resolve().parent
ARCH = HERE.parent
ROOT = ARCH.parent.parent

REQUIRED_DOCS = [
    "README.md",
    *(f"{index:02d}-{name}.md" for index, name in [
        (1, "overview"),
        (2, "module-interfaces"),
        (3, "physics-model"),
        (4, "rules-and-ai"),
        (5, "network-protocol"),
        (6, "data-and-replay"),
        (7, "android-and-rendering"),
        (8, "performance-testing-diagnostics"),
        (9, "technology-evidence"),
        (10, "risk-register"),
        (11, "requirements-traceability"),
        (12, "stage2-roadmap"),
        (13, "validation-report"),
        (14, "environment-preparation"),
    ]),
    "adr/README.md",
    "validation/README.md",
]

ADR_NAMES = [
    "ADR-001-godot-4-7-2-gdscript.md",
    "ADR-002-custom-2-5d-physics.md",
    "ADR-003-wpa-rules-reducer.md",
    "ADR-004-lan-host-enet.md",
    "ADR-005-sqlite-conditional-v4-9.md",
    "ADR-006-snapshot-command-replay.md",
    "ADR-007-responsive-touch-input.md",
    "ADR-008-renderer-device-gate.md",
    "ADR-009-android-api37.md",
    "ADR-010-ai-fairness-and-seeds.md",
]


def check_required_files() -> dict:
    missing = [name for name in REQUIRED_DOCS if not (ARCH / name).is_file()]
    missing.extend(f"adr/{name}" for name in ADR_NAMES if not (ARCH / "adr" / name).is_file())
    required_non_md = ["schema_v1.sql", "physics_model_probe.py", "sqlite_schema_probe.py", "check_architecture_docs.py"]
    missing.extend(f"validation/{name}" for name in required_non_md if not (HERE / name).is_file())
    if missing:
        raise AssertionError(f"missing required files: {missing}")
    small = []
    for path in ARCH.rglob("*.md"):
        text = path.read_text(encoding="utf-8")
        if len(text.strip()) < 300 or not text.startswith("#"):
            small.append(str(path.relative_to(ROOT)))
    if small:
        raise AssertionError(f"empty/stub-like markdown: {small}")
    return {"required_documents": len(REQUIRED_DOCS) + len(ADR_NAMES), "markdown_files": len(list(ARCH.rglob('*.md'))), "stubs": small}


def check_no_placeholders() -> dict:
    patterns = [r"\bTODO\b", r"\bTBD\b", r"待补充", r"lorem ipsum", r"<placeholder>"]
    findings = []
    for path in ARCH.rglob("*.md"):
        text = path.read_text(encoding="utf-8")
        for pattern in patterns:
            if re.search(pattern, text, flags=re.IGNORECASE):
                findings.append({"file": str(path.relative_to(ROOT)), "pattern": pattern})
    if findings:
        raise AssertionError(f"placeholder markers found: {findings}")
    return {"files_scanned": len(list(ARCH.rglob('*.md'))), "findings": findings}


def check_local_links() -> dict:
    link_pattern = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
    broken = []
    checked = 0
    for path in ARCH.rglob("*.md"):
        text = path.read_text(encoding="utf-8")
        for raw_target in link_pattern.findall(text):
            target = raw_target.strip().split()[0].strip("<>")
            if target.startswith(("https://", "http://", "mailto:", "#")):
                continue
            target = target.split("#", 1)[0]
            if not target:
                continue
            checked += 1
            resolved = (path.parent / target).resolve()
            try:
                resolved.relative_to(ROOT.resolve())
            except ValueError:
                broken.append({"file": str(path.relative_to(ROOT)), "target": raw_target, "reason": "outside workspace"})
                continue
            if not resolved.exists():
                broken.append({"file": str(path.relative_to(ROOT)), "target": raw_target, "reason": "not found"})
    if broken:
        raise AssertionError(f"broken local links: {broken}")
    return {"local_links_checked": checked, "broken": broken}


def check_adr_sections() -> dict:
    required = ["## 背景", "## 备选方案", "## 理由", "## 代价", "## 风险与降级", "## 验证方法"]
    findings = []
    for name in ADR_NAMES:
        path = ARCH / "adr" / name
        text = path.read_text(encoding="utf-8")
        missing = [heading for heading in required if heading not in text]
        if missing:
            findings.append({"file": name, "missing": missing})
    if findings:
        raise AssertionError(f"incomplete ADRs: {findings}")
    return {"adrs_checked": len(ADR_NAMES), "required_sections": required}


def check_requirements_and_risks() -> dict:
    trace = (ARCH / "11-requirements-traceability.md").read_text(encoding="utf-8")
    missing_requirements = [f"REQ-{index:02d}" for index in range(1, 19) if f"REQ-{index:02d}" not in trace]
    risks = (ARCH / "10-risk-register.md").read_text(encoding="utf-8")
    missing_risks = [f"R-{index:02d}" for index in range(1, 23) if f"R-{index:02d}" not in risks]
    if missing_requirements or missing_risks:
        raise AssertionError(f"missing requirements={missing_requirements}, risks={missing_risks}")
    return {"requirements": 18, "risks_including_stage0_and_new": 22}


def check_stage_scope() -> dict:
    forbidden = []
    if (ROOT / "project.godot").exists():
        forbidden.append("project.godot")
    for pattern in ("src/**/*.gd", "tests/**/*.gd", "*.tscn", "*.scn", "addons/**", "android/**"):
        matches = [str(path.relative_to(ROOT)) for path in ROOT.glob(pattern) if path.is_file()]
        forbidden.extend(matches)
    if forbidden:
        raise AssertionError(f"Stage 2/runtime files found: {forbidden}")
    ignored = (ROOT / ".gitignore").read_text(encoding="utf-8")
    entries = [".godot/", ".gradle/", "build/", "android/build/", "local.properties", "*.keystore", "*.jks", "*.apk", "*.aab"]
    missing = [entry for entry in entries if entry not in ignored.splitlines()]
    if missing or "export_presets.cfg" in ignored.splitlines():
        raise AssertionError(f"gitignore missing={missing}, export preset incorrectly ignored={'export_presets.cfg' in ignored.splitlines()}")
    return {"runtime_files_found": forbidden, "required_gitignore_entries": entries, "export_presets_tracked_allowed": True}


def check_evidence_pins() -> dict:
    evidence = (ARCH / "09-technology-evidence.md").read_text(encoding="utf-8")
    required = [
        "4.7.2-stable",
        "v4.9",
        "95e91b72fe32984a84edaf6357a78753661f37a170cb362f5b948e0ede7c2cb0",
        "compatibility_minimum=\"4.7\"",
        "ACCESS_LOCAL_NETWORK",
        "Public Domain",
        "2026-10-21",
    ]
    missing = [value for value in required if value not in evidence]
    if missing:
        raise AssertionError(f"evidence pins missing: {missing}")
    return {"pins_checked": required}


CHECKS: list[tuple[str, Callable[[], dict]]] = [
    ("required_files_and_nonempty_documents", check_required_files),
    ("no_placeholder_documents", check_no_placeholders),
    ("local_markdown_links", check_local_links),
    ("adr_required_sections", check_adr_sections),
    ("requirements_and_risk_ids", check_requirements_and_risks),
    ("stage1_scope_and_gitignore", check_stage_scope),
    ("official_evidence_version_pins", check_evidence_pins),
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=HERE / "results" / "documentation_check_results.json")
    args = parser.parse_args()
    # The documents link to this generated report; make the self-link valid on a clean first run.
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.touch(exist_ok=True)
    results = []
    for name, check in CHECKS:
        try:
            details = check()
            results.append({"name": name, "status": "PASS", "details": details})
        except Exception as exc:
            results.append({"name": name, "status": "FAIL", "error": f"{type(exc).__name__}: {exc}"})
    passed = sum(item["status"] == "PASS" for item in results)
    failed = len(results) - passed
    report = {
        "probe": "stage1-architecture-documentation-v1",
        "executed_at_utc": datetime.now(timezone.utc).isoformat(),
        "python": platform.python_version(),
        "platform": platform.platform(),
        "workspace": str(ROOT),
        "summary": {"PASS": passed, "FAIL": failed, "total": len(results)},
        "checks": results,
        "limitations": [
            "Static checks do not prove technical accuracy, runtime compatibility, visual quality, or implementation completeness.",
            "External URLs require the separately recorded source review; this script checks local links only.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
