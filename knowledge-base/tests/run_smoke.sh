#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

smoke_dir="$(mktemp -d)"
trap 'rm -r -- "$smoke_dir"' EXIT

mkdir -p \
  "$smoke_dir/raw" \
  "$smoke_dir/candidates" \
  "$smoke_dir/reviewed" \
  "$smoke_dir/knowledge" \
  "$smoke_dir/output"

python3 scripts/10_download.py \
  --sources config/sources.fixture.json \
  --raw-dir "$smoke_dir/raw"

for restriction in milk celiac; do
  python3 scripts/20_extract.py \
    --manifest "$smoke_dir/raw/manifest.json" \
    --compounds config/compounds.json \
    --restriction "fixtures/${restriction}_restriction.json" \
    --output "$smoke_dir/candidates/${restriction}.json"

  python3 scripts/30_prepare_review.py \
    --candidates "$smoke_dir/candidates/${restriction}.json" \
    --output "$smoke_dir/reviewed/${restriction}-review.json"
done

python3 - \
  "$smoke_dir/reviewed/milk-review.json" \
  "$smoke_dir/reviewed/milk-reviewed.json" \
  "$smoke_dir/reviewed/celiac-review.json" \
  "$smoke_dir/reviewed/celiac-reviewed.json" <<'PY'
import json
import pathlib
import sys

for index in range(1, len(sys.argv), 2):
    source = pathlib.Path(sys.argv[index])
    target = pathlib.Path(sys.argv[index + 1])
    payload = json.loads(source.read_text(encoding="utf-8"))

    for review in payload["reviews"]:
        for item in review["sources"]:
            item["review_status"] = "approved"
            item["reviewed_by"] = "smoke-test"
            item["review_notes"] = None

    target.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
PY

for restriction in milk celiac; do
  python3 scripts/60_build_knowledge.py \
    --compounds config/compounds.json \
    --restriction "fixtures/${restriction}_restriction.json" \
    --reviewed "$smoke_dir/reviewed/${restriction}-reviewed.json" \
    --output "$smoke_dir/knowledge/${restriction}.json"
done

python3 scripts/70_consolidate_knowledge.py \
  --inputs \
    "$smoke_dir/knowledge/milk.json" \
    "$smoke_dir/knowledge/celiac.json" \
  --output "$smoke_dir/knowledge/knowledge.json"

python3 scripts/80_build_sqlite.py \
  --knowledge "$smoke_dir/knowledge/knowledge.json" \
  --output "$smoke_dir/output/safelabel.sqlite" \
  --version smoke-test

python3 scripts/89_check_sqlite.py \
  "$smoke_dir/output/safelabel.sqlite"

python3 scripts/90_query_ingredient.py \
  "$smoke_dir/output/safelabel.sqlite" \
  "leche" |
  grep -q '"restriction_id": "RES-MILK"'

python3 scripts/90_query_ingredient.py \
  "$smoke_dir/output/safelabel.sqlite" \
  "trigo" |
  grep -q '"restriction_id": "RES-CELIAC"'

python3 scripts/90_query_ingredient.py \
  "$smoke_dir/output/safelabel.sqlite" \
  "caseína" |
  grep -q '"status": "MATCHED"'

python3 scripts/90_query_ingredient.py \
  "$smoke_dir/output/safelabel.sqlite" \
  "ingrediente inexistente" |
  grep -q '"status": "UNKNOWN"'

echo "Smoke test: OK"
