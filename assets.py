#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Generate original court textures, models, and sounds with the stdlib."""

import math
import random
import re
import struct
from pathlib import Path

from hud_font import pixels as font_pixels


def pak_entry(pak, name):
    with Path(pak).open("rb") as stream:
        magic, offset, length = struct.unpack("<4sii", stream.read(12))
        if magic != b"PACK" or length % 64:
            raise ValueError(f"invalid PAK: {pak}")
        stream.seek(offset)
        directory = stream.read(length)
        for cursor in range(0, length, 64):
            raw, start, size = struct.unpack_from("<56sii", directory, cursor)
            if raw.split(b"\0", 1)[0].decode("ascii") == name:
                stream.seek(start)
                return stream.read(size)
    raise ValueError(f"{name} missing from {pak}")


def palette_from(base):
    for name in ("pak0.pak", "pak1.pak"):
        path = Path(base) / "id1" / name
        if path.is_file():
            try:
                data = pak_entry(path, "gfx/palette.lmp")
                if len(data) == 768:
                    return [tuple(data[i:i + 3]) for i in range(0, 768, 3)]
            except ValueError:
                pass
    loose = Path(base) / "id1/gfx/palette.lmp"
    if loose.is_file():
        data = loose.read_bytes()
        if len(data) == 768:
            return [tuple(data[i:i + 3]) for i in range(0, 768, 3)]
    raise ValueError("a Quake id1 palette is required to build the assets")


def nearest(palette, color, fullbright=False):
    indices = range(224, 255) if fullbright else range(224)
    return min(indices, key=lambda i: sum((a - b) ** 2
               for a, b in zip(palette[i], color)))


def texture(name, width, height, pixels):
    offsets = [40]
    levels = []
    for level in range(4):
        step = 1 << level
        levels.append(bytes(pixels[y * width + x]
                            for y in range(0, height, step)
                            for x in range(0, width, step)))
        if level < 3:
            offsets.append(offsets[-1] + len(levels[-1]))
    return struct.pack("<16s6I", name.encode(), width, height, *offsets) + b"".join(levels)


def write_wad(path, textures):
    offset = 12
    body = bytearray()
    directory = bytearray()
    for name, data in textures.items():
        directory.extend(struct.pack("<iiiBB2x16s", offset, len(data), len(data),
                                     68, 0, name.encode()))
        body.extend(data)
        offset += len(data)
    path.write_bytes(struct.pack("<4sii", b"WAD2", len(textures), offset) + body + directory)


def brush(mins, maxs, material, scale=1):
    """Classic MAP planes use cross(p0-p1, p2-p1) as the outward normal."""
    x0, y0, z0 = mins
    x1, y1, z1 = maxs
    planes = (
        ((x0, y0, z0), (x0, y1, z0), (x0, y0, z1)),
        ((x1, y0, z0), (x1, y0, z1), (x1, y1, z0)),
        ((x0, y0, z0), (x0, y0, z1), (x1, y0, z0)),
        ((x0, y1, z0), (x1, y1, z0), (x0, y1, z1)),
        ((x0, y0, z0), (x1, y0, z0), (x0, y1, z0)),
        ((x0, y0, z1), (x0, y1, z1), (x1, y0, z1)),
    )
    lines = ["{"]
    for points in planes:
        line = " ".join("( %g %g %g )" % point for point in points)
        lines.append(f"{line} {material} 0 0 0 {scale} {scale}")
    return "\n".join(lines + ["}"])


