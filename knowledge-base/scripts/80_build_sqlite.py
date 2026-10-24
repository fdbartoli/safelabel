#!/usr/bin/env python3
import argparse
import json
import pathlib
import sqlite3
from datetime import datetime, timezone


SCHEMA = """
PRAGMA foreign_keys = ON;

CREATE TABLE release_metadata (
  version TEXT NOT NULL,
  generated_at TEXT NOT NULL
);

CREATE TABLE concept (
  id TEXT PRIMARY KEY,
  canonical_name TEXT NOT NULL,
  type TEXT NOT NULL CHECK(type IN ('ingredient', 'food_origin'))
);

CREATE TABLE restriction (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  target_concept_id TEXT NOT NULL REFERENCES concept(id)
);

CREATE TABLE denomination (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL COLLATE NOCASE,
  language TEXT NOT NULL,
  concept_id TEXT NOT NULL REFERENCES concept(id),
  UNIQUE(name, language)
);

CREATE TABLE concept_restriction (
  concept_id TEXT NOT NULL REFERENCES concept(id),
  restriction_id TEXT NOT NULL REFERENCES restriction(id),
  match_type TEXT NOT NULL CHECK(match_type IN ('DIRECT', 'RELATED')),
  PRIMARY KEY(concept_id, restriction_id)
);

CREATE TABLE source (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  url TEXT NOT NULL,
  sha256 TEXT NOT NULL
);

CREATE TABLE evidence (
  id INTEGER PRIMARY KEY,
  concept_id TEXT NOT NULL REFERENCES concept(id),
  restriction_id TEXT NOT NULL REFERENCES restriction(id),
  source_id TEXT NOT NULL REFERENCES source(id),
  denomination TEXT NOT NULL,
  language TEXT NOT NULL,
  fragment TEXT NOT NULL,
  location TEXT,
  reviewed_by TEXT NOT NULL,
  review_notes TEXT
);

CREATE INDEX idx_denomination_name ON denomination(name);
CREATE INDEX idx_denomination_concept ON denomination(concept_id);
CREATE INDEX idx_evidence_concept ON evidence(concept_id);
CREATE INDEX idx_evidence_source ON evidence(source_id);

CREATE VIEW v_restriction_matches AS
SELECT
  denomination.name AS denomination,
  denomination.language AS language,
  concept.id AS concept_id,
  concept.canonical_name AS matched_concept,
  concept_restriction.match_type AS match_type,
  NULL AS relation_type,
  target.canonical_name AS target_concept,
  restriction.id AS restriction_id,
  restriction.name AS restriction_name,
  'certain' AS certainty
FROM denomination
JOIN concept ON concept.id = denomination.concept_id
JOIN concept_restriction ON concept_restriction.concept_id = concept.id
JOIN restriction ON restriction.id = concept_restriction.restriction_id
JOIN concept target ON target.id = restriction.target_concept_id;
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--knowledge", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()

    payload = json.loads(pathlib.Path(args.knowledge).read_text(encoding="utf-8"))
    output = pathlib.Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    restriction = payload["restriction"]
    concepts = payload["concepts"]

    with sqlite3.connect(output) as conn:
        conn.executescript(SCHEMA)
        conn.execute(
            "INSERT INTO release_metadata VALUES (?, ?)",
            (args.version, datetime.now(timezone.utc).isoformat())
        )

        for concept in concepts:
            conn.execute(
                "INSERT INTO concept(id, canonical_name, type) VALUES (?, ?, ?)",
                (concept["id"], concept["canonical_name"], concept["type"])
            )

        conn.execute(
            "INSERT INTO restriction(id, name, target_concept_id) VALUES (?, ?, ?)",
            (restriction["id"], restriction["name"], restriction["target_concept_id"])
        )

        for concept in concepts:
            for alias in concept["aliases"]:
                conn.execute(
                    "INSERT OR IGNORE INTO denomination(name, language, concept_id) VALUES (?, ?, ?)",
                    (alias["term"], alias["language"], concept["id"])
                )

            concept_restriction = concept["restriction"]
            conn.execute(
                "INSERT INTO concept_restriction(concept_id, restriction_id, match_type) VALUES (?, ?, ?)",
                (
                    concept["id"],
                    concept_restriction["restriction_id"],
                    concept_restriction["match_type"]
                )
            )

            for source_evidence in concept["evidence"]:
                conn.execute(
                    "INSERT OR IGNORE INTO source(id, title, url, sha256) VALUES (?, ?, ?, ?)",
                    (
                        source_evidence["source_id"],
                        source_evidence["source_title"],
                        source_evidence["source_url"],
                        source_evidence["source_sha256"]
                    )
                )
                for denomination in source_evidence["denominations"]:
                    conn.execute(
                        """
                        INSERT INTO evidence(
                          concept_id, restriction_id, source_id,
                          denomination, language, fragment, location,
                          reviewed_by, review_notes
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            concept["id"],
                            concept_restriction["restriction_id"],
                            source_evidence["source_id"],
                            denomination["term"],
                            denomination["language"],
                            denomination["representative_evidence"],
                            denomination["representative_location"],
                            source_evidence["reviewed_by"],
                            source_evidence["review_notes"]
                        )
                    )

        alias_count = conn.execute("SELECT COUNT(*) FROM denomination").fetchone()[0]
        evidence_count = conn.execute("SELECT COUNT(*) FROM evidence").fetchone()[0]

    print(
        f"SQLite generada: {len(concepts)} concepto(s), "
        f"{alias_count} denominación(es), {evidence_count} evidencia(s): {output}"
    )


if __name__ == "__main__":
    main()

