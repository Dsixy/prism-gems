"""Copy required notices beside a Godot Web export, without private build files."""
from pathlib import Path
import html
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "build/web"
out.mkdir(parents=True, exist_ok=True)
notices = []
for source in [*sorted((ROOT / "third_party").glob("*.txt")), ROOT / "assets/fonts/OFL.txt"]:
    target = out / source.name
    shutil.copy2(source, target)
    notices.append(f'<h2>{html.escape(source.name)}</h2><pre>{html.escape(source.read_text(encoding="utf-8"))}</pre>')
(out / "licenses.html").write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>PRISM · 第三方许可</title><style>body{max-width:960px;margin:40px auto;padding:0 24px;background:#f6f6ef;color:#203f36;font:15px/1.7 system-ui}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:12px/1.6 monospace}a{color:inherit}</style><a href="./">← 返回试玩</a><h1>PRISM · 第三方许可</h1>' + ''.join(notices), encoding="utf-8")
(out / ".nojekyll").touch()
print("Web distribution prepared:", sum(f.stat().st_size for f in out.iterdir() if f.is_file()), "bytes")
