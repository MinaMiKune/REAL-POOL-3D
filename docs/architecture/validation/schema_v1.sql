PRAGMA foreign_keys = ON;
PRAGMA user_version = 1;

CREATE TABLE IF NOT EXISTS schema_migrations (
    version         INTEGER PRIMARY KEY CHECK (version >= 1),
    script_name     TEXT NOT NULL UNIQUE,
    sha256          TEXT NOT NULL CHECK (length(sha256) = 64),
    applied_at      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS settings (
    key             TEXT PRIMARY KEY,
    value_json      TEXT NOT NULL CHECK (json_valid(value_json)),
    value_version   INTEGER NOT NULL CHECK (value_version >= 1),
    updated_at      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS matches (
    match_id            TEXT PRIMARY KEY CHECK (length(match_id) = 32),
    mode                TEXT NOT NULL CHECK (mode IN ('OFFLINE_AI', 'LAN_HOST', 'TRAINING', 'LAB')),
    status              TEXT NOT NULL CHECK (status IN ('IN_PROGRESS', 'RACK_OVER', 'MATCH_OVER', 'SUSPENDED', 'TECHNICAL_ERROR')),
    rules_version       TEXT NOT NULL,
    physics_version     TEXT NOT NULL,
    protocol_version    TEXT NOT NULL,
    players_json        TEXT NOT NULL CHECK (json_valid(players_json)),
    current_snapshot_json TEXT NOT NULL CHECK (json_valid(current_snapshot_json)),
    current_revision    INTEGER NOT NULL CHECK (current_revision >= 0),
    current_shot_ordinal INTEGER NOT NULL CHECK (current_shot_ordinal >= 0),
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL,
    ended_at            TEXT
);

CREATE TABLE IF NOT EXISTS shots (
    match_id            TEXT NOT NULL,
    ordinal             INTEGER NOT NULL CHECK (ordinal >= 1),
    shot_id             TEXT NOT NULL UNIQUE CHECK (length(shot_id) = 32),
    shot_kind           TEXT NOT NULL CHECK (shot_kind IN ('BREAK', 'SHOT', 'PLACEMENT', 'BREAK_CHOICE')),
    turn_serial         INTEGER NOT NULL CHECK (turn_serial >= 0),
    shooter_seat        INTEGER NOT NULL CHECK (shooter_seat IN (0, 1)),
    command_json        TEXT NOT NULL CHECK (json_valid(command_json)),
    events_json         TEXT NOT NULL CHECK (json_valid(events_json)),
    final_snapshot_json TEXT NOT NULL CHECK (json_valid(final_snapshot_json)),
    pre_state_hash      TEXT NOT NULL CHECK (length(pre_state_hash) = 64),
    post_state_hash     TEXT NOT NULL CHECK (length(post_state_hash) = 64),
    tick_count          INTEGER NOT NULL CHECK (tick_count >= 0),
    termination         TEXT NOT NULL CHECK (termination = 'AT_REST'),
    created_at          TEXT NOT NULL,
    PRIMARY KEY (match_id, ordinal),
    FOREIGN KEY (match_id) REFERENCES matches(match_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS replays (
    replay_id           TEXT PRIMARY KEY CHECK (length(replay_id) = 32),
    match_id            TEXT NOT NULL UNIQUE,
    format_version      TEXT NOT NULL,
    initial_snapshot_json TEXT NOT NULL CHECK (json_valid(initial_snapshot_json)),
    version_set_json    TEXT NOT NULL CHECK (json_valid(version_set_json)),
    first_break_seed    TEXT NOT NULL,
    rng_algorithm       TEXT NOT NULL,
    status              TEXT NOT NULL CHECK (status IN ('RECORDING', 'COMPLETE', 'CORRUPT', 'INCOMPATIBLE')),
    final_state_hash    TEXT CHECK (final_state_hash IS NULL OR length(final_state_hash) = 64),
    record_count        INTEGER NOT NULL CHECK (record_count >= 0),
    created_at          TEXT NOT NULL,
    completed_at        TEXT,
    FOREIGN KEY (match_id) REFERENCES matches(match_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS replay_chunks (
    replay_id           TEXT NOT NULL,
    ordinal             INTEGER NOT NULL CHECK (ordinal >= 0),
    payload             BLOB NOT NULL,
    sha256              TEXT NOT NULL CHECK (length(sha256) = 64),
    created_at          TEXT NOT NULL,
    PRIMARY KEY (replay_id, ordinal),
    FOREIGN KEY (replay_id) REFERENCES replays(replay_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS training_attempts (
    attempt_id          TEXT PRIMARY KEY CHECK (length(attempt_id) = 32),
    match_id            TEXT NOT NULL,
    task_id             TEXT NOT NULL,
    task_version        TEXT NOT NULL,
    layout_id           TEXT NOT NULL,
    seed                TEXT NOT NULL,
    command_json        TEXT NOT NULL CHECK (json_valid(command_json)),
    metrics_json        TEXT NOT NULL CHECK (json_valid(metrics_json)),
    created_at          TEXT NOT NULL,
    FOREIGN KEY (match_id) REFERENCES matches(match_id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_shots_match_created
    ON shots(match_id, created_at, ordinal);
CREATE INDEX IF NOT EXISTS idx_replays_status_created
    ON replays(status, created_at);
CREATE INDEX IF NOT EXISTS idx_training_task_created
    ON training_attempts(task_id, task_version, created_at);
