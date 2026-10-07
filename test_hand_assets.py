# SPDX-License-Identifier: GPL-2.0-or-later
"""Handedness and quantized folds in the first-person volleyball rig."""
from pathlib import Path
import math
import shutil
import tempfile
import unittest

import hand_assets as hands
import player_assets as player


class HandAssets(unittest.TestCase):
    def test_extended_strokes_keep_compact_wrist_reach(self):
        for side in (1, -1):
            neutral = (16, side*6, -10.5)
            self.assertEqual(hands.motion("ready", 0, side)[0], neutral)
            for clip in hands.hand_manifest()["clips"]:
                for frame in range(clip["count"]):
                    t = frame/(clip["count"] if clip["loop"] else clip["count"]-1)
                    wrist = hands.motion(clip["name"], t, side)[0]
                    self.assertLess(wrist[0], 25.5, (clip["name"], frame, side))
                    self.assertLess(math.dist(wrist, neutral), 18, (clip["name"], frame, side))

    def test_dorsal_basis_and_contact_palms(self):
        rig = hands.rig()
        # A nail-bevel landmark in the pinned source must be on the dorsal
        # side of its distal bone, so flexing toward -Z closes into the palm.
        point = rig["vertices"][624]
        bone = rig["bones"]["finger5-3"]
        axis = player.sub(bone["tail"], bone["head"])
        t = player.dot(player.sub(point, bone["head"]), axis)/player.dot(axis, axis)
        center = player.add(bone["head"], player.mul(axis, t))
        self.assertGreater(point[2]-center[2], .04)
        for side in (1, -1):
            angles = hands.motion("set_load", 1, side)[1]
            palm = player.mul(player.rotate((0, 0, 1), angles), -1)
            self.assertGreater(palm[0], .6)
            self.assertGreater(palm[2], .25)
        palm = player.mul(player.rotate((0, 0, 1), hands.motion("float_serve", 0, -1)[1]), -1)
        self.assertGreater(palm[0], .99)
        toss = player.mul(player.rotate((0, 0, 1), hands.motion("float_load", .35, 1)[1]), -1)
        self.assertGreater(toss[2], .95)

    def test_shared_frames_and_wrist_away_variant(self):
        clips = hands.hand_manifest()["clips"]
        self.assertEqual([(c["name"], c["start"], c["count"]) for c in clips[:-1]],
                         [(c.name, c.start, c.count) for c in player.CLIPS])
        self.assertEqual(clips[-1]["start"], player.FRAME_COUNT)
        self.assertEqual(clips[-1]["start"]+clips[-1]["count"], hands.HAND_FRAME_COUNT)

    def test_both_thumbs_are_on_medial_side(self):
        rig = hands.rig()
        for side in (1, -1):
            positions, _, _ = hands.hand_pose("ready", 0, side)
            def tip(name):
                ids = [i for i, corner in enumerate(rig["corners"])
                       if corner[0] < len(rig["weights"])
                       and rig["weights"][corner[0]].get(name, 0) > .98]
                return sum(positions[i][1] for i in ids)/len(ids)
            self.assertLess(side*tip("finger1-3"), side*tip("finger5-3"))

    def test_overhead_and_folded_poses_survive_md3_quantization(self):
        rig = hands.rig()
        # Include the transition that previously inverted the inner wrist,
        # the deepest finger curl, and both opposed cut-shot wrists.
        poses = [("ready", 0), ("approach", 7/13), ("set_load", 1),
                 ("set", 3/7), ("float_load", 1), ("float_serve", 2/11),
                 ("cut", 3/12), ("cut_away", 3/12), ("poke", 0),
                 ("spike", 1/12), ("poke", 5/8), ("float_serve", 8/11), ("ready", 0)]
        scene = dict(schema="md3harness.scene.v1", name="hand-folds.md3", winding="ccw",
                     profile="qssm", frames=[f"test{i}" for i in range(len(poses))], tags=[[] for _ in poses], surfaces=[])
        for side in (1, -1):
            surface = dict(name="left" if side > 0 else "right", shader="progs/bv_hands",
                uv=[c[1:] for c in rig["corners"]],
                triangles=[(a, c, b) if side > 0 else (a, b, c) for a, b, c in rig["triangles"]], poses=[])
            for name, t in poses:
                p, n, _ = hands.hand_pose(name, t, side)
                surface["poses"].append(dict(positions=player.Vectors(p), normals=player.Vectors(n)))
            scene["surfaces"].append(surface)
        with tempfile.TemporaryDirectory() as directory:
            game = Path(directory)
            (game/"progs").mkdir()
            shutil.copyfile(player.HERE/"resources/hands/bv_hands.tga", game/"progs/bv_hands.tga")
            report = hands.harness().export_scene(scene, game/"progs/test.md3", game, dict(triangle_budget=30000), strict=True)
            self.assertTrue(report["passed"])
            self.assertFalse(report["issues"])
            from md3harness.format import encode_scene
            batches = []
            for index, (start, end) in enumerate(((0, 4), (4, len(poses)))):
                part = dict(scene, frames=scene["frames"][start:end], tags=scene["tags"][start:end],
                    surfaces=[dict(s, poses=s["poses"][start:end]) for s in scene["surfaces"]])
                path = game/f"batch{index}.md3"
                path.write_bytes(encode_scene(part))
                batches.append(path)
            hands.combine_batches(batches, game/"combined.md3")
            self.assertEqual((game/"combined.md3").read_bytes(), (game/"progs/test.md3").read_bytes())
            unique = dict(scene, frames=scene["frames"][:-1], tags=scene["tags"][:-1],
                surfaces=[dict(s, poses=s["poses"][:-1]) for s in scene["surfaces"]])
            (game/"unique.md3").write_bytes(encode_scene(unique))
            hands.expand_frames(game/"unique.md3", game/"expanded.md3", list(range(len(poses)-1))+[0], scene["frames"])
            self.assertEqual((game/"expanded.md3").read_bytes(), (game/"progs/test.md3").read_bytes())


if __name__ == "__main__":
    unittest.main()
