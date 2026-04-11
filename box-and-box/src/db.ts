/**
 * SQLite schema and open helper for box-and-box.
 *
 * Persists registered specs, their validation history, and composition
 * results. better-sqlite3 provides fast synchronous access; WAL mode and
 * foreign keys are enabled.
 */
import Database, { type Database as Db } from "better-sqlite3";

export type Handle = Db;

export function openDatabase(filePath: string): Handle {
  const db = new Database(filePath);
  db.pragma("journal_mode = WAL");
  db.pragma("foreign_keys = ON");
  db.exec(SCHEMA_SQL);
  return db;
}

const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS specs (
  id             TEXT PRIMARY KEY,
  agent          TEXT NOT NULL,
  version        TEXT NOT NULL,
  schema_version TEXT NOT NULL,
  source_path    TEXT,
  source_hash    TEXT NOT NULL,
  spec_json      TEXT NOT NULL,
  registered_at  INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_specs_agent ON specs(agent);
CREATE INDEX IF NOT EXISTS idx_specs_registered_at ON specs(registered_at);

CREATE TABLE IF NOT EXISTS validations (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  spec_id       TEXT NOT NULL,
  validator     TEXT NOT NULL,
  status        TEXT NOT NULL,
  errors_json   TEXT,
  validated_at  INTEGER NOT NULL,
  FOREIGN KEY (spec_id) REFERENCES specs(id)
);

CREATE INDEX IF NOT EXISTS idx_validations_spec ON validations(spec_id);

CREATE TABLE IF NOT EXISTS compositions (
  id             TEXT PRIMARY KEY,
  input_ids      TEXT NOT NULL,
  output_json    TEXT NOT NULL,
  status         TEXT NOT NULL,
  conflicts_json TEXT,
  composed_at    INTEGER NOT NULL
);
`;
