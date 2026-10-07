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
SPHERE_SUBDIVISIONS = 5


def sphere_mesh():
    """Uniform high-detail sphere, with stable meridian and polar UV corners.

    Five icosahedral refinements retain broad, grid-safe faces near both poles,
    where a dense latitude/longitude mesh would collapse on MD3's 1/64 grid.
    """
    golden = (1+math.sqrt(5))/2
    points = [(-1,golden,0),(1,golden,0),(-1,-golden,0),(1,-golden,0),
              (0,-1,golden),(0,1,golden),(0,-1,-golden),(0,1,-golden),
              (golden,0,-1),(golden,0,1),(-golden,0,-1),(-golden,0,1)]
    def project(p):
        length = math.sqrt(sum(c*c for c in p))
        return tuple(c*RADIUS/length for c in p)
    points = list(map(project, points))
    faces = [(0,11,5),(0,5,1),(0,1,7),(0,7,10),(0,10,11),
             (1,5,9),(5,11,4),(11,10,2),(10,7,6),(7,1,8),
             (3,9,4),(3,4,2),(3,2,6),(3,6,8),(3,8,9),
             (4,9,5),(2,4,11),(6,2,10),(8,6,7),(9,8,1)]
    for _ in range(SPHERE_SUBDIVISIONS):
        edges, refined = {}, []
        def midpoint(a,b):
            edge = tuple(sorted((a,b)))
            if edge not in edges:
                edges[edge] = len(points)
                points.append(project(tuple((x+y)*.5 for x,y in zip(points[a],points[b]))))
            return edges[edge]
        for a,b,c in faces:
            ab,bc,ca = midpoint(a,b),midpoint(b,c),midpoint(c,a)
            refined.extend(((a,ab,ca),(b,bc,ab),(c,ca,bc),(ab,bc,ca)))
        faces = refined
    base_uv = [((math.atan2(y,x)%math.tau)/math.tau, math.acos(max(-1,min(1,z/RADIUS)))/math.pi)
               for x,y,z in points]
    vertices, coords, triangles, lookup = [], [], [], {}
    for face in faces:
        corners = [list(base_uv[i]) for i in face]
        non_poles = [i for i,source in enumerate(face) if abs(points[source][2]) < RADIUS-1e-8]
        if max(corners[i][0] for i in non_poles)-min(corners[i][0] for i in non_poles) > .5:
            for uv in corners:
                if uv[0] < .5:
                    uv[0] += 1
        for index, source in enumerate(face):
            if abs(points[source][2]) > RADIUS-1e-8:
                corners[index][0] = sum(corners[j][0] for j in range(3) if j != index)*.5
        polygon = [(points[source],uv) for source,uv in zip(face,corners)]
        pieces = [(polygon,False)]
        if any(uv[0] > 1 for p,uv in polygon):
            pieces = []
            for upper in (False,True):
                clipped,previous = [],polygon[-1]
                for current in polygon:
                    inside = current[1][0] >= 1 if upper else current[1][0] <= 1
                    before = previous[1][0] >= 1 if upper else previous[1][0] <= 1
                    if inside != before:
                        fraction = (1-previous[1][0])/(current[1][0]-previous[1][0])
                        point = tuple(a+(b-a)*fraction for a,b in zip(previous[0],current[0]))
                        clipped.append((point,[1,previous[1][1]+(current[1][1]-previous[1][1])*fraction]))
                    if inside:
                        clipped.append(current)
                    previous = current
                if len(clipped) >= 3:
                    pieces.append((clipped,upper))
        for polygon,upper in pieces:
            ids = []
            for point,uv in polygon:
                uv = (uv[0]-(1 if upper else 0),uv[1])
                key = tuple(round(x,12) for x in (*point,*uv))
                if key not in lookup:
                    lookup[key] = len(vertices)
                    vertices.append(point)
                    coords.append(uv)
                if not ids or lookup[key] != ids[-1]:
                    ids.append(lookup[key])
            if len(ids)>1 and ids[0]==ids[-1]:
                ids.pop()
            for i in range(1,len(ids)-1):
                # Source icosahedron is CCW; QSS-M alias faces are clockwise.
                triangles.append((ids[0],ids[i+1],ids[i]))
    return vertices, coords, triangles


def write_md3(path, vertices, coords, triangles):
    """One surface, one shader, one static frame; MD3 version 15."""
    if len(vertices) != len(coords) or not 0 < len(vertices) <= 65535:
        raise ValueError("invalid MD3 vertex/UV count")
    if not 0 < len(triangles) <= 2147483647//3:
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
