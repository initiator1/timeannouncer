"""Release regressions: never label a stale app or edited source as this candidate."""

import importlib.util
import json
import plistlib
import tempfile
import unittest
from pathlib import Path


spec = importlib.util.spec_from_file_location("release_metadata", Path(__file__).with_name("release-metadata.py"))
metadata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metadata)


class ReleaseMetadataTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "TimeAnnouncer.xcodeproj").mkdir()
        self.project = self.root / "TimeAnnouncer.xcodeproj/project.pbxproj"
        self.project.write_text("MARKETING_VERSION = 1.0.2;\nCURRENT_PROJECT_VERSION = 3;\n" * 2)
        (self.root / "TimeAnnouncer").mkdir()
        self.source = self.root / "TimeAnnouncer/App.swift"
        self.source.write_text("import AppKit\n")
        (self.root / "scripts").mkdir()
        (self.root / "scripts/setup-kokoro.sh").write_text("#!/bin/bash\n")
        self.app = self.root / "TimeAnnouncer.app"
        (self.app / "Contents").mkdir(parents=True)

    def write_app(self, version="1.0.2", build="3"):
        with (self.app / "Contents/Info.plist").open("wb") as stream:
            plistlib.dump({"CFBundleShortVersionString": version, "CFBundleVersion": build}, stream)

    def test_matching_candidate_passes_but_stale_version_or_build_fails(self):
        self.write_app()
        metadata.check_app(self.app, self.root)
        for version, build in (("1.0.1", "3"), ("1.0.2", "2")):
            with self.subTest(version=version, build=build):
                self.write_app(version, build)
                with self.assertRaises(ValueError):
                    metadata.check_app(self.app, self.root)

    def test_source_changed_after_build_rejects_receipt(self):
        path = self.root / "source.json"
        path.write_text(json.dumps(metadata.receipt(self.root)))
        metadata.check_receipt(path, self.root)
        self.source.write_text("import AppKit\n// changed after build\n")
        with self.assertRaises(ValueError):
            metadata.check_receipt(path, self.root)

    def test_configuration_version_disagreement_fails(self):
        self.project.write_text(self.project.read_text() + "MARKETING_VERSION = 1.0.3;\n")
        with self.assertRaises(ValueError):
            metadata.identity(self.root)


if __name__ == "__main__":
    unittest.main()
