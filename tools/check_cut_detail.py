"""Validate refined optical solids and compare real, matched GPU turntables."""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np
from scipy.ndimage import binary_erosion, label, maximum_filter, minimum_filter
from scipy.spatial import cKDTree
from PIL import Image, ImageDraw, ImageFont
from qa_masks import reference_mask

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "artifacts"
BEFORE = ROOT / "artifacts/cut_refinement_before"
qa = json.loads((OUT / "cutdetail_qa_report.json").read_text(encoding="utf-8"))
assert qa["passed"] and not qa["before"] and len(qa["materials"]) == 40
catalog = {c["id"]: c for c in json.loads((ROOT / "assets/gem/cut_catalog.json").read_text(encoding="utf-8"))["cuts"]}


def image(root, tag):
    result = Image.open(root / ("cutdetail_" + tag + ".png")).convert("RGB")
    assert result.size == (256, 256), tag
    return result


def pixels(root, tag):
    return np.asarray(image(root, tag), float)[:145]


def family_counts(data):
    y = np.asarray(data["planes"])[:, 1]
    return {"crown": int(((y > .01) & (y < .999)).sum()),
            "pavilion": int(((y < -.01) & (y > -.999)).sum())}


def footprint(data):
    canvas = Image.new("1", (512, 512))
    ImageDraw.Draw(canvas).polygon([((x + 1.6) / 3.2 * 511, (z + 1.6) / 3.2 * 511)
                                   for x, z in data["outline"]], fill=1)
    return np.asarray(canvas, bool)


def bright_features(array):
    mask = binary_erosion(reference_mask(array), iterations=2)
    luminance = array.mean(axis=2)
    # Local bright structure over five pixels, away from the silhouette. Flat
    # white tables cannot satisfy this count; adjacent tied pixels form one peak.
    peaks = (luminance == maximum_filter(luminance, 3)) & mask & (luminance > 140)
    peaks &= luminance - minimum_filter(luminance, 5) > 30
    _, count = label(peaks)
    return int(count), float(np.percentile(array[mask], 99.5))


checks = []
for cut in ["pear", "oval"]:
    old = json.loads((BEFORE / f"assets/gem/cuts/{cut}.json").read_text(encoding="utf-8"))
    new = json.loads((ROOT / f"assets/gem/cuts/{cut}.json").read_text(encoding="utf-8"))
    assert new["facet_count"] == len(new["planes"]) == len(new["faces"]) == catalog[cut]["facet_count"]
    assert new["facet_count"] > old["facet_count"] * 1.8 and new["facet_count"] > 96
    a, b = family_counts(old), family_counts(new)
    assert b["crown"] > a["crown"] * 1.5 and b["pavilion"] > a["pavilion"] * 1.5
    vertices, planes = np.asarray(new["vertices"]), np.asarray(new["planes"])
    assert np.max(np.einsum("ij,kj->ik", vertices, planes[:, :3]) - planes[:, 3]) < 2e-5
    edges, areas = {}, []
    for i, face in enumerate(new["faces"]):
        points = vertices[face]
        assert np.abs(np.sum(points * planes[i, :3], axis=1) - planes[i, 3]).max() < 2e-5
        areas.append(float(np.linalg.norm(np.cross(points, np.roll(points, -1, axis=0)).sum(axis=0)) * .5))
        for x, y in zip(face, face[1:] + face[:1]):
            key = tuple(sorted((x, y)))
            edges[key] = edges.get(key, 0) + 1
    assert min(areas) > 1e-5 and all(count == 2 for count in edges.values())
    assert len(vertices) - len(edges) + len(new["faces"]) == 2
    mirrored = vertices * np.array([-1, 1, 1])
    symmetry_error = float(cKDTree(vertices).query(mirrored)[0].max())
    assert symmetry_error < 2e-5
    if cut == "oval":
        assert cKDTree(vertices).query(vertices * np.array([1, 1, -1]))[0].max() < 2e-5
    old_footprint, new_footprint = footprint(old), footprint(new)
    iou = float((old_footprint & new_footprint).sum() / (old_footprint | new_footprint).sum())
    assert iou > .94 and abs(new["volume"] / old["volume"] - 1) < .10
    cut_check = {"cut": cut, "faces_before_after": [old["facet_count"], new["facet_count"]],
                 "families_before_after": [a, b], "minimum_facet_area": min(areas),
                 "outline_iou": iou, "mirror_error": symmetry_error, "materials": []}
    for mat in ["pink", "diamond"]:
        tag = cut + "_" + mat
        series = []
        for root in [BEFORE, OUT]:
            measurements = [bright_features(pixels(root, tag + f"_turn_{i:03d}")) for i in range(60)]
            series.append(np.mean(measurements, axis=0))
        assert series[1][0] > series[0][0] * 1.03, (tag, series)
        assert series[1][1] > 225 and series[1][1] > series[0][1] - 10, (tag, series)
        reflection = float(np.abs(pixels(OUT, tag + "_deep_reflections") - pixels(OUT, tag + "_single_bounce")).mean())
        fire = float(np.abs(pixels(OUT, tag + "_fire") - pixels(OUT, tag + "_no_fire")).mean())
        change = float(np.abs(pixels(OUT, tag + "_hero") - pixels(BEFORE, tag + "_hero")).mean())
        assert reflection > .5 and fire > .3 and change > 3, (tag, reflection, fire, change)
        cut_check["materials"].append({"material": mat,
            "mean_local_bright_features_before_after": [float(s[0]) for s in series],
            "highlight_995_before_after": [float(s[1]) for s in series],
            "reflection_depth_difference": reflection, "dispersion_difference": fire, "changed_pixels_mean": change})
    assert np.array_equal(pixels(OUT, cut + "_static_a"), pixels(OUT, cut + "_static_b"))
    checks.append(cut_check)

