#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Check the exported MD3 bytes, winding, lighting normals, and texture wrap."""

import math
import struct
import tempfile
import unittest
from pathlib import Path

from ball_assets import RADIUS, ball_skin, sphere_mesh, write_md3


class VolleyballAssetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        vertices, coords, triangles = sphere_mesh()
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "bv_ball.md3"
            write_md3(path, vertices, coords, triangles)
            cls.data = path.read_bytes()
        cls.skin = ball_skin(128)

    def test_md3_layout_and_shader(self):
        magic, version, _, *fields = struct.unpack_from("<4si64s9i", self.data)
        flags, frames, tags, surfaces, skins, frame_at, tag_at, surface_at, end = fields
        self.assertEqual((magic, version, flags, frames, tags, surfaces, skins),
                         (b"IDP3", 15, 0, 1, 0, 1, 0))
        self.assertEqual(end, len(self.data))
        self.assertEqual((frame_at, tag_at, surface_at), (108, 164, 164))
        surface = struct.unpack_from("<4s64s10i", self.data, surface_at)
        self.assertEqual(surface[0], b"IDP3")
        self.assertEqual(surface[2:7], (0, 1, 1, 561, 960))
        triangles_at, shader_at, uv_at, vertices_at, surface_end = surface[7:]
        self.assertEqual(triangles_at, 108)
        self.assertEqual(shader_at, triangles_at + 960 * 12)
        self.assertEqual(uv_at, shader_at + 68)
        self.assertEqual(vertices_at, uv_at + 561 * 8)
        self.assertEqual(surface_end, vertices_at + 561 * 8)
        self.assertEqual(surface_at + surface_end, end)
        shader, index = struct.unpack_from("<64si", self.data, surface_at + shader_at)
        self.assertEqual((shader.split(b"\0")[0], index), (b"progs/bv_ball", 0))

    def test_exported_bounds_winding_and_normals(self):
        frame = struct.unpack_from("<10f16s", self.data, 108)
        surface = struct.unpack_from("<4s64s10i", self.data, 164)
        triangle_at, vertex_at = 164 + surface[7], 164 + surface[10]
        vertices = []
        for i in range(surface[5]):
            x, y, z, polar, azimuth = struct.unpack_from("<3h2B", self.data, vertex_at + i * 8)
            vertex = (x / 64, y / 64, z / 64)
            vertices.append(vertex)
            length = math.sqrt(sum(c * c for c in vertex))
            self.assertAlmostEqual(length, RADIUS, delta=0.014)
            self.assertLessEqual(length, frame[9] + 1e-6)
            for axis, c in enumerate(vertex):
                self.assertLessEqual(frame[axis], c)
                self.assertLessEqual(c, frame[3 + axis])
            polar, azimuth = polar * math.tau / 255, azimuth * math.tau / 255
            normal = (math.sin(polar) * math.cos(azimuth),
                      math.sin(polar) * math.sin(azimuth), math.cos(polar))
            self.assertGreater(sum(c * n for c, n in zip(vertex, normal)) / length, 0.999)
        self.assertEqual(frame[6:9], (0, 0, 0))
        for i in range(surface[6]):
            indices = struct.unpack_from("<3i", self.data, triangle_at + i * 12)
            self.assertTrue(all(0 <= index < len(vertices) for index in indices))
            a, b, c = [vertices[index] for index in indices]
            u, v = [b[j] - a[j] for j in range(3)], [c[j] - a[j] for j in range(3)]
            normal = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2],
                      u[0] * v[1] - u[1] * v[0])
            # Quake's clockwise winding gives a negative outward cross product.
            self.assertLess(sum(normal[j] * (a[j] + b[j] + c[j]) for j in range(3)), 0)

    def test_uv_wrap_does_not_cross_a_face(self):
        surface = struct.unpack_from("<4s64s10i", self.data, 164)
        coords = [struct.unpack_from("<2f", self.data, 164 + surface[9] + i * 8)
                  for i in range(surface[5])]
        for uv in coords:
            self.assertTrue(all(0 <= c <= 1 for c in uv))
        for i in range(surface[6]):
            face = struct.unpack_from("<3i", self.data, 164 + surface[7] + i * 12)
            us = [coords[j][0] for j in face]
            self.assertLessEqual(max(us) - min(us), 1 / 32 + 1e-6)

    def test_skin_colours_poles_and_meridian(self):
        self.assertEqual(len(self.skin), 128 * 128)
        self.assertTrue(all(p[3] == 255 for p in self.skin))
        white = sum(min(p[:3]) > 200 for p in self.skin)
        yellow = sum(p[0] > 200 and p[1] > 150 and p[2] < 60 for p in self.skin)
        blue = sum(p[2] > 130 and p[0] < 50 for p in self.skin)
        self.assertTrue(all(count > 1500 for count in (white, yellow, blue)))
        # The cap remains one colour even where UV longitudes meet at the pole.
        for row in (0, 127):
            samples = self.skin[row * 128:(row + 1) * 128]
            self.assertLess(max(p[0] for p in samples) - min(p[0] for p in samples), 10)
        differences = [abs(self.skin[y * 128][c] - self.skin[y * 128 + 127][c])
                       for y in range(128) for c in range(3)]
        self.assertLess(sum(differences) / len(differences), 12)


if __name__ == "__main__":
    unittest.main()
