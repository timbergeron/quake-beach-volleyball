# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Regressions for folded joints, source/game frame agreement and scale."""
from pathlib import Path
import tempfile
import unittest

import player_assets as player


class PlayerAssets(unittest.TestCase):
    def test_rigid_skinning_matches_weighted_dual_quaternions(self):
        import anatomical_body as anatomy
        from hand_assets import quaternion, qmultiply, dual_skin
        data = anatomy.rig()
        poses = anatomy.transforms(player.BOW, data)[0]
        actual = anatomy.raw_pose(player.BOW, data)[0]
        duals = {}
        for name, (rotation, translation) in poses.items():
            real = quaternion(rotation)
            duals[name] = (real, tuple(x*.5 for x in qmultiply((0,*translation),real)))
        for i in range(0,len(data["vertices"]),83):
            expected = dual_skin(data["vertices"][i],data["weights"][i],duals)
            for a,b in zip(actual[i],expected):
                self.assertAlmostEqual(a,b,places=10)

    def test_deep_folds_preserve_exported_winding_and_topology(self):
        cli = player.harness()
        from md3harness.materials import write_tga
        states = [player.READY, player.SET, player.BOW, player.PIKE, player.PRONE]
        # These in-between samples previously inverted an inner elbow/knee
        # wall even though the key poses looked valid.
        for frame in (117, 354):
            clip = next(c for c in player.CLIPS if c.start <= frame < c.start+c.count)
            states.append(clip.sample((frame-clip.start)/(clip.count-1)))
        meshes = [player.athlete(s)[0] for s in states]
        scene = dict(schema="md3harness.scene.v1", name="folds.md3", winding="ccw",
            profile="qssm", frames=[f"fold{i}" for i in range(len(states))], surfaces=[])
        for part in meshes[0].parts.values():
            for mesh in meshes[1:]:
                self.assertEqual(part.triangles, mesh.parts[part.name].triangles)
                self.assertEqual(part.uv, mesh.parts[part.name].uv)
            scene["surfaces"].append(dict(name=part.name, shader="progs/bv_athlete",
                uv=part.uv, triangles=part.triangles,
                poses=[dict(positions=m.parts[part.name].positions, normals=m.parts[part.name].normals)
                       for m in meshes]))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_tga(root/"progs/bv_athlete.tga", 4, 4, [(255, 255, 255, 255)]*16)
            report = cli.export_scene(scene, root/"progs/folds.md3", root, dict(triangle_budget=60000), strict=True)
            self.assertTrue(report["passed"])
            self.assertFalse(report["issues"])

    def test_animation_frames_match_game_contract(self):
        self.assertEqual((player.HERE/"src/animation_frames.qc").read_text(), player.qc_constants())
        self.assertLessEqual(player.FRAME_COUNT, 1024)
        dive = next(c for c in player.CLIPS if c.name == "dive")
        self.assertGreater(dive.start, 255)

    def test_rest_proportions_and_origin(self):
        mesh, _ = player.athlete(player.READY)
        vertices = [v for p in mesh.parts.values() for v in p.positions]
        sole = min(v[2] for v in vertices)
        height = max(v[2] for v in vertices)-sole
        self.assertAlmostEqual(sole, -24, delta=.2)
        self.assertGreater(height/32, 1.92)
        self.assertLess(height/32, 1.99)


if __name__ == "__main__":
    unittest.main()
