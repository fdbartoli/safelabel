#!/usr/bin/env python3
import hashlib
import importlib.util
import pathlib
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parent.parent


def load_script(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / filename)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


download = load_script("download_sources", "10_download.py")
review = load_script("prepare_review", "30_prepare_review.py")


class RemoteSourceCacheTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.target = pathlib.Path(self.directory.name) / "source.html"
        self.payload = b"official source"
        self.target.write_bytes(self.payload)
        self.source = {"url": "https://example.test/source"}
        self.previous = {
            "url": self.source["url"],
            "sha256": hashlib.sha256(self.payload).hexdigest(),
        }

    def tearDown(self):
        self.directory.cleanup()

    def test_reuses_a_valid_remote_copy(self):
        actual = download.reusable_remote_payload(
            self.source,
            self.target,
            self.previous,
            refresh=False,
        )
        self.assertEqual(actual, self.payload)

    def test_refresh_forces_a_new_download(self):
        actual = download.reusable_remote_payload(
            self.source,
            self.target,
            self.previous,
            refresh=True,
        )
        self.assertIsNone(actual)

    def test_rejects_a_copy_whose_hash_does_not_match(self):
        self.previous["sha256"] = "outdated"
        actual = download.reusable_remote_payload(
            self.source,
            self.target,
            self.previous,
            refresh=False,
        )
        self.assertIsNone(actual)


class ReviewFingerprintTest(unittest.TestCase):
    def source(self, sha256, evidence="same evidence"):
        return {
            "source_url": "https://example.test/source",
            "source_sha256": sha256,
            "denominations": [
                {
                    "term": "almond",
                    "language": "en",
                    "representative_evidence": evidence,
                }
            ],
        }

    def test_preserves_a_decision_when_only_the_source_hash_changes(self):
        old = self.source("old-hash")
        new = self.source("new-hash")
        self.assertEqual(
            review.source_fingerprint(old),
            review.source_fingerprint(new),
        )

    def test_requires_review_when_the_evidence_changes(self):
        old = self.source("old-hash", "old evidence")
        new = self.source("new-hash", "new evidence")
        self.assertNotEqual(
            review.source_fingerprint(old),
            review.source_fingerprint(new),
        )


if __name__ == "__main__":
    unittest.main()
