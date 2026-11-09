"""Check actual opal GPU renders and encode a faithful turntable preview."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "artifacts"
qa = json.loads((OUT / "opal_qa_report.json").read_text(encoding="utf-8"))
assert qa["passed"] and qa["custom_settings_preserved"] and qa["light_controls_synchronized"]
catalog = json.loads((ROOT / "assets/gem/cut_catalog.json").read_text(encoding="utf-8"))["cuts"]
assert len(qa["combinations"]) == 2 * len(catalog)


def pixels(name):
    return np.asarray(Image.open(OUT / name).convert("RGB"), dtype=float)[:145]


on = pixels("opal_turn_000.png")
off = pixels("opal_no_color.png")
other_light = pixels("opal_light_90.png")
other_light_off = pixels("opal_no_color_light_90.png")
mask = (np.linalg.norm(on - on[0, 0], axis=2) > 35) & (on.mean(axis=2) > 15)
color_difference = float(np.abs(on - off)[mask].mean())
# Subtract each light's non-diffracting reference so changing studio reflections
# alone cannot satisfy the test for an angular change in the colored patches.
angular_difference = float(np.abs((on - off) - (other_light - other_light_off))[mask].mean())
size_difference = float(np.abs(pixels("opal_small_patches.png") - pixels("opal_large_patches.png")).mean())
haze_difference = float(np.abs(pixels("opal_clear.png") - pixels("opal_milky.png")).mean())
assert color_difference > 8 and angular_difference > 8
assert size_difference > 2 and haze_difference > 2
assert np.array_equal(pixels("opal_static_a.png"), pixels("opal_static_b.png")), "Color must stay still when pose and lighting are frozen"

combinations = []
for entry in qa["combinations"]:
    name = "opal_%s_%s.png" % (entry["cut"], "day" if entry["light"] == 0 else "warm")
    image = Image.open(OUT / name).convert("RGB")
    assert image.size == (256, 256)
    hsv = np.asarray(image.convert("HSV"))[:145]
    colored = (hsv[..., 1] > 60) & (hsv[..., 2] > 90)
    histogram = np.histogram(hsv[..., 0][colored], bins=6, range=(0, 256))[0]
    assert colored.sum() > 200 and (histogram > 30).sum() >= 4, (name, histogram)
    combinations.append({"capture": name, "colored_pixels": int(colored.sum()), "hue_histogram": histogram.tolist()})

frames = [Image.open(OUT / f"opal_turn_{i:03d}.png").convert("RGB") for i in range(72)]
rotation_difference = float(np.abs(np.asarray(frames[0], float) - np.asarray(frames[18], float))[:145].mean())
assert rotation_difference > 5
# A shared palette prevents GIF palette flicker. Source pixels are enlarged
# with nearest-neighbor; no recoloring or synthesized frames are involved.
palette_strip = Image.new("RGB", (256 * 12, 256))
for i in range(12):
    palette_strip.paste(frames[i * 6], (i * 256, 0))
palette = palette_strip.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
animated = [frame.resize((512, 512), Image.Resampling.NEAREST).quantize(
    palette=palette, dither=Image.Dither.NONE) for frame in frames]
animated[0].save(OUT / "opal_rotation.gif", save_all=True, append_images=animated[1:],
                 duration=100, loop=0, optimize=False, disposal=2)

font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 20)
small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 14)
board = Image.new("RGB", (1024, 698), "#f6f6ef")
draw = ImageDraw.Draw(board)
draw.text((24, 18), "PRISM / 水晶欧泊 · 实际 GPU 画面", font=font, fill="#203f36")
draw.text((24, 54), "上排：旋转观察 · 下排：固定宝石，改变光照与乳浊程度 · 已关闭十字星装饰", font=small, fill="#64786c")
for i, frame in enumerate([frames[0], frames[12], frames[24], frames[36]]):
    board.paste(frame, (i * 256, 94))
    draw.text((i * 256 + 16, 354), f"旋转 {i * 60}°", font=small, fill="#64786c")
for i, (name, label) in enumerate([
        ("opal_oval_day.png", "日光 / 灯光 0°"), ("opal_light_90.png", "日光 / 灯光 90°"),
        ("opal_clear.png", "低乳浊 / 通透"), ("opal_milky.png", "高乳浊 / 柔和")]):
    board.paste(Image.open(OUT / name).convert("RGB"), (i * 256, 392))
    draw.text((i * 256 + 16, 654), label, font=small, fill="#64786c")
board.save(OUT / "opal_comparison.png")
report = {"passed": True, "combinations": combinations, "color_difference": color_difference,
          "isolated_angular_color_difference": angular_difference, "size_difference": size_difference,
          "haze_difference": haze_difference, "rotation_difference": rotation_difference,
          "frozen_pose_and_light_identical": True, "decorative_stars_disabled": True,
          "turntable_frames": len(frames)}
(OUT / "opal_checks.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in report.items() if k != "combinations"}, indent=2))
