#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Build court textures, original models, and sounds with the stdlib."""

import math
import random
import re
import shutil
import struct
from pathlib import Path

from hud_font import pixels as font_pixels
from hud_assets import generate as generate_hud
from ball_assets import generate_ball
from player_assets import generate_players
from net_assets import generate_net, POST_Y, POST_RADIUS, POST_HEIGHT


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
        ((-1, -126, 0), (1, 126, 0.25)),
    ):
        lines.append(brush(low, high, "bv_line"))
    # Player-only round collision hulls; the MD3 supplies the visible padding.
    # Ball sweeps use the matching rounded capsules in physics.qc.
    for y in (-POST_Y, POST_Y):
        planes = [((0, y, 0), (POST_RADIUS, y, 0), (0, y + POST_RADIUS, 0)),
                  ((0, y, POST_HEIGHT), (0, y + POST_RADIUS, POST_HEIGHT),
                   (POST_RADIUS, y, POST_HEIGHT))]
        for i in range(24):
            a, b = math.tau * i / 24, math.tau * (i + 1) / 24
            x0, y0 = POST_RADIUS * math.cos(a), y + POST_RADIUS * math.sin(a)
            x1, y1 = POST_RADIUS * math.cos(b), y + POST_RADIUS * math.sin(b)
            planes.append(((x0, y0, 0), (x0, y0, POST_HEIGHT), (x1, y1, 0)))
        lines.append("{\n" + "\n".join(" ".join("( %g %g %g )" % point for point in plane)
                     + " clip 0 0 0 1 1" for plane in planes) + "\n}")
    # Low driftwood barriers frame the practice area without obscuring the sea.
    for x in (-480, 480):
        lines.append(brush((x - 4, -240, 0), (x + 4, 240, 12), "bv_wood", 2))
    lines.append("}")
    lines.extend(['{', '"classname" "info_player_start"',
                  '"origin" "-288 0 32"', '"angle" "0"', '}',
                  '{', '"classname" "info_player_deathmatch"',
                  '"origin" "-288 0 32"', '"angle" "0"', '}'])
    return "\n".join(lines) + "\n"


def write_mdl(path, vertices, texcoords, triangles, skin, skin_size, normals=None,
              frames=None, skins=None):
    """Original Quake alias geometry; animated frames share vertex topology."""
    frames = frames or [vertices]
    skins = skins or [skin]
    if any(len(frame) != len(vertices) for frame in frames):
        raise ValueError("alias frames must share topology")
    mins = [min(v[axis] for frame in frames for v in frame) for axis in range(3)]
    maxs = [max(v[axis] for frame in frames for v in frame) for axis in range(3)]
    scales = [max((high - low) / 255, 0.001) for low, high in zip(mins, maxs)]
    radius = max(math.sqrt(sum(c * c for c in v)) for frame in frames for v in frame)
    header = struct.pack("<ii3f3ff3f8if", 1330660425, 6, *scales, *mins, radius,
                         0, 0, 0, len(skins), *skin_size, len(vertices),
                         len(triangles), len(frames), 0, 0, 1)
    data = bytearray(header)
    for pixels in skins:
        data.extend(struct.pack("<i", 0))
        data.extend(pixels)
    for s, t in texcoords:
        data.extend(struct.pack("<iii", 0, s, t))
    for triangle in triangles:
        # Quake alias-model front faces wind clockwise.
        data.extend(struct.pack("<4i", 1, triangle[0], triangle[2], triangle[1]))
    for number, frame in enumerate(frames):
        frame_normals = normals if len(frames) == 1 else mesh_normals(frame, triangles)
        data.extend(struct.pack("<i4B4B16s", 0, 0, 0, 0, 0, 255, 255, 255, 0,
                                f"pose{number}".encode()))
        for i, vertex in enumerate(frame):
            encoded = tuple(max(0, min(255, round((vertex[axis] - mins[axis]) / scales[axis])))
                            for axis in range(3)) + (frame_normals[i] if frame_normals else 5,)
            data.extend(bytes(encoded))
    path.write_bytes(data)


def mesh_normals(vertices, triangles):
    pattern = r"\{\s*(-?\d+\.\d+),\s*(-?\d+\.\d+),\s*(-?\d+\.\d+)\s*\}"
    directions = [tuple(map(float, values)) for values in re.findall(
        pattern, (Path(__file__).parent / "resources/anorms.h").read_text())]
    accumulated = [[0., 0., 0.] for _ in vertices]
    for a, b, c in triangles:
        u = [vertices[b][i] - vertices[a][i] for i in range(3)]
        v = [vertices[c][i] - vertices[a][i] for i in range(3)]
        normal = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2],
                  u[0] * v[1] - u[1] * v[0])
        for index in (a, b, c):
            accumulated[index] = [x + y for x, y in zip(accumulated[index], normal)]
    return [max(range(len(directions)), key=lambda i: sum(x * y for x, y in
                zip(normal, directions[i]))) for normal in accumulated]


