# SPDX-License-Identifier: GPL-2.0-or-later
"""Refinement must keep skin seams, joint weights and a watertight surface."""
from collections import Counter
import unittest

from anatomy_mesh import refine_quads, triangulate


class AnatomyMesh(unittest.TestCase):
    def test_adaptive_refinement_has_no_open_internal_edges(self):
        vertices = [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                    (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]
        faces = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        data = dict(vertices=vertices, weights=[{"root": .7, "joint": .3} for _ in vertices],
                    faces=[[[v, face_index/6, corner/4] for corner,v in enumerate(face)]
                           for face_index,face in enumerate(faces)])
        refine_quads(data, lambda p: p[2] > .9)
        triangulate(data)
        edges = Counter(tuple(sorted((a,b))) for triangle in data["geometric"]
                        for a,b in zip(triangle,triangle[1:]+triangle[:1]))
        self.assertEqual(set(edges.values()), {2})
        self.assertGreater(len(data["geometric"]), 12)
        self.assertEqual(len(data["triangle_sources"]), len(data["geometric"]))
        self.assertEqual(set(data["triangle_sources"]), set(range(6)))
        for weights in data["weights"]:
            self.assertAlmostEqual(sum(weights.values()), 1)
            self.assertAlmostEqual(weights["joint"], .3)
        # Separate texture islands still share their geometric seam vertex.
        self.assertGreater(len({tuple(c[1:]) for c in data["corners"] if c[0]==4}), 1)

    def test_existing_small_triangle_is_not_subdivided(self):
        data = dict(vertices=[(0,0,0),(.1,0,0),(0,.1,0)],
                    weights=[{"root":1} for _ in range(3)], faces=[[[0,0,0],[1,1,0],[2,0,1]]])
        refine_quads(data)
        triangulate(data)
        self.assertEqual(len(data["vertices"]), 3)
        self.assertEqual(data["geometric"], [(0,1,2)])

    def test_inserted_edge_in_triangle_keeps_fan_triangulation(self):
        # A triangle with one inserted midpoint has four corners, but is not
        # a quad: a diagonal through that midpoint can create a sliver.
        data = dict(vertices=[(0,0,0),(2,0,0),(0,2,0),(1,0,0)],
                    weights=[{"root":1} for _ in range(4)],
                    faces=[[[0,0,0],[3,.5,0],[1,1,0],[2,0,1]]], fan_faces=[0])
        triangulate(data)
        self.assertEqual(len(data["geometric"]),4)
        self.assertTrue(all(4 in face for face in data["geometric"]))


if __name__ == "__main__":
    unittest.main()
