#!/usr/bin/env python3
import argparse
import json
import pathlib


DECISIONS = {
    "a": "approved",
    "r": "rejected",
    "d": "deferred",
}


def save(path: pathlib.Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def source_key(payload, review, source):
    restriction_id = review.get(
        "restriction_id", payload.get("restriction", {}).get("id")
    )
    return restriction_id, review["concept_id"], source["source_id"]


def source_fingerprint(source):
    denominations = []
    for denomination in source.get("denominations", []):
        denominations.append((
            denomination.get("term"),
            denomination.get("language"),
            denomination.get("representative_evidence"),
        ))
    return source.get("source_sha256"), tuple(sorted(denominations))


def merge_existing_decisions(current: dict, existing: dict) -> int:
    decisions = {}
    for review in existing.get("reviews", []):
        for source in review.get("sources", []):
            decisions[source_key(existing, review, source)] = source

    preserved = 0
    for review in current.get("reviews", []):
        for source in review.get("sources", []):
            if source.get("review_status") != "pending":
                continue
            old_source = decisions.get(source_key(current, review, source))
            if (
                old_source
                and old_source.get("review_status") != "pending"
                and source_fingerprint(old_source) == source_fingerprint(source)
            ):
                source["review_status"] = old_source["review_status"]
                source["reviewed_by"] = old_source.get("reviewed_by")
                source["review_notes"] = old_source.get("review_notes")
                preserved += 1
    return preserved


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--reviewed-by", required=True)
    args = parser.parse_args()

    input_path = pathlib.Path(args.input)
    output_path = pathlib.Path(args.output)

    payload = json.loads(input_path.read_text(encoding="utf-8"))
    if output_path.exists():
        existing = json.loads(output_path.read_text(encoding="utf-8"))
        preserved = merge_existing_decisions(payload, existing)
        print(
            f"Revisión actualizada desde {input_path}; "
            f"decisiones en curso conservadas: {preserved}"
        )
    else:
        output_path.parent.mkdir(parents=True, exist_ok=True)
    save(output_path, payload)

    pending = [
        (review, source)
        for review in payload["reviews"]
        for source in review["sources"]
        if source["review_status"] == "pending"
    ]

    if not pending:
        print("No quedan vinculaciones pendientes de revisión")
        return

    total = len(pending)
    for index, (review, source) in enumerate(pending, start=1):
        print("\n" + "=" * 72)
        restriction = payload.get("restriction", {})
        restriction_label = restriction.get("name", review.get("restriction_id", ""))
        print(f"Restricción: {restriction_label}")
        print(f"[{index}/{total}] {review['concept_id']} — {review['canonical_concept']}")
        aliases = ", ".join(
            f"{alias['term']} [{alias['language']}]"
            for alias in review["aliases"]
        )
        print(f"Alias: {aliases}")
        print(f"Fuente: {source['source_id']} — {source['source_title']}")

        for denomination in source["denominations"]:
            print(
                f"\nTérmino: {denomination['term']} "
                f"[{denomination['language']}] "
                f"({denomination['occurrence_count']} aparición/es)"
            )
            print(f"Evidencia: {denomination['representative_evidence']}")

        while True:
            answer = input("\n[a]probar, [r]echazar, [d]iferir, [s]alir: ").strip().lower()
            if answer in (*DECISIONS.keys(), "s"):
                break
            print("Opción inválida")

        if answer == "s":
            save(output_path, payload)
            print(f"Revisión guardada: {output_path}")
            return

        source["review_status"] = DECISIONS[answer]
        source["reviewed_by"] = args.reviewed_by
        notes = input("Notas opcionales: ").strip()
        source["review_notes"] = notes or None
        save(output_path, payload)

    print(f"Revisión completa: {output_path}")


if __name__ == "__main__":
    main()