def shadow_model(path, palette):
    vertices = [(0, 0, 0)] + [(math.cos(i * math.tau / 24) * 5,
                math.sin(i * math.tau / 24) * 5, 0) for i in range(24)]
    triangles = [(0, i + 1, (i + 1) % 24 + 1) for i in range(24)]
    pixels = bytearray([nearest(palette, (70, 65, 50))] * 64)
    pixels[0] = 255
    write_mdl(path, vertices, [(4, 4)] * len(vertices), triangles, pixels, (8, 8))


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
    # Frequency, noise mix and decay distinguish cushioning from a firm strike.
    contacts = {
        "pass": (125, 0.35, 28), "set": (230, 0.12, 38),
        "spike": (85, 0.65, 24), "roll": (180, 0.18, 34),
        "serve": (105, 0.5, 25), "dig": (95, 0.7, 22),
        "sand": (65, 0.9, 35),
    }
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
        elif kind in contacts:
            frequency, roughness, decay = contacts[kind]
            tone = math.sin(math.tau * (frequency - t * frequency * 0.7) * t)
            value = (tone * (0.5 - roughness * 0.25) +
                     filtered * roughness) * math.exp(-t * decay)
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


def court_textures():
    """Load the prepared 1024px RGBA textures without an image-library dependency."""
    directory = Path(__file__).resolve().parent / "resources/textures"
    images = {}
    for name, filename in (("bv_sand", "bv_sand.tga"), ("*bv_sea", "#bv_sea.tga")):
        path = directory / filename
        data = path.read_bytes()
        if len(data) < 18:
            raise ValueError(f"truncated court texture: {path}")
        width, height = struct.unpack_from("<HH", data, 12)
        if data[1] or data[2] != 2 or data[16] != 32 or (width, height) != (1024, 1024):
            raise ValueError(f"court texture must be a 1024x1024 uncompressed RGBA TGA: {path}")
        start = 18 + data[0]
        pixels = data[start:start + width * height * 4]
        if len(pixels) != width * height * 4:
            raise ValueError(f"truncated court pixels: {path}")
        rows = [pixels[y * width * 4:(y + 1) * width * 4] for y in range(height)]
        if not data[17] & 0x20:
            rows.reverse()
        if data[17] & 0x10:
            rows = [b"".join(row[x:x + 4] for x in range(len(row) - 4, -1, -4)) for row in rows]
        pixels = b"".join(rows)
        rgba = bytearray(pixels)
        rgba[0::4], rgba[2::4] = pixels[2::4], pixels[0::4]
        images[name] = bytes(rgba)
    return images


def external_textures(game):
    """RGB companions keep daylight colours independent of Quake's palette."""
    destination = game / "textures/beach"
    destination.mkdir(parents=True, exist_ok=True)
    source = Path(__file__).resolve().parent / "resources/textures"
    for name in ("bv_sand.tga", "#bv_sea.tga"):
        shutil.copyfile(source / name, destination / name)
    for name, color in (("bv_line", (24, 95, 162)),):
        write_tga(destination / f"{name}.tga", 64, 64, [(*color, 255)] * 4096)
    for name, base in (("bv_wood", (135, 102, 65)),):
        pixels = []
        for y in range(64):
            for x in range(64):
                grain = round(4 * math.sin(x * 0.9 + 0.4 * math.sin(y * 0.1)))
                pixels.append((*[c + grain for c in base], 255))
        write_tga(destination / f"{name}.tga", 64, 64, pixels)
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


def generate_court(palette, build, game):
    """Build the clean court independently of the animated model assets."""
    build.mkdir(parents=True, exist_ok=True)
    (game / "maps").mkdir(parents=True, exist_ok=True)
    textures = {}
    court = court_textures()
    # Keep the BSP's classic 64px materials and UV scale, with matching palette
    # fallbacks. High-resolution RGB replacements carry the full artwork.
    for name, rgba in court.items():
        pixels = []
        for y in range(64):
            for x in range(64):
                offset = ((y * 16 + 8) * 1024 + x * 16 + 8) * 4
                pixels.append(nearest(palette, rgba[offset:offset + 3]))
        textures[name] = texture(name, 64, 64, pixels)
    for name, color in (
        ("bv_line", (32, 88, 160)), ("bv_wood", (110, 85, 58)),
    ):
        index = nearest(palette, color)
        textures[name] = texture(name, 64, 64, [index] * 4096)
    blue = nearest(palette, (74, 126, 161))
    cloud = nearest(palette, (205, 215, 215))
    pixels = [blue if x >= 128 else
              (cloud if math.sin(x / 15) + math.cos(y / 12) > 1 else 0)
              for y in range(128) for x in range(256)]
    textures["sky_beach"] = texture("sky_beach", 256, 128, pixels)
    wad = build / "beach.wad"
    write_wad(wad, textures)
    (build / "beach.map").write_text(court_map(wad))
    external_textures(game)
    daylight_skybox(game)


def generate(base, build, game):
    palette = palette_from(base)
    for directory in ("progs", "sound/beach"):
        (game / directory).mkdir(parents=True, exist_ok=True)
    generate_court(palette, build, game)
    generate_ball(game / "progs")
    generate_net(game / "progs")
    marker_model(game / "progs/bv_marker.mdl", palette)
    generate_players(game, build / "player-quality")
    shadow_model(game / "progs/bv_shadow.mdl", palette)
    write_tga(game / "gfx/bv_hud.tga", 128, 128, font_pixels())
    generate_hud(game / "gfx")
    for kind, duration in (("pass", 0.18), ("set", 0.13), ("spike", 0.2),
                           ("roll", 0.15), ("serve", 0.2), ("dig", 0.22), ("sand", 0.15),
                           ("net", 0.2), ("target", 0.3), ("ocean", 4)):
        write_sound(game / f"sound/beach/{kind}.wav", kind, duration, kind == "ocean")
