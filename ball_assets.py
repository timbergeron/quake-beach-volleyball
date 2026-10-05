#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Generate an original beach volleyball MD3 and RGB skin with the stdlib."""

import argparse
import math
import struct
from pathlib import Path

from hud_font import GLYPHS


RADIUS = 3.4  # Matches BV_RADIUS: 21.25 cm at 32 Quake units/metre.
TEXTURE_SIZE = 512
SHADER = "progs/bv_ball"


def sphere_mesh():
    """Duplicate the UV meridian and pole corners to avoid wrap interpolation."""
    columns, rows = 32, 16
    vertices, coords, triangles = [], [], []
    for row in range(rows + 1):
        polar = math.pi * row / rows
        for column in range(columns + 1):
            longitude = math.tau * column / columns
            vertices.append((RADIUS * math.sin(polar) * math.cos(longitude),
                             RADIUS * math.sin(polar) * math.sin(longitude),
                             RADIUS * math.cos(polar)))
            # At a pole each fan corner samples the middle of its UV wedge.
            u = (column + (-0.5 if row == 0 else 0.5 if row == rows else 0)) / columns
            coords.append((max(0, min(1, u)), row / rows))
    for row in range(rows):
        for column in range(columns):
            a = row * (columns + 1) + column
            b = a + columns + 1
            # Clockwise outward faces, as used by Quake/QSS-M alias models.
            if row > 0:
                triangles.append((a, a + 1, b))
            if row < rows - 1:
                triangles.append((a + 1, b + 1, b))
    return vertices, coords, triangles


def write_md3(path, vertices, coords, triangles):
    """One surface, one shader, one static frame; MD3 version 15."""
    if len(vertices) != len(coords) or not 0 < len(vertices) <= 4096:
        raise ValueError("invalid MD3 vertex/UV count")
    if not 0 < len(triangles) <= 8192:
        raise ValueError("invalid MD3 triangle count")
    if any(not 0 <= i < len(vertices) for face in triangles for i in face):
        raise ValueError("MD3 triangle index outside the mesh")
    encoded = [tuple(round(c * 64) for c in vertex) for vertex in vertices]
    if any(not -32768 <= c <= 32767 for vertex in encoded for c in vertex):
        raise ValueError("MD3 vertex exceeds signed 16-bit coordinates")

    header_size, frame_size, surface_size = 108, 56, 108
    triangle_offset = surface_size
    shader_offset = triangle_offset + len(triangles) * 12
    uv_offset = shader_offset + 68
    vertex_offset = uv_offset + len(vertices) * 8
    surface_end = vertex_offset + len(vertices) * 8
    surface_offset = header_size + frame_size
    file_end = surface_offset + surface_end
    header = struct.pack("<4si64s9i", b"IDP3", 15, path.name.encode(),
                         0, 1, 0, 1, 0, header_size, surface_offset,
                         surface_offset, file_end)
    # Bounds contain the quantized vertices, including rounding at the poles.
    mins = [min(v[i] for v in encoded) / 64 for i in range(3)]
    maxs = [max(v[i] for v in encoded) / 64 for i in range(3)]
    radius = max(math.sqrt(sum((c / 64) ** 2 for c in v)) for v in encoded)
    frame = struct.pack("<10f16s", *mins, *maxs, 0, 0, 0, radius, b"beach")
    surface = bytearray(struct.pack("<4s64s10i", b"IDP3", b"ball", 0, 1, 1,
                                   len(vertices), len(triangles), triangle_offset,
                                   shader_offset, uv_offset, vertex_offset, surface_end))
    for face in triangles:
        surface.extend(struct.pack("<3i", *face))
    surface.extend(struct.pack("<64si", SHADER.encode(), 0))
    for uv in coords:
        surface.extend(struct.pack("<2f", *uv))
    for vertex, position in zip(vertices, encoded):
        length = math.sqrt(sum(c * c for c in vertex))
        polar = math.acos(max(-1, min(1, vertex[2] / length)))
        azimuth = math.atan2(vertex[1], vertex[0]) % math.tau
        # MD3 stores the polar byte first, azimuth second (little endian).
        normal = (round(polar * 255 / math.tau) & 255,
                  round(azimuth * 255 / math.tau) & 255)
        surface.extend(struct.pack("<3h2B", *position, *normal))
    path.write_bytes(header + frame + surface)


