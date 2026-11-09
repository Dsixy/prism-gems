"""Generate a deterministic, tileable 3D opal-domain parameter field.

RGB encodes domain orientation, A encodes relative layer spacing. No baked colors.
The shader computes color from these parameters and light/view directions.
"""
from pathlib import Path
import json
import numpy as np
from scipy.spatial import cKDTree

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/materials"
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(73129)
size, cells = 128, 8
grid = np.stack(np.meshgrid(*[np.arange(cells)] * 3, indexing="ij"), axis=-1).reshape(-1, 3)
seeds = (grid + rng.uniform(0.12, 0.88, grid.shape)) / cells
normals = rng.normal(size=(len(seeds), 3))
normals /= np.linalg.norm(normals, axis=1, keepdims=True)
params = np.column_stack([normals * 0.5 + 0.5, rng.uniform(0, 1, len(seeds))])
params = np.clip(np.round(params * 255), 0, 255).astype(np.uint8)
tree = cKDTree(seeds, boxsize=1.0)
axis = (np.arange(size) + 0.5) / size
yy, xx = np.meshgrid(axis, axis, indexing="ij")
volume = np.empty((size, size, size, 4), dtype=np.uint8)
order = np.empty((size, size, size), dtype=np.uint8)
for z in range(size):
    points = np.column_stack([xx.ravel(), yy.ravel(), np.full(size * size, axis[z])])
    distances, nearest = tree.query(points, k=2)
    volume[z] = params[nearest[:, 0]].reshape(size, size, 4)
    # A separate smoothly filtered boundary mask avoids interpolating unrelated
    # domain orientations into a rainbow fringe at each grain edge.
    edge = np.clip((distances[:, 1] - distances[:, 0]) / 0.018, 0, 1)
    order[z] = np.round(edge * edge * (3 - 2 * edge) * 255).astype(np.uint8).reshape(size, size)
volume.tofile(OUT / "opal_domains.bin")
order.tofile(OUT / "opal_domain_order.bin")
metadata = {"size": size, "format": "RGBA8, x-fastest, then y, then z",
            "domains_per_axis": cells, "seed": 73129,
            "rgb": "domain normal encoded as normal * 0.5 + 0.5",
            "alpha": "relative spacing; shader maps to 185-305 nm",
            "order_format": "R8, same dimensions; smoothly fading domain boundaries",
            "note": "Original procedural model, not a scan or a measured opal"}
(OUT / "opal_domains.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
print(f"Generated {size}^3 domain field: {volume.nbytes:,} bytes; {len(seeds)} unique domains")
