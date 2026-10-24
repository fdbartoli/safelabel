#!/usr/bin/env python3
import argparse
import json
import pathlib
import shutil


DECISIONS = {
    "a": "approved",
    "r": "rejected",
    "d": "deferred",
}


def save(path: pathlib.Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--reviewed-by", required=True)
    args = parser.parse_args()

    input_path = pathlib.Path(args.input)
    output_path = pathlib.Path(args.output)

    if output_path.exists():
        payload = json.loads(output_path.read_text(encoding="utf-8"))
        print(f"Continuando revisión existente: {output_path}")
    else:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(input_path, output_path)
        payload = json.loads(output_path.read_text(encoding="utf-8"))

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