def court_map(wad):
    lines = ['{', '"classname" "worldspawn"', '"message" "Beach / Practice"',
             f'"wad" "{wad.name}"', '"_sunlight" "220"',
             '"_sunlight_color" "1 0.94 0.82"', '"_sun_mangle" "35 -50 0"',
             '"_minlight" "35"', '"_minlight_color" "0.65 0.78 1"',
             '"_sky" "bv_beach"']
    lines.append(brush((-1024, -1024, -96), (1024, 400, 0), "bv_sand"))
    lines.append(brush((-1024, 400, -96), (1024, 1024, -64), "bv_sand"))
    lines.append(brush((-1024, 400, -64), (1024, 1024, -6), "*bv_sea", 4))
    for low, high in (
        ((-1056, -1056, -128), (-1024, 1056, 1056)),
        ((1024, -1056, -128), (1056, 1056, 1056)),
        ((-1024, -1056, -128), (1024, -1024, 1056)),
        ((-1024, 1024, -128), (1024, 1056, 1056)),
        ((-1024, -1024, 1024), (1024, 1024, 1056)),
    ):
        lines.append(brush(low, high, "sky_beach", 4))
    # The lines sit just above the surface. Dimensions match the QC constants.
    for low, high in (
        ((-256, -128, 0), (-254, 128, 0.25)),
        ((254, -128, 0), (256, 128, 0.25)),
        ((-254, -128, 0), (254, -126, 0.25)),
        ((-254, 126, 0), (254, 128, 0.25)),
    ):
        lines.append(brush(low, high, "bv_line"))
    for y in (-144, 144):
        lines.append(brush((-3, y - 3, 0), (3, y + 3, 91), "bv_pole"))
    for x in (-208, -80, 80, 208):
        for y in (-92, 0, 92):
            lines.append(brush((x - 28, y - 26, 0), (x + 28, y + 26, 0.1), "bv_target"))
    # Low driftwood barriers frame the practice area without obscuring the sea.
    for x in (-480, 480):
        lines.append(brush((x - 4, -240, 0), (x + 4, 240, 12), "bv_wood", 2))
    lines.append("}")
    # A non-solid brush model gives the mesh a visible surface. QC sweeps the
    # actual ball/net collision rather than relying on alpha texture holes.
    lines.extend(['{', '"classname" "func_illusionary"'])
    lines.append(brush((-0.65, -128, 43), (0.65, 128, 77.76), "{bv_net"))
    lines.append(brush((-1, -144, 76), (1, 144, 79), "bv_tape"))
    lines.append("}")
    lines.extend(['{', '"classname" "info_player_start"',
                  '"origin" "-288 0 32"', '"angle" "0"', '}',
                  '{', '"classname" "info_player_deathmatch"',
                  '"origin" "-288 0 32"', '"angle" "0"', '}'])
    return "\n".join(lines) + "\n"


def write_mdl(path, vertices, texcoords, triangles, skin, skin_size, normals=None):
    """One original alias-model frame, with duplicated UV seam vertices."""
    mins = [min(v[axis] for v in vertices) for axis in range(3)]
    maxs = [max(v[axis] for v in vertices) for axis in range(3)]
    scales = [max((high - low) / 255, 0.001) for low, high in zip(mins, maxs)]
    encoded = [tuple(max(0, min(255, round((v[axis] - mins[axis]) / scales[axis])))
                     for axis in range(3)) + (normals[i] if normals else 5,)
               for i, v in enumerate(vertices)]
    radius = max(math.sqrt(sum(c * c for c in v)) for v in vertices)
    header = struct.pack("<ii3f3ff3f8if", 1330660425, 6, *scales, *mins, radius,
                         0, 0, 0, 1, *skin_size, len(vertices),
                         len(triangles), 1, 0, 0, 1)
    data = bytearray(header)
    data.extend(struct.pack("<i", 0))
    data.extend(skin)
    for s, t in texcoords:
        data.extend(struct.pack("<iii", 0, s, t))
    for triangle in triangles:
        # Quake alias-model front faces wind clockwise.
        data.extend(struct.pack("<4i", 1, triangle[0], triangle[2], triangle[1]))
    data.extend(struct.pack("<i4B4B16s", 0, 0, 0, 0, 0, 255, 255, 255, 0, b"beach"))
    for vertex in encoded:
        data.extend(bytes(vertex))
    path.write_bytes(data)


