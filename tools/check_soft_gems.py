"""Validate smooth-form optics from actual GPU images and record moving lights."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "artifacts"
catalog = json.loads((ROOT / "assets/gem/cut_catalog.json").read_text(encoding="utf-8"))["cuts"]
qa = json.loads((OUT / "soft_qa_report.json").read_text(encoding="utf-8"))
assert qa["passed"] and qa["custom_parameters_preserved"] and qa["lights_synchronized"]
assert len(qa["combinations"]) == 3 * 2 * len(catalog)
assert all(c["passed"] and c["geometry"]["passed"] for c in qa["combinations"])
assert all(r["passed"] for r in qa["recommended_shapes"])


def pixels(name):
    return np.asarray(Image.open(OUT / name).convert("RGB"), dtype=float)[:180]


def centroid(effect):
    w = np.maximum(effect, 0).sum(axis=2)
    y, x = np.indices(w.shape)
    return np.array([(x * w).sum(), (y * w).sum()]) / max(w.sum(), 0.0001)


checks = {}
for name, off in [("pearl", "no_orient"), ("catseye", "no_eye"), ("moonstone", "no_glow")]:
    on = pixels(f"soft_{name}_hero.png")
    reference = pixels(f"soft_{name}_{off}.png")
    mask = np.linalg.norm(reference - reference[0, 0], axis=2) > 30
    difference = float(np.abs(on - reference)[mask].mean())
    assert difference > 1, (name, difference)
    checks[name] = {"effect_pixel_difference": difference}
    if name != "pearl":
        lit90 = pixels(f"soft_{name}_light_015.png")
        ref90 = pixels(f"soft_{name}_{off}_light_90.png")
        a, b = centroid(on - reference), centroid(lit90 - ref90)
        movement = float(np.linalg.norm(a - b))
        assert movement > 4, (name, a, b)
        checks[name].update({"effect_centroid_at_0_degrees": a.tolist(),
                             "effect_centroid_at_90_degrees": b.tolist(),
                             "isolated_effect_movement_pixels": movement})

pearl_gloss = float(np.abs(pixels("soft_pearl_hero.png") - pixels("soft_pearl_no_luster.png")).mean())
assert pearl_gloss > 0.5, pearl_gloss
eye_reference = pixels("soft_catseye_no_eye.png")
width_counts = [int((np.maximum(pixels(f"soft_catseye_{s}.png") - eye_reference, 0).mean(axis=2) > 20).sum())
                for s in ["narrow", "wide"]]
assert width_counts[1] > width_counts[0] * 2, width_counts
axis_difference = float(np.abs(pixels("soft_catseye_hero.png") - pixels("soft_catseye_axis_90.png")).mean())
assert axis_difference > 2, axis_difference
depth_difference = float(np.abs(pixels("soft_moonstone_shallow.png") - pixels("soft_moonstone_deep.png")).mean())
assert depth_difference > 1, depth_difference
assert np.array_equal(pixels("soft_static_a.png"), pixels("soft_static_b.png"))
for combo in qa["combinations"]:
    name = "soft_%s_%s_%s.png" % (combo["material"], combo["cut"], "day" if combo["light"] == 0 else "warm")
    image = Image.open(OUT / name).convert("RGB")
    assert image.size == (256, 256) and np.asarray(image).std() > 12, name

font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 20)
small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 14)
labels = [("pearl", "珍珠 / 圆珠"), ("catseye", "猫眼 / 椭圆弧面"), ("moonstone", "月光石 / 椭圆弧面")]
frames = []
for i in range(60):
    frame = Image.new("RGB", (768, 314), "#f6f6ef")
    draw = ImageDraw.Draw(frame)
    for j, (name, label) in enumerate(labels):
        draw.text((j * 256 + 16, 8), label, font=font, fill="#203f36")
        frame.paste(Image.open(OUT / f"soft_{name}_light_{i:03d}.png").convert("RGB"), (j * 256, 40))
    draw.text((16, 297), "固定宝石，转动灯光 · 实际游戏画面 · 无装饰性十字星", font=small, fill="#64786c")
    frames.append(frame)
strip = Image.new("RGB", (768, 314 * 10))
for i in range(10):
    strip.paste(frames[i * 6], (0, i * 314))
palette = strip.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
animated = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
animated[0].save(OUT / "soft_gems_lighting.gif", save_all=True, append_images=animated[1:],
                 duration=100, loop=0, optimize=False, disposal=2)
frames[0].save(OUT / "soft_gems_preview.png")

# Large, nearest-neighbor specimen sheet for inspecting the material details.
sheet = Image.new("RGB", (1536, 648), "#f6f6ef")
draw = ImageDraw.Draw(sheet)
for j, (name, label) in enumerate(labels):
    draw.text((j * 512 + 24, 20), label, font=font, fill="#203f36")
    im = Image.open(OUT / f"soft_{name}_hero.png").convert("RGB").resize((512, 512), Image.Resampling.NEAREST)
    sheet.paste(im, (j * 512, 70))
draw.text((24, 610), "PRISM / Blender + Godot · 光滑曲面与三种独立光学响应 · 实际 GPU 渲染", font=font, fill="#64786c")
sheet.save(OUT / "soft_gems_comparison.png")
report = {"passed": True, "combinations_checked": len(qa["combinations"]), "effects": checks,
          "pearl_luster_difference": pearl_gloss, "eye_narrow_wide_pixel_counts": width_counts,
          "eye_axis_difference": axis_difference, "moon_depth_difference": depth_difference,
          "frozen_pose_and_light_identical": True, "light_animation_frames": 60,
          "decorative_stars_disabled": True}
(OUT / "soft_gems_checks.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps(report, indent=2))
