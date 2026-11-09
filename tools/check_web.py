"""Exercise the real WebAssembly game in Chromium, including PNG downloads."""
from pathlib import Path
import argparse
import json
import sys
import numpy as np
from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("url", nargs="?", default="http://127.0.0.1:8765/")
parser.add_argument("--browser", default="msedge" if sys.platform == "win32" else "chromium")
args = parser.parse_args()
out = ROOT / "build/web_qa"
out.mkdir(parents=True, exist_ok=True)

with sync_playwright() as p:
    options = {"headless": True, "args": ["--enable-webgl", "--ignore-gpu-blocklist"]}
    if sys.platform == "win32":
        options["args"].append("--use-angle=d3d11")
    if args.browser != "chromium":
        options["channel"] = args.browser
    browser = p.chromium.launch(**options)
    page = browser.new_page(viewport={"width": 1440, "height": 1040}, device_scale_factor=1, accept_downloads=True)
    errors, console_errors = [], []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.on("console", lambda message: console_errors.append(message.text) if message.type == "error" or message.text.startswith(("ERROR:", "SCRIPT ERROR")) else None)
    page.goto(args.url, wait_until="domcontentloaded", timeout=60000)
    page.wait_for_function("document.documentElement.dataset.gameReady === 'true'", timeout=120000)
    page.wait_for_timeout(800)
    canvas = page.locator("#canvas")
    bounds = canvas.bounding_box()

    def click(x, y):
        page.mouse.click(bounds["x"] + x * bounds["width"] / 1280, bounds["y"] + y * bounds["height"] / 860)

    def shot(name):
        path = out / (name + ".png")
        canvas.screenshot(path=path)
        return np.asarray(Image.open(path).convert("RGB"), float)[105:617, 564:1076]

    def download(name):
        with page.expect_download(timeout=15000) as pending:
            page.keyboard.press("p")
        item = pending.value
        item.save_as(out / (name + ".png"))
        assert Image.open(out / (name + ".png")).size == (768, 768)
        return item.suggested_filename

    page.keyboard.press("Space")
    baseline = shot("baseline")
    click(820, 330)
    page.mouse.down()
    page.mouse.move(bounds["x"] + 900, bounds["y"] + 290, steps=12)
    page.mouse.up()
    page.wait_for_timeout(200)
    rotated = shot("rotated")
    drag_difference = float(np.abs(rotated - baseline).mean())
    assert drag_difference > 3, drag_difference
    page.keyboard.press("[")
    page.keyboard.press("1")
    page.keyboard.press("l")
    page.wait_for_timeout(250)
    saved = download("oval_warm_download")
    assert "prism_oval_uniform_warm_" in saved, saved
    material_names = ["uniform", "bicolor", "ametrine", "watermelon", "alexandrite", "opal", "pearl", "catseye", "moonstone", "black_opal"]
    materials = []
    for index, name in enumerate(material_names):
        click(170, 230)
        page.wait_for_timeout(120)
        click(165, 269 + index * 27)
        page.wait_for_timeout(250)
        page.keyboard.press("Escape")
        canvas.focus()
        pixels = shot("material_" + name)
        filename = download("download_" + name)
        assert f"_{name}_" in filename, (name, filename)
        assert pixels.std() > 8, (name, float(pixels.std()))
        materials.append({"material": name, "download": filename, "preview_std": float(pixels.std())})
    page.keyboard.press("r")
    page.screenshot(path=ROOT / "artifacts/web_preview.png", full_page=True)
    gpu = page.evaluate("""() => { const gl = document.querySelector('#canvas').getContext('webgl2'); const e = gl.getExtension('WEBGL_debug_renderer_info'); return {renderer:e ? gl.getParameter(e.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER), fragmentUniformVectors:gl.getParameter(gl.MAX_FRAGMENT_UNIFORM_VECTORS), vertexUniformVectors:gl.getParameter(gl.MAX_VERTEX_UNIFORM_VECTORS)}; }""")
    assert not errors and not console_errors, {"errors": errors, "console_errors": console_errors}
    report = {"passed": True, "url": args.url, "drag_difference": drag_difference,
              "keyboard_shape_palette_light_download": saved, "materials": materials,
              "png_size": [768, 768], "errors": errors, "console_errors": console_errors, "gpu": gpu}
    (ROOT / "artifacts/web_checks.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=True, indent=2))
    browser.close()
