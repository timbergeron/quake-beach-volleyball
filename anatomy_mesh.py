# SPDX-License-Identifier: GPL-2.0-or-later
"""Stable anatomical topology, interpolated weights and seam-preserving detail."""
from collections import defaultdict
from player_assets import add, sub, mul, dot, cross


def blend_weights(items):
    result = defaultdict(float)
    for weights, factor in items:
        for name, weight in weights.items():
            result[name] += weight*factor
    total = sum(result.values())
    return {name: weight/total for name, weight in sorted(result.items()) if weight > 1e-8}


def weld_small_edges(data, distance=.055):
    """Weld unrepresentable source details once, preserving UV seam corners."""
    vertices, weights, faces = data["vertices"], data["weights"], data["faces"]
    parents = list(range(len(vertices)))
    def root(index):
        while parents[index] != index:
            parents[index] = parents[parents[index]]
            index = parents[index]
        return index
    for face in faces:
        for a, b in zip(face, face[1:]+face[:1]):
            delta = sub(vertices[a[0]], vertices[b[0]])
            if dot(delta, delta) < distance**2:
                ra, rb = root(a[0]), root(b[0])
                parents[max(ra, rb)] = min(ra, rb)
    groups = defaultdict(list)
    for index in range(len(vertices)):
        groups[root(index)].append(index)
    for ids in groups.values():
        p = tuple(sum(vertices[i][a] for i in ids)/len(ids) for a in range(3))
        w = blend_weights((weights[i], 1/len(ids)) for i in ids)
        for index in ids:
            vertices[index], weights[index] = p, w
    result = []
    for face in faces:
        corners = []
        for corner in face:
            entry = [root(corner[0]), *corner[1:]]
            if not corners or entry[0] != corners[-1][0]:
                corners.append(entry)
        if len(corners) > 1 and corners[0][0] == corners[-1][0]:
            corners.pop()
        if len({c[0] for c in corners}) >= 3:
            result.append(corners)
    data["faces"] = result
    return data


def refine_quads(data, predicate=None, min_edge=.16, face_filter=None):
    """Refine selected quads with shared edge points and interpolated skin weights.

    Edge points use Catmull–Clark face neighborhoods; UVs interpolate within
    each original island. Neighbor faces retain shared inserted edge points.
    Small detail remains at its source resolution to respect the MD3 grid.
    """
    vertices, weights, faces = data["vertices"], data["weights"], data["faces"]
    edges, centers, selected = defaultdict(list), [], set()
    original_fans = set(data.get("fan_faces", []))
    original_sources = data.get("face_sources", list(range(len(faces))))
    for index, face in enumerate(faces):
        ids = [c[0] for c in face]
        centers.append(tuple(sum(vertices[i][a] for i in ids)/len(ids) for a in range(3)))
        lengths = []
        for a, b in zip(ids, ids[1:]+ids[:1]):
            edges[tuple(sorted((a, b)))].append(index)
            delta = sub(vertices[a], vertices[b])
            lengths.append(dot(delta, delta))
        if (len(ids) == 4 and index not in original_fans and min(lengths) >= min_edge**2
                and (predicate is None or predicate(centers[-1])) and (face_filter is None or face_filter(face, index))):
            selected.add(index)
    edge_ids = {}
    for index in sorted(selected):
        ids = [c[0] for c in faces[index]]
        for a, b in zip(ids, ids[1:]+ids[:1]):
            edge = tuple(sorted((a, b)))
            if edge in edge_ids:
                continue
            adjacent = edges[edge]
            if len(adjacent) == 2:
                point = mul(add(add(vertices[a], vertices[b]), add(centers[adjacent[0]], centers[adjacent[1]])), .25)
                terms = [(weights[a], .25), (weights[b], .25)]
                for face_index in adjacent:
                    corners = faces[face_index]
                    terms.extend((weights[c[0]], .25/len(corners)) for c in corners)
            else:
                point = mul(add(vertices[a], vertices[b]), .5)
                terms = [(weights[a], .5), (weights[b], .5)]
            edge_ids[edge] = len(vertices)
            vertices.append(point)
            weights.append(blend_weights(terms))
    result, fan_faces, face_sources = [], [], []
    for index, face in enumerate(faces):
        if index in selected:
            middle = len(vertices)
            vertices.append(centers[index])
            weights.append(blend_weights((weights[c[0]], 1/len(face)) for c in face))
            center = [middle, *[sum(c[a] for c in face)/len(face) for a in (1, 2)]]
            for i, current in enumerate(face):
                before, after = face[i-1], face[(i+1)%len(face)]
                left = [edge_ids[tuple(sorted((before[0], current[0])))], *[(before[a]+current[a])*.5 for a in (1, 2)]]
                right = [edge_ids[tuple(sorted((current[0], after[0])))], *[(current[a]+after[a])*.5 for a in (1, 2)]]
                result.append([current, right, center, left])
                face_sources.append(original_sources[index])
        else:
            expanded = []
            for current, after in zip(face, face[1:]+face[:1]):
                expanded.append(current)
                edge = tuple(sorted((current[0], after[0])))
                if edge in edge_ids:
                    expanded.append([edge_ids[edge], *[(current[a]+after[a])*.5 for a in (1, 2)]])
            if len(expanded) != len(face) or index in original_fans:
                fan_faces.append(len(result))
            result.append(expanded)
            face_sources.append(original_sources[index])
    data["faces"] = result
    data["fan_faces"] = fan_faces
    data["face_sources"] = face_sources
    return data


