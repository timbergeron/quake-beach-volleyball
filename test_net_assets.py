#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Check the actual exported equipment: scale, holes, lighting and flex poses."""

import math
import struct
import unittest
from pathlib import Path

from net_assets import (ANTENNA_TOP, BAND, BOTTOM, CELL, FRAME_COUNT,
                        HALF_LENGTH, POST_HEIGHT, SURFACE_VERTEX_LIMIT, TOP, cross, dot, sub)


class PackedPoses:
    """Decode one actual binary pose at a time to bound regression memory."""
    def __init__(self, data, offset, raw):
        self.data, self.offset, self.raw = data, offset, raw

    def __getitem__(self, frame):
        if not 0 <= frame < self.raw[3]:
            raise IndexError(frame)
        vertices, normals = [], []
        for i in range(self.raw[5]):
            x, y, z, polar, azimuth = struct.unpack_from('<3h2B', self.data,
                self.offset+self.raw[10]+(frame*self.raw[5]+i)*8)
            vertices.append((x/64, y/64, z/64))
            polar, azimuth = polar*math.tau/255, azimuth*math.tau/255
            normals.append((math.sin(polar)*math.cos(azimuth), math.sin(polar)*math.sin(azimuth), math.cos(polar)))
        return vertices, normals


class NetAssetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = (Path(__file__).resolve().parent / 'resources/models/bv_net.md3').read_bytes()
        header = struct.unpack_from('<4si64s9i', cls.data)
        cls.header = header
        cls.surfaces = []
        offset = header[10]
        for _ in range(header[6]):
            raw = struct.unpack_from('<4s64s10i', cls.data, offset)
            name = raw[1].split(b'\0')[0].decode()
            poses = PackedPoses(cls.data, offset, raw)
            faces = [struct.unpack_from('<3i', cls.data, offset + raw[7] + i * 12) for i in range(raw[6])]
            cls.surfaces.append((name, offset, raw, poses, faces))
            offset += raw[11]
        cls.surface_end = offset

    def test_md3_layout_and_complete_bounds(self):
        self.assertEqual(self.header[:2], (b'IDP3', 15))
        self.assertEqual(self.header[3:6], (0, FRAME_COUNT, 0))
        self.assertEqual(self.header[11], len(self.data))
        self.assertEqual(self.surface_end, len(self.data))
        for _, offset, raw, poses, faces in self.surfaces:
            self.assertEqual(raw[0], b'IDP3')
            self.assertEqual(raw[3:5], (FRAME_COUNT, 1))
            self.assertLessEqual(raw[5], SURFACE_VERTEX_LIMIT)
            self.assertLessEqual(raw[6], 2147483647//3)
            shader, index = struct.unpack_from('<64si', self.data, offset + raw[8])
            self.assertEqual((shader.split(b'\0')[0], index), (b'progs/bv_net', 0))
            for i in range(raw[5]):
                coords = struct.unpack_from('<2f', self.data, offset + raw[9] + i * 8)
                self.assertTrue(all(math.isfinite(c) and 0 <= c <= 1 for c in coords))
            self.assertTrue(all(0 <= i < raw[5] for face in faces for i in face))
            for frame, (vertices, _) in enumerate(poses):
                bounds = struct.unpack_from('<10f16s', self.data, 108 + frame * 56)
                self.assertEqual(bounds[6:9], (0, 0, 0))
                for vertex in vertices:
                    self.assertTrue(all(bounds[a] <= vertex[a] <= bounds[a + 3] for a in range(3)))
                    self.assertLessEqual(math.sqrt(dot(vertex, vertex)), bounds[9] + 0.0001)

    def test_regulation_measurements_and_opaque_skin(self):
        for name, _, _, poses, _ in self.surfaces:
            vertices = poses[0][0]
            if name.startswith('horizontal_bands'):
                self.assertAlmostEqual(min(v[1] for v in vertices), -HALF_LENGTH, delta=1 / 64)
                self.assertAlmostEqual(max(v[1] for v in vertices), HALF_LENGTH, delta=1 / 64)
                self.assertAlmostEqual(min(v[2] for v in vertices), BOTTOM, delta=1 / 64)
                self.assertAlmostEqual(max(v[2] for v in vertices), TOP, delta=1 / 64)
            if name.startswith('padded_posts'):
                self.assertAlmostEqual(min(v[2] for v in vertices), 0, delta=1 / 64)
                self.assertAlmostEqual(max(v[2] for v in vertices), POST_HEIGHT, delta=1 / 64)
            if name.startswith('antenna_stripes'):
                self.assertAlmostEqual(min(v[2] for v in vertices), TOP, delta=1 / 64)
                self.assertAlmostEqual(max(v[2] for v in vertices), ANTENNA_TOP, delta=1 / 64)
        skin = (Path(__file__).resolve().parent / 'resources/models/bv_net.tga').read_bytes()
        self.assertEqual((skin[2], skin[16], skin[17]), (2, 32, 0x28))
        self.assertEqual(struct.unpack_from('<HH', skin, 12), (1024, 1024))
        self.assertEqual(len(skin), 18 + 1024 * 1024 * 4)
        self.assertEqual(set(skin[21::4]), {255})

    def test_mesh_has_real_openings(self):
        def covers(a, b, c, point):
            area = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
            if abs(area) < 1e-9:
                return False
            weights = []
            for start, end in ((a, b), (b, c), (c, a)):
                weights.append(((end[1] - start[1]) * (point[1] - start[2]) -
                                (end[2] - start[2]) * (point[0] - start[1])) / area)
            return min(weights) >= -1e-9
        triangles = []
        for _, _, _, poses, faces in self.surfaces:
            vertices = poses[0][0]
            triangles.extend(tuple(vertices[i] for i in face) for face in faces)
        for column in (15, 40, 65):
            for row in (1, 3, 6):
                point = (-HALF_LENGTH + (column + 0.5) * CELL, BOTTOM + BAND + (row + 0.5) * CELL)
                self.assertFalse(any(covers(*triangle, point) for triangle in triangles), point)

    def test_clockwise_faces_and_fixed_equipment_during_flex(self):
        for name, _, _, poses, faces in self.surfaces:
            vertices, normals = poses[0]
            for face in faces:
                a, b, c = (vertices[i] for i in face)
                geometric = cross(sub(b, a), sub(c, a))
                average = tuple(sum(normals[i][axis] for i in face) for axis in range(3))
                self.assertGreater(dot(geometric, geometric), 0, (name, face))
                self.assertLessEqual(dot(geometric, average), 0.00001, (name, face))
            moving = name.startswith(('vertical_cords', 'horizontal_cords', 'side_bands', 'end_bindings'))
            if not moving:
                self.assertTrue(all(pose[0] == vertices for pose in poses), name)
            else:
                for phase in (6, 12, 18, 24, 30, 36):
                    self.assertEqual(poses[phase][0], vertices)
                for pose, _ in poses:
                    self.assertTrue(all(abs(a[0] - b[0]) <= 1.02 and a[1:] == b[1:]
                                        for a, b in zip(vertices, pose)))


if __name__ == '__main__':
    unittest.main()
