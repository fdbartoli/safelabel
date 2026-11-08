#!/usr/bin/env python3
import argparse
import json
import pathlib


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--inputs", nargs="+", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    catalog = json.loads(
        pathlib.Path(args.catalog).read_text(encoding="utf-8")
    )
    concepts = {}
    for concept in catalog:
        concept_id = concept["id"]
        if concept_id in concepts:
            raise ValueError(f"Concepto duplicado en el catálogo: {concept_id}")
        concepts[concept_id] = concept

    restrictions = {}
    relations = []
    relation_keys = set()

    for input_name in args.inputs:
        payload = json.loads(pathlib.Path(input_name).read_text(encoding="utf-8"))
        restriction = payload["restriction"]
        restriction_id = restriction["id"]
        if restriction_id in restrictions:
            raise ValueError(f"Restricción duplicada: {restriction_id}")
        restrictions[restriction_id] = restriction

        for item in payload["concepts"]:
            concept_id = item["id"]
            if concept_id not in concepts:
                raise ValueError(
                    f"Concepto de conocimiento ausente en el catálogo: {concept_id}"
                )

            catalog_definition = concepts[concept_id]
            for field in ("canonical_name", "type"):
                if item[field] != catalog_definition[field]:
                    raise ValueError(
                        f"Definición conflictiva para {concept_id}: {field}"
                    )

            relation_key = (concept_id, restriction_id)
            if relation_key in relation_keys:
                raise ValueError(
                    "Relación duplicada: " + " / ".join(relation_key)
                )
            relation_keys.add(relation_key)
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
        f"{len(concepts)} concepto(s) y {len(relations)} relación(es); "
        f"{len(set(concepts) - {item['concept_id'] for item in relations})} "
        "concepto(s) sin relación"
    )


if __name__ == "__main__":
    main()
