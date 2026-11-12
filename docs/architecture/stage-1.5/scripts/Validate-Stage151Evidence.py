#!/usr/bin/env python3
"""Validate stage 1.5.1 evidence without rerunning the host audit."""

from collections import Counter
import json
from pathlib import Path
import re
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[4]
STAGE_DIR = ROOT / "docs/architecture/stage-1.5"
RESULTS_DIR = STAGE_DIR / "results"
REPORT_PATH = STAGE_DIR / "01-windows-environment-audit.md"
FINAL_PATH = RESULTS_DIR / "environment-audit.json"
ARCHIVE_NAMES = (
    "environment-audit.initial_fail.json",
    "environment-audit.run2.json",
    "environment-audit.run3.json",
    "environment-audit.json",
)
REQUIRED_CHECK_FIELDS = {
    "id",
    "category",
    "purpose",
    "prerequisites",
    "command",
    "workingDirectory",
    "expected",
    "startedAtLocal",
    "durationMilliseconds",
    "status",
    "exitCode",
    "powershellSucceeded",
    "error",
    "observed",
    "evidence",
    "firstFailure",
    "rerun",
    "limitations",
    "followUp",
}
EXPECTED_ATTEMPTS = ["initial-launch", "run1", "run2", "run3", "run4"]


def load_json(path: Path):
    with path.open("r", encoding="utf-8-sig") as handle:
        return json.load(handle)


def normalized_summary(summary: dict) -> dict:
    normalized = dict(summary)
    if "NOT_RUN" in normalized:
        normalized["NOT RUN"] = normalized.pop("NOT_RUN")
    return normalized


archives = {name: load_json(RESULTS_DIR / name) for name in ARCHIVE_NAMES}
assert len(archives) == 4
final = archives["environment-audit.json"]
assert final["project"] == "REAL-POOL-3D"
assert final["stage"] == "1.5.1"

checks = final["checks"]
assert len(checks) == 31
ids = [check["id"] for check in checks]
assert len(set(ids)) == len(ids)
allowed_statuses = {"PASS", "FAIL", "BLOCKED", "NOT RUN", "NOT_RUN"}

for check in checks:
    missing = REQUIRED_CHECK_FIELDS - set(check)
    assert not missing, (check.get("id"), sorted(missing))
    assert check["status"] in allowed_statuses, check["id"]
    assert isinstance(check["durationMilliseconds"], (int, float))
    assert not isinstance(check["durationMilliseconds"], bool)
    assert check["durationMilliseconds"] >= 0, check["id"]
    exit_code = check["exitCode"]
    assert exit_code is None or (
        isinstance(exit_code, int) and not isinstance(exit_code, bool)
    ), check["id"]
    assert isinstance(check["evidence"], list) and check["evidence"], check["id"]
    for relative_path in check["evidence"]:
        assert (ROOT / relative_path).is_file(), (check["id"], relative_path)

observed_summary = Counter(
    "NOT RUN" if check["status"] == "NOT_RUN" else check["status"]
    for check in checks
)
expected_summary = {"PASS": 17, "FAIL": 4, "BLOCKED": 10, "NOT RUN": 0}
assert final["summary"] == expected_summary
for status, count in expected_summary.items():
    assert observed_summary[status] == count, status
assert sum(observed_summary.values()) == len(checks)

history = final["executionHistory"]
assert [entry["attempt"] for entry in history] == EXPECTED_ATTEMPTS
for entry in history:
    evidence = entry["evidence"]
    evidence_paths = [evidence] if isinstance(evidence, str) else evidence
    assert evidence_paths, entry["attempt"]
    for relative_path in evidence_paths:
        assert (ROOT / relative_path).is_file(), (entry["attempt"], relative_path)
    if "summary" not in entry:
        continue
    json_evidence = [path for path in evidence_paths if path.endswith(".json")]
    assert len(json_evidence) == 1, entry["attempt"]
    archive_name = Path(json_evidence[0]).name
    archived = archives[archive_name]
    # Execution history uses NOT_RUN; archived audit summaries use NOT RUN.
    expected = normalized_summary(entry["summary"])
    assert expected == archived["summary"], entry["attempt"]
    archived_counts = Counter(
        "NOT RUN" if check["status"] == "NOT_RUN" else check["status"]
        for check in archived["checks"]
    )
    for status, count in expected.items():
        assert archived_counts[status] == count, (entry["attempt"], status)

scope = final["scope"]
assert scope and all(value is False for value in scope.values())

report = REPORT_PATH.read_text(encoding="utf-8-sig")
local_links = []
for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", report):
    if not target.startswith("./"):
        continue
    target_path = unquote(target.split("#", 1)[0].split(" ", 1)[0])
    resolved = (REPORT_PATH.parent / target_path).resolve()
    assert resolved.is_file(), target
    assert STAGE_DIR.resolve() in resolved.parents, target
    local_links.append(target)
assert local_links

# Scan persisted evidence for unredacted local paths and enumerate every GPU
# identifier value instead of relying on unsupported regex look-around.
absolute_path_pattern = re.compile(r"[A-Za-z]:[\\/]+(?:Kimi|Users[\\/])")
for path in STAGE_DIR.rglob("*"):
    if path.is_file():
        text = path.read_text(encoding="utf-8-sig")
        assert not absolute_path_pattern.search(text), path

gpu_identifier_pattern = re.compile(
    r"(deviceUUID|driverUUID|deviceLUID)\b\s*=\s*([^\r\n,\"]+)"
)
allowed_gpu_values = {
    "deviceUUID": "<GPU_DEVICE_UUID>",
    "driverUUID": "<GPU_DRIVER_UUID>",
    "deviceLUID": "<GPU_DEVICE_LUID>",
}
gpu_identifier_count = 0
for path in RESULTS_DIR.glob("*"):
    if not path.is_file():
        continue
    text = path.read_text(encoding="utf-8-sig")
    for match in gpu_identifier_pattern.finditer(text):
        name, value = match.groups()
        assert value.strip() == allowed_gpu_values[name], (path, name)
        gpu_identifier_count += 1
assert gpu_identifier_count > 0

workspace_entries = [
    path for path in ROOT.rglob("*") if ".git" not in path.parts
]
forbidden_project_files = [
    path
    for path in workspace_entries
    if path.is_file()
    and (path.name == "project.godot" or path.suffix in {".gd", ".tscn"})
]
assert not forbidden_project_files, forbidden_project_files
poc_directories = [
    path
    for path in workspace_entries
    if path.is_dir() and path.name.lower() == "poc"
]
assert not poc_directories, poc_directories

print("EVIDENCE_VALIDATION PASS")
print(f"json_files {len(archives)}")
print(f"checks {len(checks)}")
print(
    "summary "
    f"{expected_summary['PASS']}/{expected_summary['FAIL']}/"
    f"{expected_summary['BLOCKED']}/{expected_summary['NOT RUN']}"
)
print(f"history {','.join(EXPECTED_ATTEMPTS)}")
print(f"markdown_local_links {len(local_links)}")
print(f"scope_flags {len(scope)} all false")
print("privacy_path_matches 0")
print(f"gpu_identifier_values {gpu_identifier_count} all placeholders")
print("forbidden_project_files 0")
print("poc_directories 0")
