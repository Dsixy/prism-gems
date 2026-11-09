"""Validate broad angular rainbow sheen, while retaining faceted optical paths."""
from pathlib import Path
import json
import sys
import numpy as np
from scipy.ndimage import binary_fill_holes, label
from PIL import Image, ImageDraw, ImageFont
from qa_masks import gem_mask, reference_mask

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "artifacts"
BEFORE = ROOT / "artifacts/moonrainbow_before"
qa = json.loads((OUT / "moonrainbow_qa_report.json").read_text(encoding="utf-8"))
for key in ["passed", "optics_preserved", "sheen_settings_preserved",
            "controls_synchronized", "decorative_stars_disabled"]:
    assert qa[key], key
catalog = json.loads((ROOT / "assets/gem/cut_catalog.json").read_text(encoding="utf-8"))["cuts"]
assert len(qa["combinations"]) == len(catalog) * 2


def pixels(name):
    image = Image.open(OUT / name).convert("RGB")
    assert image.size == (256, 256), name
    return np.asarray(image, dtype=float)[:145]


on = pixels("moonrainbow_cushion_day.png")
off = pixels("moonrainbow_cushion_day_no_glow.png")
old = pixels("moonrainbow_legacy_blue.png")
old_off = pixels("moonrainbow_legacy_no_glow.png")
actual_before = np.asarray(Image.open(BEFORE / "cushion_day.png").convert("RGB"), float)[:145]
silhouette = gem_mask(OUT, "cushion")
if silhouette is None:
    silhouette = reference_mask(actual_before)
assert np.array_equal(old[silhouette], actual_before[silhouette]), "The blue setting must reproduce the old gem optical model"
mask = binary_fill_holes(np.linalg.norm(off - off[0, 0], axis=2) > 30)
delta, old_delta = on - off, old - old_off


def extent(effect):
    active = (np.abs(effect).max(axis=2) > 15) & mask
    y, x = np.nonzero(active)
    return {"area": int(active.sum()), "width": int(x.max() - x.min()), "height": int(y.max() - y.min())}


old_extent, new_extent = extent(old_delta), extent(delta)
assert new_extent["area"] > old_extent["area"] * 1.5
assert new_extent["width"] > old_extent["width"] * 1.3
narrow = extent(pixels("moonrainbow_narrow.png") - off)
wide = extent(pixels("moonrainbow_wide.png") - off)
assert wide["area"] > narrow["area"] * 1.15 and wide["height"] > narrow["height"]

# Subtract the no-sheen render so body tint and pre-existing dispersion cannot
# satisfy the rainbow test. Require coherent warm, green and cool regions.
regions = {}
for name, condition in [
        ("warm", delta[..., 0] - delta[..., 2] > 8),
        ("green", delta[..., 1] - np.maximum(delta[..., 0], delta[..., 2]) > 3),
        ("cool", delta[..., 2] - delta[..., 0] > 8)]:
    components, count = label(condition & mask)
    areas = np.bincount(components.ravel())[1:]
    largest = int(areas.max()) if count else 0
    assert largest > 80, (name, largest)
    regions[name] = {"pixels": int((condition & mask).sum()), "largest_connected_region": largest}

angular = float(np.abs(delta - (pixels("moonrainbow_light_90.png")
                                - pixels("moonrainbow_no_glow_light_90.png")))[mask].mean())
assert angular > 8, angular
metrics = {}
for key, a, b, threshold in [
        ("rainbow_control", "blue", "full_rainbow", 1),
        ("depth_control", "shallow", "deep", 1),
        ("transparency_control", "soft_body", "clear_body", 1),
        ("reflection_depth_with_sheen", "single_bounce", "deep_reflections", 0.35)]:
    metrics[key] = float(np.abs(pixels(f"moonrainbow_{a}.png") - pixels(f"moonrainbow_{b}.png")).mean())
    assert metrics[key] > threshold, (key, metrics[key])
assert np.array_equal(pixels("moonrainbow_static_a.png"), pixels("moonrainbow_static_b.png"))

