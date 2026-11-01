#!/usr/bin/env python3
import argparse
import json
import sqlite3


QUERY = """
SELECT denomination, matched_concept, match_type, relation_type,
       target_concept, restriction_id, restriction_name, certainty
FROM v_restriction_matches
WHERE denomination = ? COLLATE NOCASE
ORDER BY restriction_id, relation_type
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("database")
    parser.add_argument("denomination")
    args = parser.parse_args()

    with sqlite3.connect(args.database) as conn:
        conn.row_factory = sqlite3.Row
        matches = [dict(row) for row in conn.execute(QUERY, (args.denomination,))]

    result = {
        "input": args.denomination,
        "status": "MATCHED" if matches else "UNKNOWN",
        "matches": matches,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
