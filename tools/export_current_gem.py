"""Export the active convex Blender mesh after manual edits.

In Blender's Scripting workspace, open this script and Run Script with the gem
selected. It exports a transform-baked GLB and matching Y-up optical planes.
The original object is preserved. Concave or non-planar cuts fail explicitly.
"""
from pathlib import Path
import json
import re
import sys
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "gem"
sys.path.insert(0, str(ROOT / "tools"))
from cut_geometry import footprint_data, MAX_FACETS
obj = bpy.context.view_layer.objects.active
if obj is None or obj.type != "MESH":
    raise ValueError("Select the convex gem mesh first.")
if obj.get("analytic_geometry", 0):
    raise ValueError("Smooth optical forms use analytic ellipsoids. Edit the axes/center in tools/build_smooth_forms.py and rebuild them.")
cut_id = str(obj.get("cut_id", "round"))
if re.fullmatch(r"[a-z][a-z0-9_]{0,31}", cut_id) is None:
    raise ValueError("Invalid cut_id custom property.")
base = OUT / "brilliant" if cut_id == "round" else OUT / "cuts" / cut_id
existing = json.loads(base.with_suffix(".json").read_text(encoding="utf-8")) if base.with_suffix(".json").exists() else {"id": cut_id, "name": "自定义切型", "en": "CUSTOM", "style": "自定义"}

mesh = obj.data.copy()
mesh.transform(obj.matrix_world)
bm = bmesh.new()
bm.from_mesh(mesh)
if not all(edge.is_manifold for edge in bm.edges):
    bm.free()
    bpy.data.meshes.remove(mesh)
    raise ValueError("The gem must be a closed manifold.")
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mesh)
bm.free()
mesh.update()


def godot(vector):
    return [float(vector.x), float(vector.z), float(-vector.y)]


vertices = [v.co.copy() for v in mesh.vertices]
centre = sum(vertices, Vector()) / len(vertices)
planes, centres, seen = [], [], set()
for polygon in mesh.polygons:
    n = polygon.normal.copy()
    c = sum((vertices[i] for i in polygon.vertices), Vector()) / len(polygon.vertices)
    if n.dot(c - centre) < 0:
        n = -n
    distance = n.dot(c)
    if any(abs(n.dot(vertices[i]) - distance) > 0.0001 for i in polygon.vertices):
        raise ValueError("Each facet must be planar. Flatten or triangulate the edited facet.")
    if any(n.dot(v) - distance > 0.0001 for v in vertices):
        raise ValueError("The optical shader requires a convex gem; a face bends inward.")
    plane = godot(n) + [float(distance)]
    key = tuple(round(x, 5) for x in plane)
    if key not in seen:
        seen.add(key)
        planes.append(plane)
        centres.append({"position": godot(c), "normal": godot(n)})
if len(planes) > MAX_FACETS:
    raise ValueError(f"The prototype supports at most {MAX_FACETS} distinct facet planes.")

selected = list(bpy.context.selected_objects)
clone = bpy.data.objects.new("Prism_Brilliant", mesh)
bpy.context.collection.objects.link(clone)
try:
    bpy.ops.object.select_all(action="DESELECT")
    clone.select_set(True)
    bpy.context.view_layer.objects.active = clone
    for polygon in mesh.polygons:
        polygon.use_smooth = False
    base.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(base.with_suffix(".glb")), export_format="GLB",
        use_selection=True, export_yup=True, export_normals=True,
        export_materials="EXPORT", export_cameras=False, export_lights=False)
    data = dict(existing)
    data.update({"facet_count": len(planes),
        "vertex_count": len(vertices), "planes": planes, "facet_centres": centres,
        "vertices": [godot(v) for v in vertices],
        "faces": [list(p.vertices) for p in mesh.polygons],
        "coordinate_system": "Godot Y-up; inside is dot(normal, position) <= distance"})
    data.update(footprint_data(data["vertices"]))
    base.with_suffix(".json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"PRISM_REEXPORT_OK: {cut_id} / {len(planes)} facets")
finally:
    bpy.data.objects.remove(clone, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    for original in selected:
        original.select_set(True)
    bpy.context.view_layer.objects.active = obj
