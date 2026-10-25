#!/usr/bin/env python3
import argparse
import json
import pathlib


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compounds", required=True)
    parser.add_argument("--restriction", required=True)
    parser.add_argument("--reviewed", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--manual-additions")
    args = parser.parse_args()

    compounds = json.loads(pathlib.Path(args.compounds).read_text(encoding="utf-8"))
    restriction = json.loads(
        pathlib.Path(args.restriction).read_text(encoding="utf-8")
    )
    reviewed = json.loads(pathlib.Path(args.reviewed).read_text(encoding="utf-8"))

    compound_by_id = {compound["id"]: compound for compound in compounds}
    relation_by_concept = {
        relation["concept_id"]: relation
        for relation in restriction["relations"]
    }
    reviewed_restriction = reviewed.get("restriction", {}).get("id")
    if reviewed_restriction and reviewed_restriction != restriction["id"]:
        raise ValueError(
            f"La revisión corresponde a {reviewed_restriction}, no a {restriction['id']}"
        )

    concepts = []
    for review in reviewed["reviews"]:
        review_restriction = review.get("restriction_id", restriction["id"])
        if review_restriction != restriction["id"]:
            raise ValueError(
                f"Restricción inesperada en {review['id']}: {review_restriction}"
            )

        approved_sources = [
            source
            for source in review["sources"]
            if source["review_status"] == "approved"
        ]
        if not approved_sources:
            continue

        concept_id = review["concept_id"]
        if concept_id not in compound_by_id:
            raise ValueError(f"Concepto inexistente en compounds.json: {concept_id}")
        if concept_id not in relation_by_concept:
            raise ValueError(
                f"Concepto no declarado en {restriction['id']}: {concept_id}"
            )

        evidence = []
        for source in approved_sources:
            evidence.append({
                "source_id": source["source_id"],
                "source_title": source["source_title"],
                "source_url": source["source_url"],
                "source_sha256": source["source_sha256"],
                "reviewed_by": source["reviewed_by"],
                "review_notes": source["review_notes"],
                "denominations": source["denominations"]
            })

        compound = compound_by_id[concept_id]
        concepts.append({
            "id": concept_id,
            "canonical_name": compound["canonical_name"],
            "type": compound["type"],
            "aliases": list(compound["aliases"]),
            "relation": {
                "restriction_id": restriction["id"],
                "match_type": relation_by_concept[concept_id]["match_type"]
            },
            "evidence": evidence
        })

    if args.manual_additions:
        manual = json.loads(
            pathlib.Path(args.manual_additions).read_text(encoding="utf-8")
        )
        concept_by_id = {concept["id"]: concept for concept in concepts}

        for addition in manual.get("additions", []):
            concept_id = addition["concept_id"]
            if addition["restriction_id"] != restriction["id"]:
                raise ValueError(
                    f"Restricción inesperada para {concept_id}: "
                    f"{addition['restriction_id']}"
                )
            if concept_id not in compound_by_id:
                raise ValueError(f"Concepto manual inexistente: {concept_id}")
            if concept_id not in relation_by_concept:
                raise ValueError(
                    f"Concepto manual no declarado en {restriction['id']}: {concept_id}"
                )

            expected_match_type = relation_by_concept[concept_id]["match_type"]
            if addition["match_type"] != expected_match_type:
                raise ValueError(
                    f"Tipo de relación inesperado para {concept_id}: "
                    f"{addition['match_type']}"
                )

            if concept_id not in concept_by_id:
                compound = compound_by_id[concept_id]
                concept_by_id[concept_id] = {
                    "id": concept_id,
                    "canonical_name": compound["canonical_name"],
                    "type": compound["type"],
                    "aliases": list(compound["aliases"]),
                    "relation": {
                        "restriction_id": restriction["id"],
                        "match_type": expected_match_type
                    },
                    "evidence": []
                }
                concepts.append(concept_by_id[concept_id])

            concept = concept_by_id[concept_id]
            existing_aliases = {
                (alias["term"], alias["language"])
                for alias in concept["aliases"]
            }
            for alias in addition["aliases"]:
                key = (alias["term"], alias["language"])
                if key not in existing_aliases:
                    concept["aliases"].append(alias)
                    existing_aliases.add(key)
            concept["aliases"].sort(key=lambda item: (item["term"], item["language"]))
            concept["evidence"].extend(addition["evidence"])

    restriction_output = {
        key: restriction[key]
        for key in (
            "id", "name", "display_name", "jurisdiction", "target_concept_id"
        )
    }
    output = {
        "restriction": restriction_output,
        "concepts": sorted(concepts, key=lambda item: item["id"])
    }

    target = pathlib.Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    evidence_count = sum(len(concept["evidence"]) for concept in concepts)
    print(
        f"Consolidada {restriction['id']}: {len(concepts)} concepto(s) con "
        f"{evidence_count} fuente(s) aprobada(s)"
    )


if __name__ == "__main__":
    main()