combinations = []
for row in qa["combinations"]:
    assert row["passed"]
    tag = "moonrainbow_%s_%s" % (row["cut"], "day" if row["light"] == 0 else "warm")
    glow = float(np.abs(pixels(tag + ".png") - pixels(tag + "_no_glow.png")).mean())
    fire_delta = pixels(tag + "_fire_1.png") - pixels(tag + "_fire_0.png")
    fire, chroma = float(np.abs(fire_delta).mean()), float(fire_delta.std(axis=2).mean())
    assert glow > 1, (tag, glow)
    if row["faceted"]:
        assert fire > 0.25 and chroma > 0.10, (tag, fire, chroma)
    else:
        assert np.array_equal(pixels(tag + "_fire_0.png"), pixels(tag + "_fire_1.png")), tag
    combinations.append({"capture": tag, "glow_difference": glow,
                         "fire_difference": fire, "chromatic_fire_difference": chroma})

font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 19)
small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 13)
frames = []
for i in range(60):
    board = Image.new("RGB", (1024, 580), "#f6f6ef")
    draw = ImageDraw.Draw(board)
    for column, (path, caption) in enumerate([
            (BEFORE / f"turn_{i:03d}.png", "之前 / 局部蓝白月光"),
            (OUT / f"moonrainbow_turn_{i:03d}.png", "现在 / 宽而柔和的彩虹浮光")]):
        draw.text((column * 512 + 18, 12), caption, font=font, fill="#203f36")
        image = Image.open(path).convert("RGB").resize((512, 512), Image.Resampling.NEAREST)
        board.paste(image, (column * 512, 45))
    draw.text((18, 562), "同外形、同视角、同灯光 · 默认弱火彩 · 保留内部反射 · 无十字星装饰 · 实际 GPU 帧", font=small, fill="#64786c")
    frames.append(board)
strip = Image.new("RGB", (1024, 580 * 10))
for i in range(10):
    strip.paste(frames[i * 6], (0, i * 580))
palette = strip.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
animated = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
animated[0].save(OUT / "moonrainbow_before_after.gif", save_all=True, append_images=animated[1:],
                 duration=100, loop=0, optimize=False, disposal=2)
frames[0].save(OUT / "moonrainbow_before_after.png")

sheet = Image.new("RGB", (1024, 646), "#f6f6ef")
draw = ImageDraw.Draw(sheet)
for i, (name, caption) in enumerate([
        ("moonrainbow_legacy_blue.png", "原蓝白月光"),
        ("moonrainbow_cushion_day.png", "彩虹光晕 / 日光"),
        ("moonrainbow_cushion_warm.png", "彩虹光晕 / 暖灯"),
        ("moonrainbow_light_90.png", "固定宝石 / 灯光 90°"),
        ("moonrainbow_cushion_day_no_glow.png", "关闭光晕 / 保留透明光路"),
        ("moonrainbow_cushion_day_fire_0.png", "光晕 + 白闪 / 火彩 0"),
        ("moonrainbow_cushion_day_fire_1.png", "光晕 + 火彩加强"),
        ("moonrainbow_oval_cabochon_day.png", "彩虹月光 / 椭圆弧面")]):
    x, y = i % 4 * 256, i // 4 * 314
    draw.text((x + 10, y + 8), caption, font=small, fill="#203f36")
    sheet.paste(Image.open(OUT / name).convert("RGB"), (x, y + 37))
draw.text((12, 628), "同姿态真实渲染 · 光晕、通透度、反射深度和色散分别检查", font=small, fill="#64786c")
sheet.save(OUT / "moonrainbow_comparison.png")
report = {"passed": True, "combinations": combinations, "previous_glow_extent": old_extent,
          "rainbow_glow_extent": new_extent, "narrow_extent": narrow, "wide_extent": wide,
          "rainbow_regions": regions, "isolated_light_response": angular, "controls": metrics,
          "blue_mode_matches_before": True, "frozen_pose_and_light_identical": True,
          "decorative_stars_disabled": True, "actual_rotation_frames": 60}
(OUT / "moonrainbow_checks.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in report.items() if k != "combinations"}, indent=2))
