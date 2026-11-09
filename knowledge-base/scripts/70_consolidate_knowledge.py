#!/usr/bin/env python3
import argparse
import json
import pathlib


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--recognition-terms", required=True)
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

    recognition_terms = json.loads(
        pathlib.Path(args.recognition_terms).read_text(encoding="utf-8")
    )
    known_terms = {
        (alias["term"].casefold(), alias["language"]): concept_id
        for concept_id, concept in concepts.items()
        for alias in concept["aliases"]
    }
    for term in recognition_terms:
        concept_id = term["concept_id"]
        if concept_id not in concepts:
            raise ValueError(
                f"Término curado asociado a un concepto inexistente: {concept_id}"
            )
        if term.get("mapping_type") != "curated":
            raise ValueError(
                f"mapping_type inválido para {term['term']}: "
                f"{term.get('mapping_type')}"
            )
        if not term.get("reviewed_by"):
            raise ValueError(f"Falta reviewed_by para {term['term']}")

        key = (term["term"].casefold(), term["language"])
        previous_concept = known_terms.get(key)
        if previous_concept is not None:
            raise ValueError(
                f"Término duplicado {term['term']} [{term['language']}]: "
                f"{previous_concept} / {concept_id}"
            )
        known_terms[key] = concept_id

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
            # El catálogo es la fuente autoritativa de denominaciones. Los
            # knowledge intermedios pueden haberse generado con una versión
            # anterior de sus alias sin invalidar la relación ya revisada.
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
        "recognition_terms": sorted(
            recognition_terms,
            key=lambda item: (item["language"], item["term"].casefold())
        ),
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
        f"concepto(s) sin relación; {len(recognition_terms)} término(s) curado(s)"
    )


if __name__ == "__main__":
    main()
