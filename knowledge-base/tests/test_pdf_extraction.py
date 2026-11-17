#!/usr/bin/env python3
import importlib.util
import pathlib
import tempfile
import unittest
from unittest import mock


ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location(
    "extract_candidates",
    ROOT / "scripts" / "20_extract.py",
)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class PdfExtractionTest(unittest.TestCase):
    def _extract(self, mode):
        commands = []

        def fake_run(command, check):
            self.assertTrue(check)
            commands.append(command)
            pathlib.Path(command[-1]).write_text(
                "texto de prueba", encoding="utf-8"
            )

        with tempfile.TemporaryDirectory() as directory:
            source = pathlib.Path(directory) / "source.pdf"
            source.write_bytes(b"pdf")
            with mock.patch.object(MODULE.subprocess, "run", side_effect=fake_run):
                text = MODULE.extract_text(source, "pdf", mode)

        return text, commands[0]

    def test_layout_conserva_el_comportamiento_anterior(self):
        text, command = self._extract("layout")
        self.assertEqual(text, "texto de prueba")
        self.assertEqual(command[0:2], ["pdftotext", "-layout"])

    def test_flow_no_usa_layout(self):
        text, command = self._extract("flow")
        self.assertEqual(text, "texto de prueba")
        self.assertEqual(command[0], "pdftotext")
        self.assertNotIn("-layout", command)

    def test_rechaza_un_modo_desconocido(self):
        with self.assertRaisesRegex(ValueError, "no soportado"):
            MODULE.extract_text(pathlib.Path("source.pdf"), "pdf", "columns")


if __name__ == "__main__":
    unittest.main()
