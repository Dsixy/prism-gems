"""Original, convex, gemstone-inspired cutting recipes. No Blender dependency.

References describe shape and faceting families, not manufacturing dimensions.
All planes use Godot coordinates: n dot p <= d, Y up.
"""
from itertools import combinations
import math
import numpy as np


SOURCES = {
    "gia_anatomy": "https://4cs.gia.edu/interactive-4cs/cut/anatomy.html",
    "gia_shapes": "https://4cs.gia.edu/en-us/blog/guide-diamond-shapes-engagement-rings/",
    "gia_styles": "https://hongkong.gia.edu/gia-website/gia-news-research-value-factors-gem-cutting-styles-definitions",
}

CUTS = [
    {"id": "round", "name": "圆形明亮式", "en": "ROUND", "style": "明亮式", "description": "放射状三角与风筝切面", "sources": ["gia_anatomy", "gia_shapes"]},
    {"id": "oval", "name": "椭圆形", "en": "OVAL", "style": "改良明亮式", "description": "修长椭圆，连续弧形轮廓", "sources": ["gia_anatomy", "gia_shapes"]},
    {"id": "pear", "name": "水滴形", "en": "PEAR", "style": "改良明亮式", "description": "一端尖、一端圆润的水滴轮廓", "sources": ["gia_shapes"]},
    {"id": "marquise", "name": "马眼形", "en": "MARQUISE", "style": "改良明亮式", "description": "两端尖、左右对称的舟形轮廓", "sources": ["gia_shapes"]},
    {"id": "princess", "name": "公主方形", "en": "PRINCESS", "style": "方形明亮式", "description": "尖角方形与交错的亭部切面", "sources": ["gia_shapes"]},
    {"id": "emerald", "name": "祖母绿阶梯", "en": "EMERALD", "style": "阶梯式", "description": "切角长方形与平行阶梯切面", "sources": ["gia_shapes", "gia_styles"]},
    {"id": "asscher", "name": "阿斯切方阶梯", "en": "ASSCHER", "style": "阶梯式", "description": "宽切角方形，较小台面与深阶梯", "sources": ["gia_shapes"]},
    {"id": "cushion", "name": "枕形", "en": "CUSHION", "style": "改良明亮式", "description": "圆润方角与饱满的弧边", "sources": ["gia_anatomy", "gia_shapes"]},
    {"id": "trillion", "name": "三角形", "en": "TRILLION", "style": "三角明亮式", "description": "三角轮廓与三重对称的切面", "sources": ["gia_anatomy", "gia_styles"]},
]


def regular_outline(count=16, x=1.0, z=1.0, phase=math.pi / 16):
    return np.asarray([[x * math.cos(phase + i * math.tau / count),
                        z * math.sin(phase + i * math.tau / count)] for i in range(count)])


def convex_outline(points):
    points = sorted(set(tuple(map(float, p)) for p in points))
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in points:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 2e-6:
            lower.pop()
        lower.append(p)
    for p in reversed(points):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 2e-6:
            upper.pop()
        upper.append(p)
    return np.asarray(lower[:-1] + upper[:-1])


def outline_planes(outline):
    outline = convex_outline(outline)
    result = []
    for a, b in zip(outline, np.roll(outline, -1, axis=0)):
        edge = b - a
        n = np.array([edge[1], -edge[0]])
        n /= np.linalg.norm(n)
        result.append([float(n[0]), float(n[1]), float(np.sum(n * a))])
    return result


def ring_planes(count, horizontal, vertical, distance, phase=0.0):
    return [[horizontal * math.cos(phase + i * math.tau / count), vertical,
             horizontal * math.sin(phase + i * math.tau / count), distance] for i in range(count)]


def round_planes():
    planes = [[0, 1, 0, .42], [0, -1, 0, .87]]
    planes += ring_planes(16, 1, 0, 1, math.pi / 16)
    planes += ring_planes(8, .72, math.sqrt(1 - .72**2), .749)
    planes += ring_planes(8, .45, math.sqrt(1 - .45**2), .658, math.pi / 8)
    planes += ring_planes(16, .90, math.sqrt(1 - .90**2), .905, math.pi / 16)
    planes += ring_planes(8, .65, -math.sqrt(1 - .65**2), .677, math.pi / 8)
    planes += ring_planes(16, .83, -math.sqrt(1 - .83**2), .837, math.pi / 16)
    return planes


