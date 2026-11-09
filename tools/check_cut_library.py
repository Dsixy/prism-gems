"""Check rendered cut variety and every material combination, then make a QA atlas."""
from pathlib import Path
import json
import itertools
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "artifacts"
catalog = json.loads((ROOT / "assets/gem/cut_catalog.json").read_text(encoding="utf-8"))["cuts"]
report = json.loads((ART / "qa_report.json").read_text(encoding="utf-8"))
assert report["cuts_passed"] and len(report["cuts"]) == len(catalog)
assert sum(c.get("geometry_mode", 0) == 0 for c in catalog) == 9
assert sum(c.get("geometry_mode", 0) > 0 for c in catalog) == 3
top_views = {}
color_differences = {}
for cut in catalog:
    cut_id = cut["id"]
    image = np.asarray(Image.open(ART / f"cut_{cut_id}_top.png").convert("RGB"), dtype=float)
    assert image.shape == (256, 256, 3)
    assert image.std() > 20, f"Blank cut: {cut_id}"
    top_views[cut_id] = image
    colors = []
    for i in range(6):
        combo = np.asarray(Image.open(ART / f"cut_{cut_id}_color_{i}.png").convert("RGB"), dtype=float)
        assert combo.std() > 20, f"Blank material: {cut_id}/{i}"
        colors.append(combo)
    difference = float(np.abs(colors[0] - colors[1]).mean())
    assert difference > 1.0, f"Material did not change: {cut_id}"
    color_differences[cut_id] = difference

pair_differences = {a+"/"+b: float(np.abs(top_views[a]-top_views[b]).mean())
                    for a, b in itertools.combinations(top_views, 2)}
assert min(pair_differences.values()) > 2.0, "Two cuts have indistinguishable rendered shapes."
checks = {"passed": True, "cut_count": len(catalog), "material_combinations_checked": len(catalog) * 6,
          "smallest_cut_pair_difference": min(pair_differences.values()),
          "green_pink_differences": color_differences,
          "geometry_checks_passed": all(c["geometry"]["passed"] for c in report["cuts"])}
(ART / "cut_checks.json").write_text(json.dumps(checks, indent=2), encoding="utf-8")

# Contact sheet of actual GPU renders. No illustration or replacement rendering.
sheet = Image.new("RGB", (960, ((len(catalog) + 2) // 3) * 370), "#f6f6ef")
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 23)
small = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 13)
for i, cut in enumerate(catalog):
    x, y = (i % 3)*320, (i // 3)*370
    frame = Image.open(ART / f"cut_{cut['id']}_top.png").convert("RGB")
    sheet.paste(frame, (x+32, y+18))
    draw.text((x+32, y+289), cut["name"], font=font, fill="#203f36")
    detail = "SMOOTH" if cut.get("geometry_mode", 0) > 0 else f"{cut['facet_count']} FACETS"
    draw.text((x+32, y+327), f"{cut['en']}  /  {detail}", font=small, fill="#75877d")
sheet.save(ART / "cut_catalog.png")
print(json.dumps(checks, indent=2))
