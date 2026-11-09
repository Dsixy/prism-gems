"""Verify coexistence of real internal ray paths, dispersion and special effects."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "artifacts"
qa = json.loads((OUT / "fire_qa_report.json").read_text(encoding="utf-8"))
catalog = json.loads((ROOT / "assets/gem/cut_catalog.json").read_text(encoding="utf-8"))["cuts"]
assert qa["passed"] and qa["parameters_preserved"] and qa["fire_controls_synchronized"]
assert len(qa["combinations"]) == 2 * 2 * len(catalog)


def pixels(name, height=145):
    return np.asarray(Image.open(OUT / name).convert("RGB"), dtype=float)[:height]


combinations = []
for row in qa["combinations"]:
    tag = "%s_%s_%s" % (row["material"], row["cut"], "day" if row["light"] == 0 else "warm")
    off, on = [pixels(f"mixed_{tag}_fire_{i}.png", 180 if not row["faceted"] else 145) for i in range(2)]
    delta = on - off
    difference = float(np.abs(delta).mean())
    chromatic_change = float(delta.std(axis=2).mean())
    if row["faceted"]:
        assert difference > 0.25 and chromatic_change > 0.10, (tag, difference, chromatic_change)
    else:
        assert np.array_equal(off, on), "Smooth effects must retain their previous soft response: " + tag
    combinations.append({"combination": tag, "faceted": row["faceted"],
                         "fire_difference": difference, "chromatic_difference": chromatic_change})

both = pixels("moonfire_enhanced.png")
glow_only = pixels("moonfire_glow_without_fire.png")
fire_only = pixels("moonfire_fire_without_glow.png")
neither = pixels("moonfire_neither.png")
metrics = {
    "fire_with_glow": float(np.abs(both - glow_only).mean()),
    "glow_with_fire": float(np.abs(both - fire_only).mean()),
    "fire_without_glow": float(np.abs(fire_only - neither).mean()),
    "glow_without_fire": float(np.abs(glow_only - neither).mean()),
    "transparency_control": float(np.abs(both - pixels("moonfire_legacy_body.png")).mean()),
    "reflection_depth": float(np.abs(pixels("moonfire_deep_reflections.png") - pixels("moonfire_single_bounce.png")).mean()),
}
assert min(metrics[k] for k in ["fire_with_glow", "glow_with_fire", "fire_without_glow", "glow_without_fire"]) > 0.35, metrics
assert metrics["transparency_control"] > 1 and metrics["reflection_depth"] > 0.35, metrics
# Isolate the blue sheen from fire so rainbow edges alone cannot count as glow.
blue_gain = np.maximum((both[..., 2] - both[..., 0]) - (fire_only[..., 2] - fire_only[..., 0]), 0)
assert (blue_gain > 15).sum() > 80, int((blue_gain > 15).sum())
metrics["distinct_blue_glow_pixels"] = int((blue_gain > 15).sum())

font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 19)
small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 13)
labels = ["月光 + 白闪（火彩 0）", "月光 + 火彩（加强）", "火彩（关闭月光）"]
frames = []
for frame_id in range(60):
    frame = Image.new("RGB", (768, 316), "#f6f6ef")
    draw = ImageDraw.Draw(frame)
    for variant in range(3):
        draw.text((variant * 256 + 12, 8), labels[variant], font=font, fill="#203f36")
        frame.paste(Image.open(OUT / f"moonfire_turn_{variant}_{frame_id:03d}.png").convert("RGB"), (variant * 256, 40))
    draw.text((12, 298), "同角度实际渲染 · 光晕与火彩分别控制 · 十字星装饰关闭", font=small, fill="#64786c")
    frames.append(frame)
strip = Image.new("RGB", (768, 316 * 10))
for i in range(10):
    strip.paste(frames[i * 6], (0, i * 316))
palette = strip.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
animated = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
animated[0].save(OUT / "moonfire_rotation.gif", save_all=True, append_images=animated[1:],
                 duration=100, loop=0, optimize=False, disposal=2)
frames[0].save(OUT / "moonfire_comparison.png")

before = ROOT / "artifacts/moonfire_before/round.png"
if before.exists():
    board = Image.new("RGB", (768, 316), "#f6f6ef")
    draw = ImageDraw.Draw(board)
    for i, (path, label) in enumerate([(before, "修正前：只有软光晕"),
                                      (OUT / "moonfire_default.png", "现在：默认弱火彩"),
                                      (OUT / "moonfire_enhanced.png", "现在：火彩加强")]):
        draw.text((i * 256 + 12, 8), label, font=font, fill="#203f36")
        board.paste(Image.open(path).convert("RGB"), (i * 256, 40))
    draw.text((12, 298), "同切型、同视角、同灯光 · 实际 GPU 画面", font=small, fill="#64786c")
    board.save(OUT / "moonfire_before_after.png")
report = {"passed": True, "combinations_checked": len(combinations), "combinations": combinations,
          "independent_effects": metrics, "decorative_stars_disabled": True, "animation_frames": 60}
(OUT / "facet_effect_checks.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in report.items() if k != "combinations"}, indent=2))
