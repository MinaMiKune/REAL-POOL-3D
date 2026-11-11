#!/usr/bin/env python3
"""Exercise the Stage 1 SQL draft with Python sqlite3, not godot-sqlite."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import shutil
import sqlite3
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

HERE = Path(__file__).resolve().parent
SCHEMA = HERE / "schema_v1.sql"
NOW = "2026-11-11T00:00:00Z"
MATCH_ID = "0" * 32
SHOT_ID = "1" * 32
REPLAY_ID = "2" * 32
HASH_A = "a" * 64
HASH_B = "b" * 64


def open_db(path: Path, apply_schema: bool = True) -> sqlite3.Connection:
    connection = sqlite3.connect(path)
    try:
        connection.execute("PRAGMA foreign_keys = ON")
        if apply_schema:
            schema_bytes = SCHEMA.read_bytes()
            connection.executescript(schema_bytes.decode("utf-8"))
            connection.execute(
                """INSERT INTO schema_migrations (version, script_name, sha256, applied_at)
                   VALUES (1, 'schema_v1.sql', ?, ?)""",
                (hashlib.sha256(schema_bytes).hexdigest(), NOW),
            )
            connection.commit()
    except Exception:
        connection.close()
        raise
    return connection


def insert_match(connection: sqlite3.Connection, match_id: str = MATCH_ID) -> None:
    connection.execute(
        """INSERT INTO matches (
            match_id, mode, status, rules_version, physics_version, protocol_version,
            players_json, current_snapshot_json, current_revision,
            current_shot_ordinal, created_at, updated_at
        ) VALUES (?, 'OFFLINE_AI', 'IN_PROGRESS', ?, ?, ?, ?, ?, 0, 0, ?, ?)""",
        (
            match_id,
            "WPA_2026_DIGITAL_V1",
            "pool-physics-1.0",
            "1.0",
            json.dumps([{"seat": 0, "name": '"); DROP TABLE matches;--'}, {"seat": 1, "name": "AI"}]),
            json.dumps({"phase": "AWAIT_BREAK", "balls": []}),
            NOW,
            NOW,
        ),
    )


def commit_shot(
    connection: sqlite3.Connection,
    payload: bytes = b"replay-chunk-0",
    termination: str = "AT_REST",
) -> str:
    digest = hashlib.sha256(payload).hexdigest()
    connection.execute("BEGIN IMMEDIATE")
    connection.execute(
        """INSERT INTO shots (
            match_id, ordinal, shot_id, shot_kind, turn_serial, shooter_seat,
            command_json, events_json, final_snapshot_json, pre_state_hash,
            post_state_hash, tick_count, termination, created_at
        ) VALUES (?, 1, ?, 'BREAK', 0, 0, ?, ?, ?, ?, ?, 240, ?, ?)""",
        (
            MATCH_ID,
            SHOT_ID,
            json.dumps({"aim_angle": 0.0, "power": 0.8}),
            json.dumps([{"sequence": 0, "type": "SHOT_AT_REST"}]),
            json.dumps({"phase": "AWAIT_SHOT", "open_table": True}),
            HASH_A,
            HASH_B,
            termination,
            NOW,
        ),
    )
    connection.execute(
        """INSERT INTO replays (
            replay_id, match_id, format_version, initial_snapshot_json,
            version_set_json, first_break_seed, rng_algorithm, status,
            final_state_hash, record_count, created_at, completed_at
        ) VALUES (?, ?, 'pool-replay-1', ?, ?, 'seed-0', 'test-prng-v1',
                  'COMPLETE', ?, 1, ?, ?)""",
        (
            REPLAY_ID,
            MATCH_ID,
            json.dumps({"phase": "AWAIT_BREAK"}),
            json.dumps({"physics": "pool-physics-1.0", "rules": "WPA_2026_DIGITAL_V1"}),
            HASH_B,
            NOW,
            NOW,
        ),
    )
    connection.execute(
        "INSERT INTO replay_chunks (replay_id, ordinal, payload, sha256, created_at) VALUES (?, 0, ?, ?, ?)",
        (REPLAY_ID, payload, digest, NOW),
    )
    connection.execute(
        "UPDATE matches SET current_revision = 1, current_shot_ordinal = 1, current_snapshot_json = ?, updated_at = ? WHERE match_id = ?",
        (json.dumps({"phase": "AWAIT_SHOT", "open_table": True}), NOW, MATCH_ID),
    )
    connection.commit()
    return digest


def check_schema() -> dict:
    with tempfile.TemporaryDirectory(dir=HERE / ".tmp") as directory:
        connection = open_db(Path(directory) / "schema.db")
        tables = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        expected = {"schema_migrations", "settings", "matches", "shots", "replays", "replay_chunks", "training_attempts"}
        version = connection.execute("PRAGMA user_version").fetchone()[0]
        foreign_keys = connection.execute("PRAGMA foreign_keys").fetchone()[0]
        baseline = connection.execute(
            "SELECT version, script_name, sha256 FROM schema_migrations"
        ).fetchall()
        connection.close()
        expected_hash = hashlib.sha256(SCHEMA.read_bytes()).hexdigest()
        if not expected.issubset(tables):
            raise AssertionError(f"missing tables: {sorted(expected - tables)}")
        if version != 1 or foreign_keys != 1:
            raise AssertionError(f"user_version={version}, foreign_keys={foreign_keys}")
        if baseline != [(1, "schema_v1.sql", expected_hash)]:
            raise AssertionError(f"invalid baseline migration: {baseline}")
        return {
            "tables": sorted(expected),
            "user_version": version,
            "foreign_keys": foreign_keys,
            "baseline_migration": {"version": 1, "script_name": "schema_v1.sql", "sha256": expected_hash},
        }


def check_parameterized_crud() -> dict:
    with tempfile.TemporaryDirectory(dir=HERE / ".tmp") as directory:
        connection = open_db(Path(directory) / "crud.db")
        insert_match(connection)
        connection.execute(
            "INSERT INTO settings (key, value_json, value_version, updated_at) VALUES (?, ?, 1, ?)",
            ("rendering.quality", json.dumps({"preset": "MEDIUM"}), NOW),
        )
        connection.commit()
        name = json.loads(connection.execute("SELECT players_json FROM matches WHERE match_id = ?", (MATCH_ID,)).fetchone()[0])[0]["name"]
        table_count = connection.execute("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='matches'").fetchone()[0]
        quality = connection.execute("SELECT value_json FROM settings WHERE key = ?", ("rendering.quality",)).fetchone()[0]
        if name != '"); DROP TABLE matches;--' or table_count != 1 or json.loads(quality)["preset"] != "MEDIUM":
            raise AssertionError("parameterized values were not preserved")
        connection.close()
        return {"hostile_text_preserved": name, "matches_table_count": table_count, "quality": json.loads(quality)}


def check_shot_transaction_and_hash() -> dict:
    with tempfile.TemporaryDirectory(dir=HERE / ".tmp") as directory:
        connection = open_db(Path(directory) / "commit.db")
        insert_match(connection)
        connection.commit()
        payload = b"versioned-replay-payload\x00\x01"
        expected_hash = commit_shot(connection, payload)
        shot_count = connection.execute("SELECT count(*) FROM shots").fetchone()[0]
        revision, ordinal = connection.execute("SELECT current_revision, current_shot_ordinal FROM matches").fetchone()
        stored_payload, stored_hash = connection.execute("SELECT payload, sha256 FROM replay_chunks").fetchone()
        if (shot_count, revision, ordinal) != (1, 1, 1):
            raise AssertionError("shot transaction did not commit atomically")
        if stored_payload != payload or stored_hash != expected_hash:
            raise AssertionError("replay chunk/hash mismatch")
        connection.close()
        return {"shots": shot_count, "revision": revision, "ordinal": ordinal, "chunk_sha256": stored_hash}


def check_unique_ordinal_rollback() -> dict:
    with tempfile.TemporaryDirectory(dir=HERE / ".tmp") as directory:
        connection = open_db(Path(directory) / "unique.db")
        insert_match(connection)
        connection.commit()
        commit_shot(connection)
        error = None
        try:
            connection.execute("BEGIN IMMEDIATE")
            connection.execute(
                """INSERT INTO shots (
                    match_id, ordinal, shot_id, shot_kind, turn_serial, shooter_seat,
                    command_json, events_json, final_snapshot_json, pre_state_hash,
                    post_state_hash, tick_count, termination, created_at
                ) VALUES (?, 1, ?, 'SHOT', 1, 0, '{}', '[]', '{}', ?, ?, 0, 'AT_REST', ?)""",
                (MATCH_ID, "3" * 32, HASH_B, HASH_A, NOW),
            )
            connection.execute("UPDATE matches SET current_revision = 99 WHERE match_id = ?", (MATCH_ID,))
            connection.commit()
        except sqlite3.IntegrityError as exc:
            error = str(exc)
            connection.rollback()
        shots = connection.execute("SELECT count(*) FROM shots").fetchone()[0]
        revision = connection.execute("SELECT current_revision FROM matches").fetchone()[0]
        if error is None or shots != 1 or revision != 1:
            raise AssertionError(f"error={error}, shots={shots}, revision={revision}")
        connection.close()
        return {"constraint_error": error, "shots_after_rollback": shots, "revision_after_rollback": revision}


def check_foreign_keys_and_json() -> dict:
    with tempfile.TemporaryDirectory(dir=HERE / ".tmp") as directory:
        connection = open_db(Path(directory) / "constraints.db")
        foreign_error = None
        try:
            connection.execute(
                """INSERT INTO shots (
                    match_id, ordinal, shot_id, shot_kind, turn_serial, shooter_seat,
                    command_json, events_json, final_snapshot_json, pre_state_hash,
                    post_state_hash, tick_count, termination, created_at
                ) VALUES (?, 1, ?, 'SHOT', 0, 0, '{}', '[]', '{}', ?, ?, 0, 'AT_REST', ?)""",
                ("f" * 32, "4" * 32, HASH_A, HASH_B, NOW),
            )
        except sqlite3.IntegrityError as exc:
            foreign_error = str(exc)
        connection.rollback()
        json_error = None
        try:
            connection.execute(
                "INSERT INTO settings (key, value_json, value_version, updated_at) VALUES ('bad.json', 'not-json', 1, ?)",
                (NOW,),
            )
        except sqlite3.IntegrityError as exc:
            json_error = str(exc)
        connection.rollback()

        insert_match(connection)
        connection.commit()
        technical_termination_error = None
        try:
            commit_shot(connection, termination="NON_CONVERGENCE")
        except sqlite3.IntegrityError as exc:
            technical_termination_error = str(exc)
        connection.rollback()
        technical_shots = connection.execute("SELECT count(*) FROM shots").fetchone()[0]
        technical_revision = connection.execute("SELECT current_revision FROM matches").fetchone()[0]
        connection.close()

        if foreign_error is None or json_error is None or technical_termination_error is None:
            raise AssertionError(
                f"foreign_error={foreign_error}, json_error={json_error}, "
                f"technical_termination_error={technical_termination_error}"
            )
        if technical_shots != 0 or technical_revision != 0:
            raise AssertionError(
                f"technical failure leaked state: shots={technical_shots}, revision={technical_revision}"
            )
        return {
            "foreign_key_error": foreign_error,
            "json_check_error": json_error,
            "technical_termination_error": technical_termination_error,
            "shots_after_technical_rollback": technical_shots,
            "revision_after_technical_rollback": technical_revision,
        }


def check_explicit_rollback() -> dict:
    with tempfile.TemporaryDirectory(dir=HERE / ".tmp") as directory:
        connection = open_db(Path(directory) / "rollback.db")
        insert_match(connection)
        connection.commit()
        try:
            connection.execute("BEGIN IMMEDIATE")
            connection.execute("UPDATE matches SET status = 'MATCH_OVER', current_revision = 8 WHERE match_id = ?", (MATCH_ID,))
            connection.execute(
                "INSERT INTO settings (key, value_json, value_version, updated_at) VALUES ('temporary', 'true', 1, ?)",
                (NOW,),
            )
            raise RuntimeError("injected failure before COMMIT")
        except RuntimeError as exc:
            connection.rollback()
            injected = str(exc)
        status, revision = connection.execute("SELECT status, current_revision FROM matches").fetchone()
        temporary = connection.execute("SELECT count(*) FROM settings WHERE key = 'temporary'").fetchone()[0]
        if (status, revision, temporary) != ("IN_PROGRESS", 0, 0):
            raise AssertionError(f"rollback leaked state: {(status, revision, temporary)}")
        connection.close()
        return {"injected_error": injected, "status": status, "revision": revision, "temporary_settings": temporary}


def check_backup_integrity() -> dict:
    with tempfile.TemporaryDirectory(dir=HERE / ".tmp") as directory:
        source_path = Path(directory) / "source.db"
        backup_path = Path(directory) / "backup.db"
        source = open_db(source_path)
        insert_match(source)
        source.commit()
        commit_shot(source)
        destination = sqlite3.connect(backup_path)
        source.backup(destination)
        destination.close()
        source.close()
        backup = sqlite3.connect(backup_path)
        integrity = backup.execute("PRAGMA integrity_check").fetchall()
        foreign_violations = backup.execute("PRAGMA foreign_key_check").fetchall()
        counts = {
            "matches": backup.execute("SELECT count(*) FROM matches").fetchone()[0],
            "shots": backup.execute("SELECT count(*) FROM shots").fetchone()[0],
            "replay_chunks": backup.execute("SELECT count(*) FROM replay_chunks").fetchone()[0],
        }
        backup.close()
        if integrity != [("ok",)] or foreign_violations or counts != {"matches": 1, "shots": 1, "replay_chunks": 1}:
            raise AssertionError(f"integrity={integrity}, foreign={foreign_violations}, counts={counts}")
        return {"integrity_check": integrity[0][0], "foreign_key_violations": len(foreign_violations), "counts": counts}


def check_corruption_quarantine_restore() -> dict:
    with tempfile.TemporaryDirectory(dir=HERE / ".tmp") as directory:
        root = Path(directory)
        valid = root / "valid.db"
        corrupt = root / "corrupt.db"
        quarantine = root / "quarantine.db"
        restored = root / "restored.db"
        connection = open_db(valid)
        insert_match(connection)
        connection.commit()
        connection.close()
        shutil.copyfile(valid, corrupt)
        original_corrupt_bytes = b"NOT A SQLITE DATABASE\x00\x01\x02"
        corrupt.write_bytes(original_corrupt_bytes)
        detail = None
        candidate = None
        try:
            candidate = sqlite3.connect(corrupt)
            rows = candidate.execute("PRAGMA integrity_check").fetchall()
            detail = json.dumps(rows)
            detected = rows != [("ok",)]
        except sqlite3.DatabaseError as exc:
            detail = f"{type(exc).__name__}: {exc}"
            detected = True
        finally:
            if candidate is not None:
                candidate.close()
        if not detected:
            raise AssertionError("corruption was not detected")
        corrupt.rename(quarantine)
        if not quarantine.exists() or quarantine.read_bytes() != original_corrupt_bytes or corrupt.exists():
            raise AssertionError("quarantine did not preserve the original corrupt bytes")
        shutil.copyfile(valid, restored)
        recovered = sqlite3.connect(restored)
        integrity = recovered.execute("PRAGMA integrity_check").fetchone()[0]
        matches = recovered.execute("SELECT count(*) FROM matches").fetchone()[0]
        recovered.close()
        if integrity != "ok" or matches != 1:
            raise AssertionError(f"restored integrity={integrity}, matches={matches}")
        return {"corruption_detection": detail, "quarantine_preserved": True, "restored_integrity": integrity, "restored_matches": matches}


CHECKS: list[tuple[str, Callable[[], dict]]] = [
    ("schema_tables_and_pragmas", check_schema),
    ("parameterized_crud", check_parameterized_crud),
    ("shot_transaction_and_replay_hash", check_shot_transaction_and_hash),
    ("unique_ordinal_and_rollback", check_unique_ordinal_rollback),
    ("foreign_keys_and_json_constraints", check_foreign_keys_and_json),
    ("explicit_failure_rollback", check_explicit_rollback),
    ("sqlite_backup_and_integrity", check_backup_integrity),
    ("corruption_quarantine_and_restore", check_corruption_quarantine_restore),
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=HERE / "results" / "sqlite_schema_results.json")
    args = parser.parse_args()
    (HERE / ".tmp").mkdir(exist_ok=True)

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
        "probe": "stage1-python-sqlite-schema-v1",
        "executed_at_utc": datetime.now(timezone.utc).isoformat(),
        "python": platform.python_version(),
        "sqlite_library": sqlite3.sqlite_version,
        "platform": platform.platform(),
        "schema_sha256": hashlib.sha256(SCHEMA.read_bytes()).hexdigest(),
        "summary": {"PASS": passed, "FAIL": failed, "total": len(results)},
        "checks": results,
        "limitations": [
            "Python sqlite3 only; godot-sqlite was not downloaded, loaded, or tested.",
            "No Godot user:// behavior, GDExtension ABI, Android packaging, device upgrade, thread behavior, or plugin-specific backup claim.",
            "Temporary databases were isolated under the workspace and removed after each check; result JSON is retained.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
