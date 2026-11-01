#!/usr/bin/env python3
import argparse
import json
import pathlib


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inputs", nargs="+", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    restrictions = {}
    concepts = {}
    relations = []

    for input_name in args.inputs:
        payload = json.loads(pathlib.Path(input_name).read_text(encoding="utf-8"))
        restriction = payload["restriction"]
        restriction_id = restriction["id"]
        if restriction_id in restrictions:
            raise ValueError(f"Restricción duplicada: {restriction_id}")
        restrictions[restriction_id] = restriction

        for item in payload["concepts"]:
            concept_id = item["id"]
            definition = {
                "id": concept_id,
                "canonical_name": item["canonical_name"],
                "type": item["type"],
                "aliases": item["aliases"]
            }
            if concept_id in concepts and concepts[concept_id] != definition:
                raise ValueError(f"Definición conflictiva para {concept_id}")
            concepts[concept_id] = definition
            relations.append({
                "concept_id": concept_id,
                "restriction_id": restriction_id,
                "match_type": item["relation"]["match_type"],
                "evidence": item["evidence"]
            })

    output = {
        "restrictions": sorted(restrictions.values(), key=lambda item: item["id"]),
        "concepts": sorted(concepts.values(), key=lambda item: item["id"]),
        "relations": sorted(
            relations,
            key=lambda item: (item["restriction_id"], item["concept_id"])
        )
    }
    target = pathlib.Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    print(
        f"Consolidadas {len(restrictions)} restricción(es), "
        f"{len(concepts)} concepto(s) y {len(relations)} relación(es)"
    )


if __name__ == "__main__":
    main()