def triangulate(data):
    """Triangulate polygons with stable geometric and UV-corner identities."""
    corners, lookup, triangles, geometric, triangle_sources = [], {}, [], [], []
    fan_faces = set(data.get("fan_faces", []))
    face_sources = data.get("face_sources", list(range(len(data["faces"]))))
    for face_index, face in enumerate(data["faces"]):
        ids = []
        for corner in face:
            key = tuple(corner)
            if key not in lookup:
                lookup[key] = len(corners)
                corners.append(corner)
            ids.append(lookup[key])
        if len(face) == 3 and face_index not in fan_faces:
            local = [(0, 1, 2)]
        elif len(face) == 4 and face_index not in fan_faces:
            p = [data["vertices"][c[0]] for c in face]
            d02, d13 = sub(p[0], p[2]), sub(p[1], p[3])
            local = [(0, 1, 2), (0, 2, 3)] if dot(d02, d02) <= dot(d13, d13) else [(0, 1, 3), (1, 2, 3)]
        else:
            # Inserted collinear edge points need a center fan, not a diagonal
            # fan that would create zero-area boundary triangles.
            center_id = len(data["vertices"])
            points = [data["vertices"][c[0]] for c in face]
            data["vertices"].append(tuple(sum(p[a] for p in points)/len(points) for a in range(3)))
            data["weights"].append(blend_weights((data["weights"][c[0]], 1/len(face)) for c in face))
            ids.append(len(corners))
            corners.append([center_id, *[sum(c[a] for c in face)/len(face) for a in (1, 2)]])
            face = [*face, corners[-1]]
            local = [(len(ids)-1, i, (i+1)%(len(ids)-1)) for i in range(len(ids)-1)]
        for a, b, c in local:
            original = tuple(face[i][0] for i in (a, b, c))
            if len(set(original)) != 3:
                continue
            p = [data["vertices"][i] for i in original]
            normal = cross(sub(p[1], p[0]), sub(p[2], p[0]))
            if dot(normal, normal) < 4e-6:
                continue
            triangles.append((ids[a], ids[b], ids[c]))
            geometric.append(original)
            triangle_sources.append(face_sources[face_index])
    data.update(corners=corners, triangles=triangles, geometric=geometric, triangle_sources=triangle_sources)
    return data
