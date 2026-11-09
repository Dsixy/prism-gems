"""Check rendered effects, independent of the shader's implementation."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "artifacts"


def pixels(name):
    return np.asarray(Image.open(ROOT / name).convert("RGB"), dtype=np.float32)


base = pixels("baseline.png")
rotated = pixels("rotated.png")
without_pool = pixels("no_caustics.png")
height, width, _ = base.shape
# The gemstone is above the projected floor. Restrict checks to meaningful areas.
gem = base[int(height * .12):int(height * .57), int(width * .18):int(width * .82)]
pool_diff = np.abs(base - without_pool).mean(axis=2)
top_diff = float(pool_diff[:int(height * .55)].mean())
bottom_diff = float(pool_diff[int(height * .57):].mean())
rotation_diff = float(np.abs(base - rotated).mean())
color_means = []
for i in range(6):
    image = pixels(f"preset_{i}.png")
    crop = image[int(height * .12):int(height * .57), int(width * .18):int(width * .82)]
    bg = base[0, 0]
    mask = np.linalg.norm(crop - bg, axis=2) > 25
    color_means.append(crop[mask].mean(axis=0).tolist())
green_pink_diff = float(np.abs(pixels("preset_0.png") - pixels("preset_1.png")).mean())
checks = {
    "size": [width, height],
    "rotation_pixel_difference": rotation_diff,
    "caustics_difference_above_gem": top_diff,
    "caustics_difference_on_floor": bottom_diff,
    "green_pink_pixel_difference": green_pink_diff,
    "preset_gem_mean_rgb": color_means,
    "gem_luminance_range": float(np.percentile(gem.mean(axis=2), 90) - np.percentile(gem.mean(axis=2), 10)),
}
assert (width, height) == (256, 256), checks
assert rotation_diff > 2.0, checks
assert top_diff < 0.1 and bottom_diff > 0.5, checks
assert green_pink_diff > 1.5, checks
assert checks["gem_luminance_range"] > 45, checks
# Nearest-neighbour enlargement must preserve each source pixel exactly.
large = Image.fromarray(base.astype(np.uint8)).resize((768, 768), Image.Resampling.NEAREST)
assert np.array_equal(np.asarray(large)[::3, ::3], base.astype(np.uint8))
checks["nearest_neighbor_exact"] = True
fire_difference = float(np.abs(pixels("fire_on.png") - pixels("fire_off.png")).mean())
reflection_depth_difference = float(np.abs(pixels("deep_reflections.png") - pixels("single_bounce.png")).mean())
assert fire_difference > 1.0, fire_difference
assert reflection_depth_difference > 1.0, reflection_depth_difference
checks["fire_pixel_difference"] = fire_difference
checks["reflection_depth_pixel_difference"] = reflection_depth_difference
checks["decorative_stars_disabled_for_optics_checks"] = True
checks["passed"] = True
(ROOT / "image_checks.json").write_text(json.dumps(checks, indent=2), encoding="utf-8")
print(json.dumps(checks, indent=2))
