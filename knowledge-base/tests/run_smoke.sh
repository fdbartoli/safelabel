#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

smoke_dir="$(mktemp -d)"
trap 'rm -r -- "$smoke_dir"' EXIT

mkdir -p \
  "$smoke_dir/raw" \
  "$smoke_dir/candidates" \
  "$smoke_dir/reviewed" \
  "$smoke_dir/output"

python3 scripts/10_download.py \
  --sources config/sources.fixture.json \
  --raw-dir "$smoke_dir/raw"

python3 scripts/20_extract.py \
  --manifest "$smoke_dir/raw/manifest.json" \
  --compounds config/compounds.json \
  --output "$smoke_dir/candidates/candidates.json"

python3 scripts/30_prepare_review.py \
  --candidates "$smoke_dir/candidates/candidates.json" \
  --output "$smoke_dir/reviewed/review.json"

python3 - \
  "$smoke_dir/reviewed/review.json" \
  "$smoke_dir/reviewed/reviewed.json" <<'PY'
import json
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])

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

python3 scripts/60_build_knowledge.py \
  --compounds config/compounds.json \
  --reviewed "$smoke_dir/reviewed/reviewed.json" \
  --output "$smoke_dir/reviewed/knowledge.json" \
  --restriction-id RES-MILK \
  --restriction-name Leche \
  --target-concept-id CMP-MILK

python3 scripts/80_build_sqlite.py \
  --knowledge "$smoke_dir/reviewed/knowledge.json" \
  --output "$smoke_dir/output/safelabel.sqlite" \
  --version smoke-test

python3 scripts/89_check_sqlite.py \
  "$smoke_dir/output/safelabel.sqlite"

python3 scripts/90_query_ingredient.py \
  "$smoke_dir/output/safelabel.sqlite" \
  "leche" |
  grep -q '"match_type": "DIRECT"'

python3 scripts/90_query_ingredient.py \
  "$smoke_dir/output/safelabel.sqlite" \
  "caseína" |
  grep -q '"status": "MATCHED"'

python3 scripts/90_query_ingredient.py \
  "$smoke_dir/output/safelabel.sqlite" \
  "ingrediente inexistente" |
  grep -q '"status": "UNKNOWN"'

echo "Smoke test: OK"