def ball_model(path, palette):
    columns, rows = 24, 12
    width, height = 128, 64
    vertices, texcoords, triangles = [], [], []
    for row in range(rows + 1):
        latitude = math.pi * row / rows
        for column in range(columns + 1):
            longitude = math.tau * column / columns
            vertices.append((3.4 * math.sin(latitude) * math.cos(longitude),
                             3.4 * math.sin(latitude) * math.sin(longitude),
                             3.4 * math.cos(latitude)))
            texcoords.append((round(column / columns * (width - 1)),
                              round(row / rows * (height - 1))))
    for row in range(rows):
        for column in range(columns):
            a = row * (columns + 1) + column
            b = a + columns + 1
            if row > 0:
                triangles.append((a, b, a + 1))
            if row < rows - 1:
                triangles.append((a + 1, b, b + 1))
    colors = [nearest(palette, c) for c in ((240, 225, 185), (230, 177, 40), (40, 92, 150))]
    seam = nearest(palette, (42, 44, 48))
    skin = bytearray()
    for y in range(height):
        for x in range(width):
            panel = (x // 21 + y // 22) % 3
            skin.append(seam if x % 21 < 1 or y % 22 < 1 else colors[panel])
    normal_file = Path(__file__).resolve().parent / "resources/anorms.h"
    normals = None
    if normal_file.is_file():
        pattern = r"\{\s*(-?\d+\.\d+),\s*(-?\d+\.\d+),\s*(-?\d+\.\d+)\s*\}"
        directions = [tuple(map(float, values))
                      for values in re.findall(pattern, normal_file.read_text())]
        if len(directions) == 162:
            normals = [max(range(162), key=lambda i: sum(a * b
                           for a, b in zip(vertex, directions[i]))) for vertex in vertices]
    write_mdl(path, vertices, texcoords, triangles, skin, (width, height), normals)


def marker_model(path, palette):
    vertices, triangles = [], []
    for i in range(24):
        angle = math.tau * i / 24
        for radius in (9, 12):
            vertices.append((math.cos(angle) * radius, math.sin(angle) * radius, 0))
    for i in range(24):
        a, b = i * 2, ((i + 1) % 24) * 2
        triangles.extend(((a, a + 1, b), (a + 1, b + 1, b)))
    skin = bytearray([nearest(palette, (245, 190, 60), fullbright=True)] * 64)
    # Quake flood-fills an alias skin's top-left background colour. An entirely
    # solid skin turns black; reserve the corner and sample the gold interior.
    skin[0] = 255
    write_mdl(path, vertices, [(3, 3)] * len(vertices), triangles, skin, (8, 8))


def write_sound(path, kind, duration, loop=False):
    rate = 22050
    count = round(rate * duration)
    rng = random.Random(128 + len(kind))
    samples = bytearray()
    filtered = 0
    for i in range(count):
        t = i / rate
        noise = rng.uniform(-1, 1)
        filtered = filtered * 0.9 + noise * 0.1
        if kind == "ocean":
            value = filtered * (0.32 + 0.14 * math.sin(math.tau * t / duration))
        elif kind == "target":
            value = math.sin(math.tau * 880 * t) * math.exp(-t * 15) * 0.18
        elif kind == "net":
            value = filtered * math.exp(-t * 22) * 0.7
        else:
            value = (math.sin(math.tau * (150 - t * 170) * t) * 0.45 +
                     filtered * 0.45) * math.exp(-t * 28)
        samples.extend(struct.pack("<h", max(-32768, min(32767, round(value * 32767)))))
    fmt = struct.pack("<HHIIHH", 1, 1, rate, rate * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    if loop:
        cue = struct.pack("<I", 1) + struct.pack("<II4sIII", 0, 0, b"data", 0, 0, 0)
        chunks += b"cue " + struct.pack("<I", len(cue)) + cue
    chunks += b"data" + struct.pack("<I", len(samples)) + samples
    path.write_bytes(b"RIFF" + struct.pack("<I", len(chunks) + 4) + b"WAVE" + chunks)


def write_tga(path, width, height, pixels):
    header = bytearray(18)
    header[2] = 2
    struct.pack_into("<HH", header, 12, width, height)
    header[16] = 32
    header[17] = 0x28
    data = bytearray(header)
    for red, green, blue, alpha in pixels:
        data.extend((blue, green, red, alpha))
    path.write_bytes(data)


def external_textures(game):
    """RGB companions keep daylight colours independent of Quake's palette."""
    destination = game / "textures/beach"
    destination.mkdir(parents=True, exist_ok=True)
    rng = random.Random(182)
    pixels = []
    for y in range(256):
        for x in range(256):
            grain = rng.randrange(-9, 10)
            ripple = round(3 * math.sin(x * 0.15 + 1.5 * math.sin(y * 0.04)))
            shade = grain + ripple
            pixels.append((213 + shade, 193 + shade, 146 + shade, 255))
    write_tga(destination / "bv_sand.tga", 256, 256, pixels)
    for name, color in (("bv_line", (24, 95, 162)), ("bv_tape", (235, 235, 224)),
                        ("bv_pole", (210, 181, 126)), ("#bv_sea", (24, 124, 164))):
        write_tga(destination / f"{name}.tga", 64, 64, [(*color, 255)] * 4096)
    # Painted practice boxes blend into sand rather than looking like slabs.
    pixels = []
    for y in range(64):
        for x in range(64):
            grain = rng.randrange(-5, 6)
            color = (213 + grain, 193 + grain, 146 + grain)
            border = x < 3 or y < 3 or x > 60 or y > 60
            cross = (abs(x - 32) < 2 and abs(y - 32) < 9) or \
                    (abs(y - 32) < 2 and abs(x - 32) < 9)
            if border or cross:
                color = (43 + grain, 134 + grain, 145 + grain)
            pixels.append((*color, 255))
    write_tga(destination / "bv_target.tga", 64, 64, pixels)
    for name, base in (("bv_pole", (210, 181, 126)), ("bv_wood", (135, 102, 65)),
                       ("bv_tape", (235, 235, 224))):
        pixels = []
        for y in range(64):
            for x in range(64):
                grain = round(4 * math.sin(x * 0.9 + 0.4 * math.sin(y * 0.1)))
                if name == "bv_tape":
                    grain = -5 if x % 4 == 0 or y % 4 == 0 else 0
                pixels.append((*[c + grain for c in base], 255))
        write_tga(destination / f"{name}.tga", 64, 64, pixels)
    pixels = [(32, 37, 40, 255 if x % 16 < 2 or y % 16 < 2 else 0)
              for y in range(64) for x in range(64)]
    write_tga(destination / "{bv_net.tga", 64, 64, pixels)
    write_tga(destination / "sky_beach_back.tga", 128, 128,
              [(87, 160, 215, 255)] * 16384)
    clouds = [(22, 38, 11, 5), (85, 24, 18, 6), (72, 85, 13, 4),
              (118, 115, 20, 7), (15, 100, 15, 5)]
    pixels = []
    for y in range(128):
        for x in range(128):
            density = sum(math.exp(-((x - cx) / rx) ** 2 - ((y - cy) / ry) ** 2)
                          for cx, cy, rx, ry in clouds)
            pixels.append((242, 247, 250, min(150, round(density * 150))))
    write_tga(destination / "sky_beach_front.tga", 128, 128, pixels)


def daylight_skybox(game):
    """Render a continuous directional sky into Quake's six skybox faces."""
    directory = game / "gfx/env"
    directory.mkdir(parents=True, exist_ok=True)
    transforms = ((3, -1, 2), (-3, 1, 2), (1, 3, 2),
                  (-1, -3, 2), (-2, -1, 3), (2, -1, -3))
    suffixes = ("rt", "lf", "bk", "ft", "up", "dn")
    sun = (math.cos(math.radians(50)) * math.cos(math.radians(35)),
           math.cos(math.radians(50)) * math.sin(math.radians(35)),
           math.sin(math.radians(50)))
    size = 256
    for transform, suffix in zip(transforms, suffixes):
        pixels = []
        for y in range(size):
            for x in range(size):
                b = (2 * x / (size - 1) - 1, 1 - 2 * y / (size - 1), 1)
                direction = [b[abs(i) - 1] * (1 if i > 0 else -1) for i in transform]
                length = math.sqrt(sum(c * c for c in direction))
                dx, dy, dz = [c / length for c in direction]
                haze = math.exp(-max(0, dz) * 4)
                color = [a * (1 - haze) + b * haze
                         for a, b in zip((49, 124, 197), (205, 224, 233))]
                if dz > 0.08:
                    px, py = dx / dz, dy / dz
                    density = (math.sin(px * 1.5 + 0.7 * math.sin(py)) +
                               0.5 * math.sin(py * 0.9) +
                               0.25 * math.sin(3 * px + 1.4 * py))
                    cloud = min(0.8, max(0, density - 0.9) * 1.4)
                    color = [c * (1 - cloud) + 244 * cloud for c in color]
                dot = sum(c * s for c, s in zip((dx, dy, dz), sun))
                glow = math.exp((dot - 1) * 90) * 0.65
                disk = math.exp((dot - 1) * 3500)
                amount = min(1, glow + disk)
                color = [c * (1 - amount) + s * amount
                         for c, s in zip(color, (255, 244, 209))]
                pixels.append((*[max(0, min(255, round(c))) for c in color], 255))
        write_tga(directory / f"bv_beach{suffix}.tga", size, size, pixels)


def generate(base, build, game):
    palette = palette_from(base)
    build.mkdir(parents=True, exist_ok=True)
    for directory in ("maps", "progs", "sound/beach"):
        (game / directory).mkdir(parents=True, exist_ok=True)
    rng = random.Random(713)
    textures = {}
    sand = [nearest(palette, (188 + i * 4, 165 + i * 4, 112 + i * 3)) for i in range(8)]
    pixels = [sand[rng.randrange(8)] for _ in range(64 * 64)]
    textures["bv_sand"] = texture("bv_sand", 64, 64, pixels)
    for name, color in (
        ("bv_line", (32, 88, 160)), ("bv_pole", (235, 206, 140)),
        ("bv_tape", (238, 235, 210)), ("bv_wood", (110, 85, 58)),
        ("*bv_sea", (35, 100, 132)),
    ):
        index = nearest(palette, color)
        textures[name] = texture(name, 64, 64, [index] * 4096)
    target = nearest(palette, (165, 114, 52))
    bright = nearest(palette, (224, 198, 124))
    pixels = [target if x < 3 or y < 3 or x >= 61 or y >= 61 else bright
              for y in range(64) for x in range(64)]
    textures["bv_target"] = texture("bv_target", 64, 64, pixels)
    cord = nearest(palette, (40, 40, 36))
    pixels = [cord if x % 16 < 2 or y % 16 < 2 else 255
              for y in range(64) for x in range(64)]
    textures["{bv_net"] = texture("{bv_net", 64, 64, pixels)
    blue = nearest(palette, (74, 126, 161))
    cloud = nearest(palette, (205, 215, 215))
    pixels = [blue if x >= 128 else
              (cloud if math.sin(x / 15) + math.cos(y / 12) > 1 else 0)
              for y in range(128) for x in range(256)]
    textures["sky_beach"] = texture("sky_beach", 256, 128, pixels)
    wad = build / "beach.wad"
    write_wad(wad, textures)
    (build / "beach.map").write_text(court_map(wad))
    ball_model(game / "progs/bv_ball.mdl", palette)
    marker_model(game / "progs/bv_marker.mdl", palette)
    external_textures(game)
    daylight_skybox(game)
    write_tga(game / "gfx/bv_hud.tga", 128, 128, font_pixels())
    for kind, duration in (("hit", 0.18), ("net", 0.2), ("target", 0.3), ("ocean", 4)):
        write_sound(game / f"sound/beach/{kind}.wav", kind, duration, kind == "ocean")
