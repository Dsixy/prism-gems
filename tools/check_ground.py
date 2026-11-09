"""Inspect actual GPU caustics, light-dependent shadows and isolated gem pixels."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from qa_masks import gem_mask

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "artifacts"
BEFORE = ROOT / "artifacts/ground_before"
qa = json.loads((OUT / "ground_qa_report.json").read_text(encoding="utf-8"))
assert qa["passed"] and qa["softness_preserved"]
assert len(qa["combinations"]) == 24 and len(qa["materials"]) == 10


def rgb(name):
    image = Image.open(OUT / ("ground_" + name + ".png")).convert("RGB")
    assert image.size == (256, 256), name
    return np.asarray(image, dtype=float)


def field(name):
    return rgb(name + "_on") - rgb(name + "_off")


def centroid(effect):
    energy = np.maximum(effect, 0).sum(axis=2)
    y, x = np.indices(energy.shape)
    return np.array([(x * energy).sum(), (y * energy).sum()]) / max(energy.sum(), 0.00001)


hero = field("hero")
mask = rgb("gem_mask").mean(axis=2) > 127
assert mask.sum() > 1000
assert np.array_equal(rgb("hero_on")[mask], rgb("hero_off")[mask]), "Ground light must remain behind the gem"
before = np.asarray(Image.open(BEFORE / "baseline.png").convert("RGB"), float)
assert np.array_equal(rgb("hero_on")[mask], before[mask]), "Preserve the gem itself"
assert hero.min() >= 0 and hero.sum() > 20000
rotation = float(np.abs(field("turn_000") - field("turn_010")).mean())
light = float(np.abs(field("light_000") - field("light_015")).mean())
movement = float(np.linalg.norm(centroid(field("light_000")) - centroid(field("light_015"))))
assert rotation > 0.20 and light > 0.40 and movement > 3

combinations = []
for row in qa["combinations"]:
    assert row["passed"]
    tag = "%s_%s" % (row["cut"], "day" if row["light"] == 0 else "warm")
    energy = field(tag)
    silhouette = gem_mask(OUT, row["cut"], 256)
    assert silhouette is not None
    assert np.array_equal(rgb(tag + "_on")[silhouette], rgb(tag + "_off")[silhouette]), tag
    assert energy.sum() > 5000 and (energy.max(axis=2) > 10).sum() > 100, tag
    combinations.append({"capture": tag, "positive_energy": float(energy.sum()),
                         "bright_floor_pixels": int((energy.max(axis=2) > 10).sum())})
materials = []
for row in qa["materials"]:
    energy = field("material_" + row["id"])
    power = float(energy.sum())
    if row["opaque"]:
        assert np.array_equal(rgb("material_" + row["id"] + "_on"), rgb("material_" + row["id"] + "_off")), row
    else:
        assert power > 1000, row
    materials.append({"id": row["id"], "opaque": row["opaque"], "energy": power})

neutral, refracted = field("ior_neutral"), field("ior_diamond")
ior_change = float(np.abs(neutral - refracted).mean())
assert ior_change > 1
achromatic, dispersed = field("dispersion_0"), field("dispersion_1")
chroma = [float(image.std(axis=2).mean()) for image in [achromatic, dispersed]]
assert chroma[1] > max(chroma[0] * 2, 0.1), chroma
half = rgb("half_strength") - rgb("hero_off")
assert 0 < half.sum() < hero.sum(), "Intensity must affect the deposited light"
assert np.array_equal(rgb("static_a"), rgb("static_b")), "A frozen pose must not shimmer on its own"

floor = ~mask
shadow_hard = (rgb("no_shadow") - rgb("hard_shadow")).mean(axis=2)
shadow_soft = (rgb("no_shadow") - rgb("soft_shadow")).mean(axis=2)
transition = [int(((image > 2) & (image < 12) & floor).sum()) for image in [shadow_hard, shadow_soft]]
assert transition[1] > transition[0] * 1.2, transition
assert 20 < shadow_soft[floor].max() < 95, "Keep the floor shadow visible and translucent"
shadow_light = float(np.abs(rgb("hero_off") - rgb("shadow_light_90"))[floor].mean())
tilt_mask = rgb("mask_tilted").mean(axis=2) > 127
shadow_tilt = float(np.abs(rgb("hero_off") - rgb("shadow_tilted"))[floor & ~tilt_mask].mean())
assert shadow_light > 1 and shadow_tilt > 0.2

# Compare pre-change gem pixels with all revised material references. Ground
# pixels are deliberately excluded using independent, unshaded GPU silhouettes.
unchanged = ["baseline.png"]
for name, cut in [("preset_1.png", "round"), ("moonrainbow_cushion_day.png", "cushion"),
                  ("soft_pearl_hero.png", "sphere"), ("soft_catseye_hero.png", "oval_cabochon"),
                  ("opal_pear_day.png", "pear"), ("black_opal_turn_000.png", "pear")]:
    # Refined pear/oval solids have different internal paths by design. Their
    # before/after behavior is validated by check_cut_detail.py.
    if cut in ["pear", "oval"]:
        continue
    path = OUT / name
    if not path.exists():
        continue
    silhouette = gem_mask(OUT, cut, 256)
    old, new = [np.asarray(Image.open(p).convert("RGB")) for p in [BEFORE / name, path]]
    assert np.array_equal(old[silhouette], new[silhouette]), name
    unchanged.append(name)

font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 20)
small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 13)
frames = []
for i in range(60):
    board = Image.new("RGB", (1024, 580), "#f6f6ef")
    draw = ImageDraw.Draw(board)
    for column, (name, caption) in enumerate([
            (f"turn_{i:03d}_on", "固定灯光 / 旋转宝石"),
            (f"light_{i:03d}_on", "固定宝石 / 转动灯光")]):
        draw.text((column * 512 + 18, 12), caption, font=font, fill="#203f36")
        image = Image.open(OUT / ("ground_" + name + ".png")).convert("RGB")
        board.paste(image.resize((512, 512), Image.Resampling.NEAREST), (column * 512, 44))
    draw.text((18, 561), "真实几何折射落地 · 聚光、彩边与投影阴影随角度变化 · 实际 GPU 帧 · 无十字星装饰", font=small, fill="#64786c")
    frames.append(board)
strip = Image.new("RGB", (1024, 580 * 10))
for i in range(10):
    strip.paste(frames[i * 6], (0, i * 580))
palette = strip.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
animated = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
animated[0].save(OUT / "ground_rotation_lighting.gif", save_all=True, append_images=animated[1:],
                 duration=100, loop=0, optimize=False, disposal=2)

board = Image.new("RGB", (1024, 646), "#f6f6ef")
draw = ImageDraw.Draw(board)
for i, (path, caption) in enumerate([
        (BEFORE / "baseline.png", "之前 / 叠色光斑与硬阴影"),
        (OUT / "ground_hero_on.png", "现在 / 折射聚光与柔和阴影"),
        (OUT / "ground_hero_off.png", "关闭焦散 / 仅看阴影"),
        (OUT / "ground_light_015_on.png", "固定宝石 / 灯光 90°"),
        (OUT / "ground_emerald_day_on.png", "阶梯切型 / 折射亮纹"),
        (OUT / "ground_oval_cabochon_day_on.png", "弧面 / 扇状聚光"),
        (OUT / "ground_hard_shadow.png", "阴影柔和度 / 0%"),
        (OUT / "ground_soft_shadow.png", "阴影柔和度 / 100%")]):
    x, y = i % 4 * 256, i // 4 * 314
    draw.text((x + 10, y + 8), caption, font=small, fill="#203f36")
    board.paste(Image.open(path).convert("RGB"), (x, y + 37))
draw.text((12, 628), "同一项目实际渲染 · 三组折射光线落到地面 · 阴影按当前几何和灯光方向投影", font=small, fill="#64786c")
board.save(OUT / "ground_comparison.png")

report = {"passed": True, "combinations": combinations, "materials": materials,
          "isolated_caustic_rotation_difference": rotation, "isolated_caustic_light_difference": light,
          "light_centroid_movement_pixels": movement, "ior_difference": ior_change,
          "dispersion_chroma_off_on": chroma, "shadow_transition_pixels_hard_soft": transition,
          "shadow_light_difference": shadow_light, "shadow_tilt_difference": shadow_tilt,
          "frozen_pose_identical": True, "gem_pixels_unchanged": unchanged,
          "photons_per_band": qa["photons_per_band"], "render_readback_ms_median": qa["render_readback_ms_median"],
          "render_readback_ms_p95": qa["render_readback_ms_p95"], "actual_frames_per_animation": 60}
(OUT / "ground_checks.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in report.items() if k not in ["combinations", "materials"]}, indent=2))
