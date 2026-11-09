"""Check actual GPU output: concentrated studio lights and coherent black opal."""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np
from scipy.ndimage import binary_fill_holes, label
from PIL import Image, ImageDraw, ImageFont
from qa_masks import gem_mask, reference_mask

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "artifacts"
BEFORE = ROOT / "artifacts/optimization_before"
qa = json.loads((OUT / "refinement_qa_report.json").read_text(encoding="utf-8"))
for key in ["passed", "recommended_form", "crystal_defaults_separate",
            "black_settings_preserved", "crystal_settings_preserved", "decorative_stars_disabled"]:
    assert qa[key], key
catalog = json.loads((ROOT / "assets/gem/cut_catalog.json").read_text(encoding="utf-8"))["cuts"]
assert len(qa["combinations"]) == 2 * len(catalog)


def pixels(name):
    image = Image.open(OUT / name).convert("RGB")
    assert image.size == (256, 256), name
    return np.asarray(image, dtype=float)[:145]


lighting = []
for i in range(6):
    old, new = [pixels(f"refine_lighting_{version}_{i}.png") for version in ["old", "new"]]
    # Fill the silhouette once and use exactly the same mask for both pictures;
    # a pale face close to the background must not disappear from the count.
    mask = binary_fill_holes(np.linalg.norm(old - old[0, 0], axis=2) > 25)
    measurements = []
    for image in [old, new]:
        high, low = image.max(axis=2), image.min(axis=2)
        chroma, luminance = high - low, image.mean(axis=2)
        measurements.append({
            "pale_bright_pixels": int(((low > 175) & (chroma < 45) & mask).sum()),
            "colored_dark_pixels": int(((luminance < 90) & (chroma > 22) & mask).sum()),
            "highlight_998": float(np.percentile(high[mask], 99.8)),
        })
    a, b = measurements
    assert b["pale_bright_pixels"] < a["pale_bright_pixels"] * 0.90, i
    assert b["colored_dark_pixels"] > a["colored_dark_pixels"] * 1.15, i
    # Uniform dimming cannot pass: retain near-white specular peaks.
    assert b["highlight_998"] >= 235 and b["highlight_998"] >= a["highlight_998"] - 5, i
    lighting.append({"preset": i, "old_studio": a, "new_studio": b})

on, off, light, light_off = [pixels(name) for name in [
    "black_opal_turn_000.png", "black_opal_no_color.png",
    "black_opal_light_90.png", "black_opal_no_color_light_90.png"]]
mask = binary_fill_holes(np.linalg.norm(on - on[0, 0], axis=2) > 35)
color_difference = float(np.abs(on - off)[mask].mean())
angular_difference = float(np.abs((on - off) - (light - light_off))[mask].mean())
size_difference = float(np.abs(pixels("black_opal_small_patches.png") - pixels("black_opal_large_patches.png")).mean())
assert color_difference > 15 and angular_difference > 15 and size_difference > 2
assert off[mask].mean() < 90, "The base must remain dark when play-of-color is disabled"
assert np.array_equal(pixels("black_opal_static_a.png"), pixels("black_opal_static_b.png"))

