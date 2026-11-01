#!/usr/bin/env python3
import argparse
import hashlib
import json
import pathlib
import time
import urllib.parse
import urllib.request
import urllib.error
from datetime import datetime, timezone


def read_source(
    url: str,
    base: pathlib.Path,
    timeout: int,
    retries: int,
) -> bytes:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme in ("http", "https"):
        request = urllib.request.Request(url, headers={"User-Agent": "SafeLabel-MVP/0.1"})
        for attempt in range(1, retries + 1):
            try:
                with urllib.request.urlopen(request, timeout=timeout) as response:
                    return response.read()
            except (TimeoutError, urllib.error.URLError) as error:
                if attempt == retries:
                    raise error
                print(f"  Intento {attempt}/{retries} fallido: {error}")
                time.sleep(2)
    return (base / url).resolve().read_bytes()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", required=True)
    parser.add_argument("--raw-dir", required=True)
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--retries", type=int, default=3)
    args = parser.parse_args()

    source_file = pathlib.Path(args.sources).resolve()
    raw_dir = pathlib.Path(args.raw_dir).resolve()
    raw_dir.mkdir(parents=True, exist_ok=True)
    sources = json.loads(source_file.read_text(encoding="utf-8"))
    manifest = []
    failures = []

    for source in sources:
        source_id = source["id"]
        print(f"Procesando {source_id}: {source['url']}")
        try:
            payload = read_source(
                source["url"],
                source_file.parent.parent,
                args.timeout,
                args.retries,
            )
        except (TimeoutError, urllib.error.URLError, OSError) as error:
            failures.append((source_id, str(error)))
            print(f"  ERROR: {error}")
            continue

        extension = source.get("format", "bin")
        filename = f"{source_id}.{extension}"
        target = raw_dir / filename
        target.write_bytes(payload)
        item = dict(source)
        item.update({
            "local_file": filename,
            "retrieved_at": datetime.now(timezone.utc).isoformat(),
            "sha256": hashlib.sha256(payload).hexdigest(),
            "size_bytes": len(payload)
        })
        manifest.append(item)
        print(f"  OK: {filename}")

    (raw_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"\nDescargadas {len(manifest)} de {len(sources)} fuente(s)")
    if failures:
        print("Fuentes no descargadas:")
        for source_id, error in failures:
            print(f"- {source_id}: {error}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
