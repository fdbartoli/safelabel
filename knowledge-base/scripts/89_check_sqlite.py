#!/usr/bin/env python3
import argparse
import sqlite3


REQUIRED_TABLES = {
    "release_metadata",
    "concept",
    "restriction",
    "denomination",
    "concept_restriction",
    "source",
    "evidence",
}

MATCH_QUERY = """
SELECT denomination, language, concept_id, matched_concept,
       match_type, target_concept, restriction_id, restriction_name
FROM v_restriction_matches
ORDER BY matched_concept, language, denomination
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("database")
    args = parser.parse_args()

    with sqlite3.connect(args.database) as conn:
        foreign_key_errors = conn.execute("PRAGMA foreign_key_check").fetchall()
        if foreign_key_errors:
            raise SystemExit(f"Errores de claves foráneas: {foreign_key_errors}")

        tables = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
        missing = REQUIRED_TABLES - tables
        if missing:
            raise SystemExit(
                "Faltan tablas requeridas: " + ", ".join(sorted(missing))
            )

        view = conn.execute(
            """
            SELECT name
            FROM sqlite_master
            WHERE type = 'view' AND name = 'v_restriction_matches'
            """
        ).fetchone()
        if view is None:
            raise SystemExit("Falta la vista v_restriction_matches")

        version = conn.execute(
            "SELECT version FROM release_metadata LIMIT 1"
        ).fetchone()
        if version is None:
            raise SystemExit("Falta la versión de la base")

        counts = {
            table: conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            for table in (
                "concept",
                "restriction",
                "denomination",
                "concept_restriction",
                "source",
                "evidence",
            )
        }
        rows = conn.execute(MATCH_QUERY).fetchall()

    if not rows:
        raise SystemExit("La base no contiene coincidencias")

    print(f"Versión: {version[0]}")
    print(
        "Conteos: "
        + ", ".join(f"{table}={count}" for table, count in counts.items())
    )
    print(f"Coincidencias disponibles: {len(rows)}")
    for row in rows:
        print(" | ".join(str(value) for value in row))

    print("Validación SQLite: OK")


if __name__ == "__main__":
    main()

