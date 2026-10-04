#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Check runtime reuse without modifying installed Quake data."""

import tempfile
import unittest
from pathlib import Path

from run import stage_runtime


class RuntimeLinks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="beachvolley-links-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.runtime = self.root / "runtime"
        self.bases = [self.root / name for name in ("base-a", "base-b")]
        self.engines = [self.root / name for name in ("engine-a", "engine-b")]
        self.games = [self.root / name for name in ("game-a", "game-b")]
        for i in range(2):
            (self.bases[i] / "id1").mkdir(parents=True)
            (self.bases[i] / "id1/pak0.pak").write_bytes(b"test base")
            self.engines[i].mkdir()
            (self.engines[i] / "quakespasm").touch()
            (self.engines[i] / "qssm.pak").write_bytes(b"test engine")
            self.games[i].mkdir()
        (self.bases[0] / "id1/pak1.pak").write_bytes(b"test optional pak")

    def stage(self, i):
        stage_runtime(self.engines[i] / "quakespasm", self.bases[i], self.runtime, self.games[i])

    def test_switch_installation_updates_links(self):
        self.stage(0)
        self.stage(1)
        self.assertEqual((self.runtime / "id1/pak0.pak").resolve(), self.bases[1] / "id1/pak0.pak")
        self.assertFalse((self.runtime / "id1/pak1.pak").is_symlink())
        self.assertEqual((self.runtime / "qssm.pak").resolve(), self.engines[1] / "qssm.pak")
        self.assertEqual((self.runtime / "beachvolley").resolve(), self.games[1])

    def test_repair_dangling_link(self):
        (self.runtime / "id1").mkdir(parents=True)
        (self.runtime / "id1/pak0.pak").symlink_to(self.root / "missing.pak")
        self.stage(0)
        self.assertEqual((self.runtime / "id1/pak0.pak").resolve(), self.bases[0] / "id1/pak0.pak")

    def test_preserve_regular_file(self):
        (self.runtime / "id1").mkdir(parents=True)
        target = self.runtime / "id1/pak0.pak"
        target.write_bytes(b"local file")
        with self.assertRaises(ValueError):
            self.stage(0)
        self.assertEqual(target.read_bytes(), b"local file")


if __name__ == "__main__":
    unittest.main()