def panel_centres():
    """Ten spherical cells: two caps and two staggered rings of four panels."""
    centres = [(0, 0, 1), (0, 0, -1)]
    for latitude, offset in ((0.38, 0), (-0.38, math.pi / 4)):
        for i in range(4):
            angle = offset + i * math.pi / 2
            centres.append((math.cos(latitude) * math.cos(angle),
                            math.cos(latitude) * math.sin(angle), math.sin(latitude)))
    return centres


def ball_skin(size=TEXTURE_SIZE):
    """Twisted spherical panels with recessed seams and fine leather grain.

    All artwork is procedural: no product photography, logos or external maps.
    Direction-space sampling keeps both the UV meridian and pole caps seamless.
    """
    centres = panel_centres()
    white, yellow, blue = (242, 241, 228), (248, 205, 36), (24, 88, 173)
    colours = (white, white, yellow, blue, white, yellow, blue, yellow, white, blue)
    pixels = []
    for y in range(size):
        latitude = math.pi * (0.5 - (y + 0.5) / size)
        cos_lat, sin_lat = math.cos(latitude), math.sin(latitude)
        for x in range(size):
            longitude = math.tau * (x + 0.5) / size
            # A smooth twist turns cell boundaries into flowing panel curves.
            angle = longitude - 0.55 * math.sin(2 * latitude)
            direction = (cos_lat * math.cos(angle), cos_lat * math.sin(angle), sin_lat)
            scores = [sum(a * b for a, b in zip(direction, centre)) for centre in centres]
            first, second = sorted(range(10), key=lambda i: scores[i], reverse=True)[:2]
            separation = math.sqrt(sum((a - b) ** 2 for a, b in
                                       zip(centres[first], centres[second])))
            edge = (scores[first] - scores[second]) / separation
            # Soft-edged narrow grooves stay readable without heavy black lines.
            groove = math.exp(-(edge / 0.006) ** 2)
            shoulder = math.exp(-(edge / 0.023) ** 2)
            shade = 1 - 0.13 * shoulder - 0.48 * groove
            dx, dy, dz = direction
            grain = (math.sin(dx * 417 + dy * 113) *
                     math.sin(dy * 391 - dz * 157) * 1.5)
            # Fine dimples sampled on three planes, continuous around the sphere.
            dimple = sum(max(0, math.cos(a * 210) * math.cos(b * 210) - 0.65)
                         for a, b in ((dx, dy), (dy, dz), (dz, dx))) * 7
            color = [max(0, min(255, round(c * shade + grain - dimple)))
                     for c in colours[first]]

            # Original BEACH wordmark centred on the northern white side panel.
            label_x = (angle % math.tau - math.pi) * cos_lat
            label_y = latitude - 0.38
            column = math.floor((label_x + 0.31) / 0.021)
            row = math.floor((0.0735 - label_y) / 0.021)
            if first == 4 and 0 <= column < 29 and 0 <= row < 7:
                letter, stroke = divmod(column, 6)
                if stroke < 5 and GLYPHS["BEACH"[letter]][row] & (1 << (4 - stroke)):
                    color = [25, 57, 84]
            # A small inset inflation valve on the opposite white panel.
            valve_angle = (angle - 5 * math.pi / 4 + math.pi) % math.tau - math.pi
            valve_distance = math.hypot(valve_angle * cos_lat, latitude + 0.38)
            if first == 8 and valve_distance < 0.025:
                color = [61, 69, 74] if valve_distance > 0.013 else [29, 35, 40]
            pixels.append((*color, 255))
    return pixels


def generate_ball(directory):
    # Imported here to let assets.generate call us without a module cycle.
    from assets import write_tga

    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    vertices, coords, triangles = sphere_mesh()
    write_md3(directory / "bv_ball.md3", vertices, coords, triangles)
    write_tga(directory / "bv_ball.tga", TEXTURE_SIZE, TEXTURE_SIZE, ball_skin())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("dist/beachvolley/progs"))
    args = parser.parse_args()
    generate_ball(args.output)
    print(f"Generated {args.output / 'bv_ball.md3'} and bv_ball.tga")
