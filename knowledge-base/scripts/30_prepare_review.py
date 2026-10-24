#!/usr/bin/env python3
import argparse
import json
import pathlib
from collections import defaultdict


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    payload = json.loads(pathlib.Path(args.candidates).read_text(encoding="utf-8"))
    grouped = defaultdict(list)

    for candidate in payload["candidates"]:
        grouped[candidate["concept_id"]].append(candidate)

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

            sources.append({
                "source_id": source_id,
                "source_title": source_first["source_title"],
                "source_url": source_first["source_url"],
                "source_sha256": source_first["source_sha256"],
                "occurrence_count": len(source_items),
                "denominations": denominations,
                "review_status": "pending",
                "reviewed_by": None,
                "review_notes": None
            })

        reviews.append({
            "id": f"REV-{number:04d}",
            "concept_id": concept_id,
            "canonical_concept": first["canonical_concept"],
            "concept_type": first["concept_type"],
            "occurrence_count": len(items),
            "aliases": [
                {"term": term, "language": language}
                for term, language in aliases
            ],
            "sources": sources
        })

    output = {
        "grouping": "concept_id",
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


if __name__ == "__main__":
    main()
