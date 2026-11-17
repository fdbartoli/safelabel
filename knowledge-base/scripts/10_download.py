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


def payload_sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def reusable_remote_payload(
    source: dict,
    target: pathlib.Path,
    previous: dict | None,
    refresh: bool,
) -> bytes | None:
    parsed = urllib.parse.urlparse(source["url"])
    if parsed.scheme not in ("http", "https") or refresh:
        return None
    if previous is None or previous.get("url") != source["url"]:
        return None
    if not target.is_file():
        return None

    payload = target.read_bytes()
    if previous.get("sha256") != payload_sha256(payload):
        return None
    return payload


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
    parser.add_argument(
        "--refresh",
        action="store_true",
        help="Vuelve a descargar las fuentes HTTP aunque exista una copia válida.",
    )
    args = parser.parse_args()

    source_file = pathlib.Path(args.sources).resolve()
    raw_dir = pathlib.Path(args.raw_dir).resolve()
    raw_dir.mkdir(parents=True, exist_ok=True)
    sources = json.loads(source_file.read_text(encoding="utf-8"))
    manifest_path = raw_dir / "manifest.json"
    previous_manifest = []
    if manifest_path.is_file():
        previous_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    previous_by_id = {item["id"]: item for item in previous_manifest}
    manifest = []
    failures = []

    for source in sources:
        source_id = source["id"]
        extension = source.get("format", "bin")
        filename = f"{source_id}.{extension}"
        target = raw_dir / filename
        previous = previous_by_id.get(source_id)
        print(f"Procesando {source_id}: {source['url']}")
        payload = reusable_remote_payload(source, target, previous, args.refresh)
        reused = payload is not None
        if not reused:
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
            target.write_bytes(payload)

        item = dict(source)
        item.update({
            "local_file": filename,
            "retrieved_at": (
                previous.get("retrieved_at")
                if reused and previous
                else datetime.now(timezone.utc).isoformat()
            ),
            "sha256": payload_sha256(payload),
            "size_bytes": len(payload)
        })
        manifest.append(item)
        state = "REUTILIZADA" if reused else "OK"
        print(f"  {state}: {filename}")

    manifest_path.write_text(
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
