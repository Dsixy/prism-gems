"""Validate rendered material behavior; build an unretouched GPU comparison sheet."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "artifacts"
catalog = json.loads((ROOT / "assets/gem/cut_catalog.json").read_text(encoding="utf-8"))["cuts"]
qa = json.loads((OUT / "qa_report.json").read_text(encoding="utf-8"))
assert qa["materials_passed"] and qa["zone_controls"] and qa["custom_zones_preserved"]
assert len(qa["materials"]) == 4 * 2 * len(catalog)


def pixels(material, cut="round", light="day"):
    return np.asarray(Image.open(OUT / f"material_{material}_{cut}_{light}.png").convert("RGB"), dtype=float)


checks = []
for cut in catalog:
    a, b = [pixels("alexandrite", cut["id"], light)[:145] for light in ["day", "warm"]]
    mask = (np.linalg.norm(a - a[0, 0], axis=2) > 35) & (a.mean(axis=2) > 15)
    day, warm = a[mask].mean(axis=0), b[mask].mean(axis=0)
    # These use only the gem, excluding the changing floor and background.
    assert day[1] - day[0] > 15, (cut["id"], day)
    assert warm[0] - warm[1] > 10 and warm[2] - warm[1] > 5, (cut["id"], warm)
    difference = float(np.abs(a - b)[mask].mean())
    assert difference > 10, (cut["id"], difference)
    checks.append({"cut": cut["id"], "day_mean_rgb": day.tolist(),
                   "warm_mean_rgb": warm.tolist(), "gem_pixel_difference": difference})
    for material in ["bicolor", "ametrine", "watermelon"]:
        for light in ["day", "warm"]:
            image = pixels(material, cut["id"], light)
            assert image.shape == (256, 256, 3) and image[:145].std() > 20

populations = {}
for material in ["bicolor", "watermelon", "ametrine"]:
    a = pixels(material)[:145]
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    if material == "ametrine":
        first = (b - g > 15) & (b - r > 5)
        second = (r - b > 15) & (g - b > 10)
    else:
        first = (g - r > 15) & (g - b > 0)
        second = (r - g > 12) & (b - g > 5)
    counts = [int(first.sum()), int(second.sum())]
    assert min(counts) > 75, (material, counts)
    populations[material] = counts

adjusted = np.asarray(Image.open(OUT / "material_zones_adjusted.png").convert("RGB"), dtype=float)
zone_difference = float(np.abs(adjusted[:145] - pixels("bicolor")[:145]).mean())
assert zone_difference > 2, zone_difference
thin, dense = [np.asarray(Image.open(OUT / f"material_alexandrite_{name}.png").convert("RGB"), dtype=float)
               for name in ["thin", "dense"]]
density_difference = float(np.abs(thin[:145] - dense[:145]).mean())
assert density_difference > 2, density_difference
report = {"passed": True, "combinations_checked": len(qa["materials"]), "alexandrite": checks,
          "two_color_pixel_populations": populations, "zone_adjustment_difference": zone_difference,
          "density_difference": density_difference, "source": "Actual Godot GPU captures; sparkles disabled"}
(OUT / "material_checks.json").write_text(json.dumps(report, indent=2), encoding="utf-8")

font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 22)
small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 15)
board = Image.new("RGB", (1280, 798), "#f6f6ef")
draw = ImageDraw.Draw(board)
draw.text((32, 20), "PRISM / 双色、色带与变石", font=font, fill="#203f36")
draw.text((32, 58), "同一视角与亮度参数 · 上：日光 D65 · 下：暖灯 A / 2856 K · 实际游戏画面", font=small, fill="#64786c")
specimens = [("bicolor", "round", "双色碧玺"), ("ametrine", "emerald", "紫黄晶色带"),
             ("watermelon", "round", "西瓜碧玺"), ("alexandrite", "round", "变石 · 圆形"),
             ("alexandrite", "emerald", "变石 · 阶梯切")]
for i, (material, cut, label) in enumerate(specimens):
    draw.text((256 * i + 16, 104), label, font=small, fill="#203f36")
    for j, light in enumerate(["day", "warm"]):
        board.paste(Image.open(OUT / f"material_{material}_{cut}_{light}.png").convert("RGB"),
                    (i * 256, 140 + j * 302))
        draw.text((i * 256 + 16, 405 + j * 302), "日光" if j == 0 else "暖灯", font=small, fill="#64786c")
draw.text((32, 762), "体内分区吸收 / 随光源与光程变化的变石 · 地面光斑为风格化近似", font=small, fill="#64786c")
board.save(OUT / "material_comparison.png")
print(json.dumps({k: v for k, v in report.items() if k != "alexandrite"}, indent=2))
