"""Build a small, renamed OFL font for the game's web UI (fonttools required)."""
from pathlib import Path
import argparse
import json
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("source", nargs="?", type=Path, default=ROOT / "build/font_source/NotoSansSC-Regular.otf")
args = parser.parse_args()
text = "".join(p.read_text(encoding="utf-8") for pattern in ["scripts/*.gd", "assets/gem/*.json", "assets/gem/cuts/*.json"] for p in ROOT.glob(pattern))
text += "颜色色相饱和度明度亮度透明确定取消复制粘贴拾取预设高级线性非线性红绿蓝下载网页浏览器全屏"
unicodes = sorted(set(map(ord, text)) | set(range(32, 127)) | {0x2190, 0x2191, 0x2192, 0x2193, 0x25B6, 0x23F8})
font = TTFont(args.source)
names = {1: "Prism UI SC", 2: "Regular", 3: "PrismUISubsetSC-Regular-1", 4: "Prism UI SC Regular", 6: "PrismUISubsetSC-Regular", 16: "Prism UI SC", 17: "Regular"}
for name in list(font["name"].names):
    if name.nameID in names:
        font["name"].setName(names[name.nameID], name.nameID, name.platformID, name.platEncID, name.langID)
options = subset.Options()
options.name_IDs = ["*"]
options.name_legacy = True
options.name_languages = ["*"]
options.notdef_outline = True
options.recommended_glyphs = True
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=unicodes)
subsetter.subset(font)
out = ROOT / "assets/fonts"
out.mkdir(parents=True, exist_ok=True)
font.save(out / "PrismUI-Regular.otf")
(out / "subset.json").write_text(json.dumps({"source": "NotoSansSC-Regular.otf, noto-cjk/Sans/SubsetOTF/SC", "license": "SIL Open Font License 1.1", "renamed_family": "Prism UI SC", "requested_codepoints": len(unicodes)}, indent=2) + "\n", encoding="utf-8")
print("Web font:", (out / "PrismUI-Regular.otf").stat().st_size, "bytes")
