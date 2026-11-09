"""Actual GPU silhouette masks keep ground changes out of gem-only checks."""
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import binary_fill_holes, label


def gem_mask(capture_dir, cut, height=145):
    path = Path(capture_dir) / f"ground_mask_{cut}.png"
    if path.exists():
        return np.asarray(Image.open(path).convert("L"))[:height] > 127
    # Keep standalone material checks usable without first running ground QA.
    return None


def reference_mask(image):
    foreground = np.linalg.norm(image - image[0, 0], axis=2) > 25
    components, count = label(foreground)
    assert count > 0
    largest = np.bincount(components.ravel())[1:].argmax() + 1
    return binary_fill_holes(components == largest)