def brilliant_planes(outline, symmetry=8, table=.42, phase=0.0, princess=False):
    outline = convex_outline(outline)
    planes = [[0, 1, 0, table], [0, -1, 0, .86]]
    planes += [[nx, 0, nz, d] for nx, nz, d in outline_planes(outline)]
    tiers = [
        (symmetry, .72, 1, 1.0, .04, phase),
        (symmetry, .45, 1, .65, table, phase + math.pi / symmetry),
        (symmetry * 2, .90, 1, .985, .04, phase + math.pi / (symmetry * 2)),
        (symmetry, .65, -1, .995, .035, phase + math.pi / symmetry),
        (symmetry * 2, .83, -1, .985, .035, phase + math.pi / (symmetry * 2)),
    ]
    if princess:
        # Different azimuths/depths create crossed pavilion images inside a square.
        tiers[-2] = (8, .68, -1, .99, .025, math.pi / 8)
        tiers[-1] = (16, .86, -1, .99, .025, math.pi / 16)
    for count, h, sign, radius, level, offset in tiers:
        v = sign * math.sqrt(1 - h*h)
        for i in range(count):
            angle = offset + i * math.tau / count
            n = np.array([math.cos(angle), math.sin(angle)])
            support = float(np.max(np.sum(outline * n, axis=1)))
            planes.append([h*n[0], v, h*n[1], h*support*radius + abs(v)*level])
    return planes


def beveled_rectangle(x, z, chamfer):
    return np.array([[-x+chamfer, -z], [x-chamfer, -z], [x, -z+chamfer],
                     [x, z-chamfer], [x-chamfer, z], [-x+chamfer, z],
                     [-x, z-chamfer], [-x, -z+chamfer]])


def step_planes(outline, asscher=False):
    edges = outline_planes(outline)
    crown = [(.035, 1), (.13, .965), (.27, .85), (.43, .62)]
    pavilion = [(.035, 1), (.25, .86), (.50, .55), (.79, .035)]
    if asscher:
        crown = [(.035, 1), (.16, .92), (.32, .73), (.48, .50)]
        pavilion = [(.035, 1), (.26, .88), (.51, .50), (.82, .035)]
    planes = [[0, 1, 0, crown[-1][0]], [0, -1, 0, pavilion[-1][0]]]
    planes += [[nx, 0, nz, d] for nx, nz, d in edges]
    for levels, sign in [(crown, 1), (pavilion, -1)]:
        for (y0, s0), (y1, s1) in zip(levels, levels[1:]):
            slope = (s1-s0) / (y1-y0)
            for nx, nz, d in edges:
                planes.append([nx, -sign*d*slope, nz, d*(s0-slope*y0)])
    return planes


def pear_outline():
    def bezier(a, b, c, d, t):
        return (1-t)**3*np.array(a) + 3*(1-t)**2*t*np.array(b) + 3*(1-t)*t*t*np.array(c) + t**3*np.array(d)
    right = [bezier((0, -1.24), (.19, -1.04), (.75, -.40), (.75, .15), t)
             for t in np.linspace(0, 1, 6)]
    right += [bezier((.75, .15), (.75, .65), (.40, 1.08), (0, 1.08), t)
              for t in [.25, .50, .75, 1.0]]
    return convex_outline(right + [np.array([-p[0], p[1]]) for p in right])


def recipe(cut_id):
    if cut_id == "round":
        return round_planes()
    if cut_id == "oval":
        return [[p[0]/.78, p[1], p[2]/1.21, p[3]] for p in round_planes()]
    if cut_id == "emerald":
        return step_planes(beveled_rectangle(.76, 1.18, .18))
    if cut_id == "asscher":
        return step_planes(beveled_rectangle(1.0, 1.0, .30), asscher=True)
    if cut_id == "pear":
        return brilliant_planes(pear_outline())
    if cut_id == "marquise":
        t = np.linspace(0, math.pi, 9)
        right = [np.array([.69 * math.sin(a)**2, -1.27 * math.cos(a)]) for a in t]
        outline = convex_outline(right + [np.array([-p[0], p[1]]) for p in right])
        return brilliant_planes(outline, table=.36)
    if cut_id == "princess":
        return brilliant_planes([[-.96, -.96], [.96, -.96], [.96, .96], [-.96, .96]],
                                symmetry=8, table=.43, princess=True)
    if cut_id == "cushion":
        outline = []
        for a in np.linspace(0, math.tau, 16, endpoint=False):
            x, z = math.cos(a), math.sin(a)
            outline.append([math.copysign(abs(x)**.56, x), math.copysign(abs(z)**.56, z)])
        return brilliant_planes(outline, table=.40)
    if cut_id == "trillion":
        return brilliant_planes(regular_outline(3, 1.13, 1.13, -math.pi/2),
                                symmetry=6, table=.30, phase=math.pi/6)
    raise KeyError(cut_id)