combinations = []
for row in qa["combinations"]:
    assert row["passed"]
    name = "black_opal_%s_%s.png" % (row["cut"], "day" if row["light"] == 0 else "warm")
    pixels(name)
    hsv = np.asarray(Image.open(OUT / name).convert("HSV"))[:145]
    colored = (hsv[..., 1] > 90) & (hsv[..., 2] > 90)
    largest, large_hues = 0, 0
    for hue in range(6):
        components, count = label(colored & (hsv[..., 0] // 43 == hue))
        areas = np.bincount(components.ravel())[1:]
        area = int(areas.max()) if count else 0
        largest = max(largest, area)
        large_hues += area > 50
    # Require spatially connected color fields, not just scattered rainbow dots.
    assert colored.sum() > 400 and largest > 150 and large_hues >= 3, name
    combinations.append({"capture": name, "colored_pixels": int(colored.sum()),
                         "largest_same_hue_patch": largest, "large_hue_regions": large_hues})

manifest = json.loads((BEFORE / "manifest.json").read_text(encoding="utf-8"))
volume_hash = hashlib.sha256((ROOT / "assets/materials/opal_domains.bin").read_bytes()).hexdigest()
assert volume_hash == manifest["opal_volume_sha256"], "Preserve the existing crystal-opal domains"
# These comparisons are available after the corresponding regression suites.
unchanged = []
for name in manifest["saved_images"]:
    # Moonstone is intentionally revised by the later rainbow-sheen iteration.
    # Pear/oval geometry is deliberately replaced by the later detail iteration;
    # keep immutable snapshots for the unmodified smooth forms.
    if name.startswith(("preset_", "opal_")) or "moon" in name or not (OUT / name).exists():
        continue
    before = np.asarray(Image.open(BEFORE / name).convert("RGB"), float)[:145]
    after = np.asarray(Image.open(OUT / name).convert("RGB"), float)[:145]
    # The floor is intentionally revised in the later caustic iteration.
    # Compare only the gem, using its actual silhouette where available.
    cut = "pear" if "pear" in name else ("oval" if "oval" in name else ("sphere" if "pearl" in name else "oval_cabochon"))
    mask = gem_mask(OUT, cut)
    if mask is None:
        mask = reference_mask(before)
    assert np.array_equal(before[mask], after[mask]), name
    unchanged.append(name)

frames = [Image.open(OUT / f"black_opal_turn_{i:03d}.png").convert("RGB") for i in range(60)]
rotation_difference = float(np.abs(np.asarray(frames[0], float) - np.asarray(frames[15], float))[:145].mean())
assert rotation_difference > 5
strip = Image.new("RGB", (256 * 12, 256))
for i in range(12):
    strip.paste(frames[i * 5], (256 * i, 0))
palette = strip.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
animated = [f.resize((512, 512), Image.Resampling.NEAREST).quantize(
    palette=palette, dither=Image.Dither.NONE) for f in frames]
animated[0].save(OUT / "black_opal_rotation.gif", save_all=True, append_images=animated[1:],
                 duration=100, loop=0, optimize=False, disposal=2)

font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 20)
small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 14)
board = Image.new("RGB", (1024, 718), "#f6f6ef")
draw = ImageDraw.Draw(board)
draw.text((20, 16), "PRISM / 第一轮观感优化 · 实际 GPU 画面", font=font, fill="#203f36")
draw.text((20, 53), "上排：相同视角与光照，调整灯箱和吸收 · 下排：欧泊材质对比与黑欧泊旋转", font=small, fill="#64786c")
panels = [(BEFORE / "preset_1.png", "粉色 / 优化前"),
          (OUT / "refine_lighting_new_1.png", "粉色 / 优化后"),
          (BEFORE / "preset_0.png", "绿色 / 优化前"),
          (OUT / "refine_lighting_new_0.png", "绿色 / 优化后"),
          (ROOT / "artifacts/opal_pear_day.png", "保留：水晶欧泊"),
          (OUT / "black_opal_turn_000.png", "新增：黑欧泊"),
          (OUT / "black_opal_turn_015.png", "黑欧泊 / 旋转 90°"),
          (OUT / "black_opal_turn_030.png", "黑欧泊 / 旋转 180°")]
for i, (path, caption) in enumerate(panels):
    x, y = (i % 4) * 256, 90 + (i // 4) * 310
    board.paste(Image.open(path).convert("RGB"), (x, y))
    draw.text((x + 12, y + 264), caption, font=small, fill="#203f36")
board.save(OUT / "refinement_comparison.png")
report = {"passed": True, "lighting": lighting, "combinations": combinations,
          "color_difference": color_difference, "isolated_angular_color_difference": angular_difference,
          "patch_size_difference": size_difference, "rotation_difference": rotation_difference,
          "frozen_pose_and_light_identical": True, "crystal_volume_preserved": True,
          "unchanged_regression_images": unchanged, "turntable_frames": len(frames)}
(OUT / "refinement_checks.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in report.items() if k not in ["lighting", "combinations"]}, indent=2))
