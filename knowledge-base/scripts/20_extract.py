#!/usr/bin/env python3
import argparse
import html
import json
import pathlib
import re
import subprocess
import tempfile


def extract_text(path: pathlib.Path, fmt: str) -> str:
    if fmt == "pdf":
        with tempfile.NamedTemporaryFile(suffix=".txt") as tmp:
            subprocess.run(["pdftotext", "-layout", str(path), tmp.name], check=True)
            return pathlib.Path(tmp.name).read_text(encoding="utf-8", errors="replace")
    text = path.read_text(encoding="utf-8", errors="replace")
    if fmt == "html":
        text = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", text, flags=re.I | re.S)
        text = re.sub(r"<[^>]+>", " ", text)
        text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def evidence_window(text: str, start: int, end: int, radius: int = 180) -> str:
    left = max(0, start - radius)
    right = min(len(text), end + radius)
    return text[left:right].strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--compounds", required=True)
    parser.add_argument("--restriction", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    manifest_path = pathlib.Path(args.manifest).resolve()
    raw_dir = manifest_path.parent
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    compounds = json.loads(pathlib.Path(args.compounds).read_text(encoding="utf-8"))
    restriction = json.loads(
        pathlib.Path(args.restriction).read_text(encoding="utf-8")
    )
    compound_by_id = {compound["id"]: compound for compound in compounds}
    relation_by_concept = {
        relation["concept_id"]: relation
        for relation in restriction["relations"]
    }
    missing_concepts = sorted(set(relation_by_concept) - set(compound_by_id))
    if missing_concepts:
        raise ValueError(
            "Conceptos inexistentes en compounds.json: "
            + ", ".join(missing_concepts)
        )

    selected_sources = set(restriction["source_ids"])
    manifest = [source for source in manifest if source["id"] in selected_sources]
    available_sources = {source["id"] for source in manifest}
    missing_sources = sorted(selected_sources - available_sources)
    if missing_sources:
        raise ValueError(
            "Fuentes de la restricción ausentes en el manifiesto: "
            + ", ".join(missing_sources)
        )

    terms = [
        {
            "term": alias["term"],
            "language": alias["language"],
            "concept_id": compound["id"],
            "canonical_name": compound["canonical_name"],
            "concept_type": compound.get("type", "ingredient"),
        }
        for concept_id in relation_by_concept
        for compound in [compound_by_id[concept_id]]
        for alias in compound["aliases"]
    ]
    candidates = []

    for source in manifest:
        text = extract_text(raw_dir / source["local_file"], source["format"])
        folded = text.casefold()
        source_language = source.get("language", "").split("-")[0].lower()
        occurrences = []
        for term in sorted(
            terms,
            key=lambda item: (
                len(item["term"]),
                item["language"] == source_language
            ),
            reverse=True
        ):
            needle = term["term"].casefold()
            pattern = rf"(?<!\w){re.escape(needle)}(?!\w)"
            for match in re.finditer(pattern, folded):
                occurrences.append((match.start(), match.end(), term))

        selected = []
        occupied = []
        for start, end, term in sorted(occurrences, key=lambda item: (item[0], -(item[1] - item[0]))):
            if any(start < used_end and end > used_start for used_start, used_end in occupied):
                continue
            occupied.append((start, end))
            selected.append((start, end, term))

        for start, end, term in selected:
            candidates.append({
                "id": f'CAND-{len(candidates) + 1:04d}',
                "denomination": term["term"],
                "language": term["language"],
                "concept_id": term["concept_id"],
                "canonical_concept": term["canonical_name"],
                "concept_type": term["concept_type"],
                "restriction_id": restriction["id"],
                "restriction_name": restriction["name"],
                "match_type": relation_by_concept[term["concept_id"]]["match_type"],
                "source_id": source["id"],
                "source_title": source["title"],
                "source_url": source.get("source_url", source["url"]),
                "source_sha256": source["sha256"],
                "evidence_text": evidence_window(text, start, end),
                "evidence_location": f'character:{start}',
                "review_status": "pending",
                "reviewed_by": None
            })

    output = {"candidates": candidates}
    target = pathlib.Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Generados {len(candidates)} candidato(s) pendientes de revisión")


if __name__ == "__main__":
    main()
