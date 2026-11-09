"""Build linear transmittance tables from CIE CMFs, D65 and illuminant A.

The absorption curve is an artistic chromium-like model, NOT a measured stone.
Source CIE tables: pbrt-v4 src/pbrt/util/spectrum.cpp (Apache-2.0).
Run from any directory; no network or colour-science dependency required.
"""
from pathlib import Path
import json
import re
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools/spectral_data/pbrt_spectrum.cpp"
OUT = ROOT / "assets/materials"
OUT.mkdir(parents=True, exist_ok=True)
text = SOURCE.read_text(encoding="utf-8")


def table(name):
    body = re.search(r"const Float " + name + r"\[[^\]]*\]\s*=\s*\{(.*?)\};", text, re.S)[1]
    body = re.sub(r"//[^\n]*", "", body)
    return np.array([float(x) for x in re.findall(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", body)])


wl = table("CIE_lambda")
cmf = np.stack([table("CIE_X"), table("CIE_Y"), table("CIE_Z")], axis=1)
xyz_to_rgb = np.array([[3.2404542, -1.5371385, -0.4985314],
                       [-0.969266, 1.8760108, 0.041556],
                       [0.0556434, -0.2040259, 1.0572252]])
# Broad yellow absorption and violet absorption leave green and red windows.
sigma = (0.015 + 3.0 * np.exp(-0.5 * ((wl - 576) / 25.9) ** 2)
         + 2.19 * np.exp(-0.5 * ((wl - 441.6) / 20.0) ** 2)
         + 0.19 * np.exp(-0.5 * ((wl - 510) / 18) ** 2)
         + 0.14 * np.exp(-0.5 * ((wl - 680) / 60) ** 2))
width, max_path = 1024, 32.0
paths = np.linspace(0, max_path, width)
transmission = np.exp(-paths[:, None] * sigma[None, :])
rows, samples = [], {}
bradford = np.array([[0.8951, 0.2664, -0.1614],
                     [-0.7502, 1.7135, 0.0367], [0.0389, -0.0685, 1.0296]])
bradford_inverse = np.linalg.inv(bradford)
target_lms = np.einsum("ij,j->i", bradford, [0.95047, 1.0, 1.08883])
for label, name in [("daylight", "CIE_Illum_D6500"), ("warm", "CIE_Illum_A")]:
    pairs = table(name).reshape(-1, 2)
    spd = np.interp(wl, pairs[:, 0], pairs[:, 1], left=0, right=0)
    xyz = np.einsum("pw,w,wc->pc", transmission, spd, cmf)
    # Bradford chromatic adaptation preserves the spectral color-change effect
    # while exposing both illuminants to the same display white point.
    xyz /= xyz[0, 1]
    source_lms = np.einsum("ij,j->i", bradford, xyz[0])
    lms = np.einsum("ij,pj->pi", bradford, xyz)
    lms *= target_lms / source_lms
    adapted_xyz = np.einsum("ij,pj->pi", bradford_inverse, lms)
    rgb = np.einsum("pc,rc->pr", adapted_xyz, xyz_to_rgb)
    rgb = np.clip(rgb, 0, 1)
    rgba = np.concatenate([rgb, np.ones((width, 1))], axis=1).astype("<f4")
    rows.append(rgba)
    samples[label] = {str(p): rgb[round(p / max_path * (width - 1))].round(5).tolist()
                      for p in [1, 2, 3, 5, 8, 12]}
np.stack(rows).tofile(OUT / "alexandrite_transmittance.bin")
metadata = {"width": width, "height": 2, "format": "RGBA32F little-endian linear RGB",
            "max_path": max_path, "illuminants": ["CIE D65", "CIE A / 2856 K"],
            "samples": samples,
            "model": "Artistic chromium-like absorption; not measured alexandrite",
            "source": "https://github.com/mmp/pbrt-v4/blob/master/src/pbrt/util/spectrum.cpp"}
(OUT / "alexandrite_transmittance.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
print(json.dumps(samples, indent=2))
