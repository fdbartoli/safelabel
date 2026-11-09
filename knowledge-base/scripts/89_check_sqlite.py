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
SELECT denomination, language, mapping_type, concept_id, matched_concept,
       status, match_type, target_concept, restriction_id, restriction_name
FROM v_concept_matches
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

        views = {
            row[0]
            for row in conn.execute(
            """
            SELECT name
            FROM sqlite_master
            WHERE type = 'view'
            """
            )
        }
        required_views = {"v_concept_matches", "v_restriction_matches"}
        missing_views = required_views - views
        if missing_views:
            raise SystemExit(
                "Faltan vistas requeridas: " + ", ".join(sorted(missing_views))
            )

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
        denomination_columns = {
            row[1] for row in conn.execute("PRAGMA table_info(denomination)")
        }
        required_denomination_columns = {
            "mapping_type",
            "reviewed_by",
            "review_notes",
        }
        missing_columns = required_denomination_columns - denomination_columns
        if missing_columns:
            raise SystemExit(
                "Faltan columnas de denominación: "
                + ", ".join(sorted(missing_columns))
            )
        recognized_count = conn.execute(
            "SELECT COUNT(*) FROM v_concept_matches WHERE status = 'RECOGNIZED'"
        ).fetchone()[0]

    if not rows:
        raise SystemExit("La base no contiene coincidencias")

    print(f"Versión: {version[0]}")
    print(
        "Conteos: "
        + ", ".join(f"{table}={count}" for table, count in counts.items())
    )
    print(f"Coincidencias disponibles: {len(rows)}")
    print(f"Denominaciones reconocidas sin relación: {recognized_count}")
    for row in rows:
        print(" | ".join(str(value) for value in row))

    print("Validación SQLite: OK")


if __name__ == "__main__":
    main()

