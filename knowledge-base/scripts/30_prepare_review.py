#!/usr/bin/env python3
import argparse
import json
import pathlib
from collections import defaultdict


def source_key(restriction_id, concept_id, source):
    return restriction_id, concept_id, source["source_id"]


def source_fingerprint(source):
    denominations = []
    for denomination in source.get("denominations", []):
        denominations.append((
            denomination.get("term"),
            denomination.get("language"),
            denomination.get("representative_evidence"),
        ))
    return source.get("source_sha256"), tuple(sorted(denominations))


def previous_decisions(path):
    if not path:
        return {}

    payload = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    decisions = {}
    for review in payload.get("reviews", []):
        restriction_id = review.get(
            "restriction_id", payload.get("restriction", {}).get("id")
        )
        for source in review.get("sources", []):
            decisions[source_key(restriction_id, review["concept_id"], source)] = source
    return decisions


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--previous-reviewed")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    payload = json.loads(pathlib.Path(args.candidates).read_text(encoding="utf-8"))
    grouped = defaultdict(list)

    if not payload["candidates"]:
        raise ValueError("No hay candidatos para preparar la revisión")

    restriction_ids = {
        candidate["restriction_id"] for candidate in payload["candidates"]
    }
    if len(restriction_ids) != 1:
        raise ValueError("El archivo debe contener una única restricción")
    first_candidate = payload["candidates"][0]
    restriction = {
        "id": first_candidate["restriction_id"],
        "name": first_candidate["restriction_name"]
    }

    for candidate in payload["candidates"]:
        grouped[candidate["concept_id"]].append(candidate)

    prior = previous_decisions(args.previous_reviewed)
    preserved = 0
    pending = 0
    reviews = []
    for number, (concept_id, items) in enumerate(sorted(grouped.items()), start=1):
        first = items[0]
        by_source = defaultdict(list)
        for item in items:
            by_source[item["source_id"]].append(item)

        aliases = sorted({
            (item["denomination"], item["language"])
            for item in items
        })

        sources = []
        for source_id, source_items in sorted(by_source.items()):
            source_first = source_items[0]
            by_denomination = defaultdict(list)
            for item in source_items:
                key = (item["denomination"], item["language"])
                by_denomination[key].append(item)

            denominations = []
            for (term, language), occurrences in sorted(by_denomination.items()):
                representative = occurrences[0]
                denominations.append({
                    "term": term,
                    "language": language,
                    "occurrence_count": len(occurrences),
                    "candidate_ids": [item["id"] for item in occurrences],
                    "representative_evidence": representative["evidence_text"],
                    "representative_location": representative["evidence_location"]
                })

            source = {
                "source_id": source_id,
                "source_title": source_first["source_title"],
                "source_url": source_first["source_url"],
                "source_sha256": source_first["source_sha256"],
                "occurrence_count": len(source_items),
                "denominations": denominations,
                "review_status": "pending",
                "reviewed_by": None,
                "review_notes": None
            }
            old_source = prior.get(source_key(restriction["id"], concept_id, source))
            if (
                old_source
                and old_source.get("review_status") != "pending"
                and source_fingerprint(old_source) == source_fingerprint(source)
            ):
                source["review_status"] = old_source["review_status"]
                source["reviewed_by"] = old_source.get("reviewed_by")
                source["review_notes"] = old_source.get("review_notes")
                preserved += 1
            else:
                pending += 1
            sources.append(source)

        reviews.append({
            "id": f"REV-{number:04d}",
            "restriction_id": restriction["id"],
            "concept_id": concept_id,
            "canonical_concept": first["canonical_concept"],
            "concept_type": first["concept_type"],
            "match_type": first["match_type"],
            "occurrence_count": len(items),
            "aliases": [
                {"term": term, "language": language}
                for term, language in aliases
            ],
            "sources": sources
        })

    output = {
        "restriction": restriction,
        "grouping": "restriction_id + concept_id + source_id",
        "reviews": reviews
    }
    target = pathlib.Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    source_links = sum(len(review["sources"]) for review in reviews)
    print(
        f"Generados {len(reviews)} concepto(s) con "
        f"{source_links} vinculación(es) a fuentes"
    )
    if args.previous_reviewed:
        print(f"Decisiones conservadas: {preserved}; pendientes: {pending}")


if __name__ == "__main__":
    main()