for row in qa["cuts"]:
    assert row["geometry"]["passed"] and row["geometry"]["facet_count"] > 96
for row in qa["materials"]:
    a = pixels(OUT, "%s_%s_%s" % (row["cut"], row["material"], "day" if row["light"] == 0 else "warm"))
    assert a.std() > 12, row

manifest = json.loads((BEFORE / "manifest.json").read_text(encoding="utf-8"))
untouched = []
for name, digest in manifest["asset_hashes"].items():
    if name == "assets/gem/cut_catalog.json" or Path(name).stem in ["pear", "oval"]:
        continue
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
    untouched.append(name)

font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 19)
small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 13)
labels = ["水滴 / 之前 70 面", "水滴 / 现在 136 面", "椭圆 / 之前 74 面", "椭圆 / 现在 146 面"]
frames = []
for frame in range(60):
    board = Image.new("RGB", (1024, 336), "#f6f6ef")
    draw = ImageDraw.Draw(board)
    for column, (cut, root) in enumerate([("pear", BEFORE), ("pear", OUT), ("oval", BEFORE), ("oval", OUT)]):
        draw.text((column * 256 + 12, 10), labels[column], font=font, fill="#203f36")
        board.paste(image(root, f"{cut}_pink_turn_{frame:03d}"), (column * 256, 46))
    draw.text((14, 313), "相同材质、相同灯光、相同视角 · 实际几何与真实内部光路 · 十字星装饰关闭", font=small, fill="#64786c")
    frames.append(board)
strip = Image.new("RGB", (1024, 336 * 10))
for i in range(10):
    strip.paste(frames[i * 6], (0, 336 * i))
palette = strip.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
animated = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
animated[0].save(OUT / "cutdetail_rotation.gif", save_all=True, append_images=animated[1:],
                 duration=100, loop=0, optimize=False, disposal=2)

board = Image.new("RGB", (1024, 680), "#f6f6ef")
draw = ImageDraw.Draw(board)
for row, mat in enumerate(["pink", "diamond"]):
    for column, (cut, root) in enumerate([("pear", BEFORE), ("pear", OUT), ("oval", BEFORE), ("oval", OUT)]):
        x, y = column * 256, row * 324
        draw.text((x + 12, y + 10), labels[column], font=font, fill="#203f36")
        board.paste(image(root, cut + "_" + mat + "_hero"), (x, y + 46))
draw.text((14, 657), "上排：粉色 / 下排：无色 · 光学参数保持相同，改动来自切面与内部路径", font=small, fill="#64786c")
board.save(OUT / "cutdetail_comparison.png")

report = {"passed": True, "cuts": checks, "material_light_combinations": len(qa["materials"]),
          "untouched_assets_verified": untouched, "actual_frames_per_turntable": 60,
          "frozen_pose_identical": True,
          "performance": {k: v for k, v in qa.items() if "readback_ms" in k}}
(OUT / "cutdetail_checks.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in report.items() if k != "untouched_assets_verified"}, indent=2))
