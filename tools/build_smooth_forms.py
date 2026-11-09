"""Original Blender bead/cabochon meshes with matching analytic optical geometry."""
from pathlib import Path
import json
import math
import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/gem/cuts"
FORMS = [
    dict(id="sphere", name="圆珠", en="SPHERE", style="珠形", axes=[.92, .92, .92], center=[0, 0, 0], geometry_mode=1,
         description="光滑球面，适合珍珠光泽与晕彩"),
    dict(id="oval_bead", name="椭圆珠", en="OVAL BEAD", style="珠形", axes=[.78, .90, 1.13], center=[0, 0, 0], geometry_mode=1,
         description="完整椭球，可从各个角度观察圆润表面"),
    dict(id="oval_cabochon", name="椭圆弧面", en="OVAL CABOCHON", style="弧面", axes=[.93, 1.02, 1.24], center=[0, -.40, 0], geometry_mode=2,
         description="平底高弧面，适合猫眼亮带、月光和欧泊"),
]


def make_mesh(entry):
    segments, rings = 96, 48
    ax, ay, az = entry["axes"]
    cx, cy, cz = entry["center"]
    capped = entry["geometry_mode"] == 2
    angle = math.pi / 2 if capped else math.pi
    vertices = [(cx, cy + ay, cz)]
    ring_count = rings if capped else rings - 1
    for j in range(1, ring_count + 1):
        theta = angle * j / rings
        for i in range(segments):
            phi = math.tau * i / segments
            vertices.append((cx + ax * math.sin(theta) * math.cos(phi),
                             cy + ay * math.cos(theta), cz + az * math.sin(theta) * math.sin(phi)))
    faces = [(0, 1 + i, 1 + (i + 1) % segments) for i in range(segments)]
    for j in range(ring_count - 1):
        a, b = 1 + j * segments, 1 + (j + 1) * segments
        for i in range(segments):
            nxt = (i + 1) % segments
            faces.append((a + i, b + i, b + nxt, a + nxt))
    last = 1 + (ring_count - 1) * segments
    if capped:
        faces.append(tuple(last + i for i in reversed(range(segments))))
    else:
        bottom = len(vertices)
        vertices.append((cx, cy - ay, cz))
        faces.extend((last + i, bottom, last + (i + 1) % segments) for i in range(segments))
    mesh = bpy.data.meshes.new(entry["id"] + "_Smooth")
    mesh.from_pydata([(x, -z, y) for x, y, z in vertices], [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    assert all(e.is_manifold for e in bm.edges), entry["id"]
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    for poly in mesh.polygons:
        poly.use_smooth = not (capped and len(poly.vertices) == segments)
    outline = [[ax * math.cos(math.tau * i / 32), az * math.sin(math.tau * i / 32)] for i in range(32)]
    outline_planes = []
    for i, p in enumerate(outline):
        q = outline[(i + 1) % len(outline)]
        nx, nz = q[1] - p[1], p[0] - q[0]
        length = math.hypot(nx, nz)
        nx, nz = nx / length, nz / length
        outline_planes.append([nx, nz, nx * p[0] + nz * p[1]])
    data = dict(entry, facet_count=0, vertex_count=len(vertices), planes=[], facet_centres=[],
                vertices=vertices, faces=faces, outline=outline, outline_planes=outline_planes,
                bounds_min=[cx - ax, cy if capped else cy - ay, cz - az],
                bounds_max=[cx + ax, cy + ay, cz + az], footprint_axes=[ax, az],
                sources=["original_smooth_forms"], analytic_axes=entry["axes"], analytic_center=entry["center"])
    return mesh, data


catalog_path = ROOT / "assets/gem/cut_catalog.json"
catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
catalog["cuts"] = [c for c in catalog["cuts"] if c["id"] not in {f["id"] for f in FORMS}]
for entry in FORMS:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    mesh, data = make_mesh(entry)
    obj = bpy.data.objects.new("Prism_" + entry["id"], mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    obj["cut_id"] = entry["id"]
    obj["analytic_geometry"] = entry["geometry_mode"]
    material = bpy.data.materials.new("Polished_" + entry["id"])
    material.diffuse_color = (.88, .84, .73, 1)
    material.use_nodes = True
    node = material.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = material.diffuse_color
    node.inputs["Roughness"].default_value = .18
    mesh.materials.append(material)
    base = OUT / entry["id"]
    bpy.ops.wm.save_as_mainfile(filepath=str(base.with_suffix(".blend")))
    bpy.ops.export_scene.gltf(filepath=str(base.with_suffix(".glb")), export_format="GLB", use_selection=True,
                              export_yup=True, export_normals=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False)
    base.with_suffix(".json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    ratio = entry["axes"][0] / entry["axes"][2]
    icon = '<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 48 48">'
    icon += f'<ellipse cx="24" cy="24" rx="{19*ratio:.2f}" ry="19" fill="#e2eee5" stroke="#24624f" stroke-width="1.8"/>'
    icon += '<path d="M18 12 Q12 18 14 25" fill="none" stroke="#7eab94" stroke-width="2.3" stroke-linecap="round"/></svg>'
    base.with_suffix(".svg").write_text(icon, encoding="utf-8")
    catalog["cuts"].append({k: data[k] for k in ["id", "name", "en", "style", "description", "facet_count", "sources", "geometry_mode"]} |
                          {"model_path": "res://" + base.with_suffix(".glb").relative_to(ROOT).as_posix(),
                           "metadata_path": "res://" + base.with_suffix(".json").relative_to(ROOT).as_posix(),
                           "icon_path": "res://" + base.with_suffix(".svg").relative_to(ROOT).as_posix()})
    print("PRISM_SMOOTH_FORM_OK:", entry["id"], len(mesh.vertices), flush=True)
catalog["version"] = 2
catalog.setdefault("sources", {})["original_smooth_forms"] = {"title": "Original Blender ellipsoid and capped-ellipsoid models"}
catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8")
