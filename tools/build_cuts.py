"""Generate nine original Blender sources + GLBs + matching optical data."""
from pathlib import Path
import json
import sys
import argparse
import bpy

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from cut_geometry import CUTS, SOURCES, make_cut

OUT = ROOT / "assets" / "gem"
(OUT / "cuts").mkdir(parents=True, exist_ok=True)


def icon_svg(data):
    outline = data["outline"]
    extent = max(abs(p) for v in outline for p in v)
    def polygon(scale):
        return " ".join(f"{24+x/extent*19*scale:.2f},{24+z/extent*19*scale:.2f}" for x, z in outline)
    content = f'<polygon points="{polygon(1)}" fill="#e2eee5"/>'
    content += f'<polygon points="{polygon(1)}"/><polygon points="{polygon(.57)}"/>'
    if data["style"] == "阶梯式":
        content += f'<polygon points="{polygon(.78)}"/>'
    else:
        for x, z in outline[::2]:
            content += f'<path d="M{24+x/extent*19:.2f},{24+z/extent*19:.2f} 24,24"/>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 48 48"><g fill="none" stroke="#24624f" stroke-width="1.7" stroke-linejoin="round">{content}</g></svg>'


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
parser = argparse.ArgumentParser(description="Build all faceted cuts, or update selected cuts only")
parser.add_argument("--cuts", nargs="+", choices=[cut["id"] for cut in CUTS])
requested = parser.parse_args(args).cuts
catalog = []
for cut in CUTS:
    if requested is not None and cut["id"] not in requested:
        continue
    data = make_cut(cut)
    cut_id = cut["id"]
    base = OUT / "brilliant" if cut_id == "round" else OUT / "cuts" / cut_id
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    mesh = bpy.data.meshes.new("Prism_" + cut_id + "_Facets")
    mesh.from_pydata([(p[0], -p[2], p[1]) for p in data["vertices"]], [], data["faces"])
    mesh.update()
    obj = bpy.data.objects.new("Prism_" + cut_id, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for face in mesh.polygons:
        face.use_smooth = False
    mat = bpy.data.materials.new("GemSurface_" + cut_id)
    mat.diffuse_color = (.12, .76, .59, 1)
    mat.use_nodes = True
    mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (.12, .76, .59, 1)
    mat.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = .08
    obj.data.materials.append(mat)
    obj["cut_id"] = cut_id
    obj["facet_count"] = data["facet_count"]
    obj["cut_style"] = cut["style"]
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces.active.region_3d.view_distance = 4.5
    bpy.ops.wm.save_as_mainfile(filepath=str(base.with_suffix(".blend")))
    bpy.ops.export_scene.gltf(filepath=str(base.with_suffix(".glb")), export_format="GLB",
        use_selection=True, export_yup=True, export_normals=True,
        export_materials="EXPORT", export_cameras=False, export_lights=False)
    base.with_suffix(".json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    icon = OUT / "cuts" / (cut_id + ".svg")
    icon.write_text(icon_svg(data), encoding="utf-8")
    entry = dict(cut)
    entry.update({"model_path": "res://" + base.with_suffix(".glb").relative_to(ROOT).as_posix(),
                  "metadata_path": "res://" + base.with_suffix(".json").relative_to(ROOT).as_posix(),
                  "icon_path": "res://" + icon.relative_to(ROOT).as_posix(),
                  "facet_count": data["facet_count"]})
    catalog.append(entry)
    print(f'PRISM_CUT_OK: {cut_id} / {data["facet_count"]} facets', flush=True)

catalog_path = OUT / "cut_catalog.json"
previous = json.loads(catalog_path.read_text(encoding="utf-8")) if catalog_path.exists() else {}
updated = {c["id"]: c for c in catalog}
existing = {c["id"]: c for c in previous.get("cuts", [])}
existing.update(updated)
catalog = [existing[c["id"]] for c in CUTS if c["id"] in existing]
catalog.extend(c for c in previous.get("cuts", []) if c.get("geometry_mode", 0) > 0)
sources = dict(previous.get("sources", {}))
sources.update(SOURCES)
catalog_path.write_text(json.dumps({"version": 2, "cuts": catalog, "sources": sources}, ensure_ascii=False, indent=2), encoding="utf-8")
print("PRISM_CUT_LIBRARY_OK: " + str(len(catalog)), flush=True)