def mesh_from_planes(input_planes):
    raw = np.asarray(input_planes, dtype=float)
    raw /= np.linalg.norm(raw[:, :3], axis=1)[:, None]
    raw = np.unique(np.round(raw, 9), axis=0)
    normals, offsets = raw[:, :3], raw[:, 3]
    indices = np.asarray(list(combinations(range(len(raw)), 3)))
    matrices = normals[indices]
    valid = np.abs(np.linalg.det(matrices)) > 1e-8
    candidates = np.linalg.solve(matrices[valid], offsets[indices[valid]][..., None])[..., 0]
    chunks = []
    for start in range(0, len(candidates), 2048):
        values = candidates[start:start+2048]
        chunks.append(values[np.max(np.einsum('ij,kj->ik', values, normals) - offsets, axis=1) <= 1e-6])
    points = np.unique(np.round(np.concatenate(chunks), 6), axis=0)
    faces, active, centres = [], [], []
    for plane in raw:
        n = plane[:3]
        ids = np.flatnonzero(np.abs(np.sum(points * n, axis=1) - plane[3]) < 2e-5)
        if len(ids) < 3:
            continue
        center = points[ids].mean(axis=0)
        u = np.cross(n, [0, 1, 0] if abs(n[1]) < .95 else [1, 0, 0])
        u /= np.linalg.norm(u)
        v = np.cross(n, u)
        ordered = sorted(ids.tolist(), key=lambda k: math.atan2(np.sum((points[k]-center)*v), np.sum((points[k]-center)*u)))
        faces.append(ordered)
        active.append(plane.tolist())
        centres.append({"position": center.tolist(), "normal": n.tolist()})
    edges = {}
    volume = 0.0
    for face in faces:
        for a, b in zip(face, face[1:]+face[:1]):
            key = tuple(sorted((a, b)))
            edges[key] = edges.get(key, 0) + 1
        for a, b in zip(face[1:-1], face[2:]):
            volume += float(np.sum(points[face[0]] * np.cross(points[a], points[b]))) / 6
    assert len(points) > 3 and all(n == 2 for n in edges.values()), f"Non-manifold cut: {len(points)} vertices, {len(faces)} faces, {[(k,n) for k,n in edges.items() if n != 2][:6]}"
    assert len(points) - len(edges) + len(faces) == 2, "Invalid topology"
    assert 0 < len(active) <= 96 and volume > .01, "Invalid optical solid"
    return points, faces, active, centres, volume


def footprint_data(points):
    points = np.asarray(points)
    outline = convex_outline(points[:, [0, 2]])
    if len(outline) > 32:
        raise ValueError("The floor shader supports at most 32 outline edges.")
    low, high = points.min(axis=0), points.max(axis=0)
    return {"outline": outline.tolist(), "outline_planes": outline_planes(outline),
            "bounds_min": low.tolist(), "bounds_max": high.tolist(),
            "footprint_axes": np.maximum(np.max(np.abs(outline), axis=0), .1).tolist()}


def make_cut(cut):
    points, faces, planes, centres, volume = mesh_from_planes(recipe(cut["id"]))
    data = dict(cut)
    data.update({"name_en": cut["en"], "facet_count": len(faces), "vertex_count": len(points),
                 "coordinate_system": "Godot Y-up; inside is dot(normal, position) <= distance",
                 "planes": planes, "facet_centres": centres, "vertices": points.tolist(),
                 "faces": faces, "volume": volume, "recipe_version": 1})
    data.update(footprint_data(points))
    return data


if __name__ == "__main__":
    for cut in CUTS:
        data = make_cut(cut)
        print(cut["id"], data["vertex_count"], data["facet_count"], round(data["volume"], 4))
