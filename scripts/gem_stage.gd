class_name PrismGemStage
extends Node3D

const GEM_SHADER = preload("res://shaders/gem.gdshader")
const OUTLINE_SHADER = preload("res://shaders/outline.gdshader")
const GROUND_OPTICS = preload("res://scripts/ground_optics.gd")
const MAX_FACETS: int = 192
const OPAL_MATERIAL: int = 5
const PEARL_MATERIAL: int = 6
const CATSEYE_MATERIAL: int = 7
const MOONSTONE_MATERIAL: int = 8
const BLACK_OPAL_MATERIAL: int = 9
const MATERIALS: Array[Dictionary] = [
	{"id": "uniform", "name": "单色宝石", "en": "CLASSIC", "mode": 0},
	{"id": "bicolor", "name": "双色碧玺", "en": "BICOLOR", "mode": 1, "shape": 0,
		"a": Color("1bb786"), "b": Color("ec679f"), "ior": 1.64, "fire": 0.28, "density": 0.90},
	{"id": "ametrine", "name": "紫黄晶色带", "en": "AMETRINE", "mode": 1, "shape": 1,
		"a": Color("9560da"), "b": Color("f4bc52"), "ior": 1.55, "fire": 0.22, "density": 0.88},
	{"id": "watermelon", "name": "西瓜碧玺", "en": "WATERMELON", "mode": 1, "shape": 2,
		"a": Color("ed6291"), "b": Color("20b782"), "ior": 1.64, "fire": 0.25, "density": 1.0},
	{"id": "alexandrite", "name": "变石", "en": "ALEXANDRITE", "mode": 2,
		"a": Color("45a889"), "b": Color("b45f98"), "ior": 1.75, "fire": 0.25, "density": 0.74},
	{"id": "opal", "name": "水晶欧泊", "en": "CRYSTAL OPAL", "mode": 3,
		"a": Color("b9e3e6"), "b": Color("d777c4"), "ior": 1.45, "fire": 0.06, "density": 0.32},
	{"id": "pearl", "name": "珍珠", "en": "PEARL", "mode": 4, "recommended_form": "sphere",
		"a": Color("eee3cc"), "b": Color("e8cbdc"), "ior": 1.53, "fire": 0.0, "density": 1.0},
	{"id": "catseye", "name": "金绿猫眼", "en": "CAT'S EYE", "mode": 5, "recommended_form": "oval_cabochon",
		"a": Color("bd9342"), "b": Color("f4d58b"), "ior": 1.75, "fire": 0.10, "density": 0.86, "transparency": 0.48},
	{"id": "moonstone", "name": "月光石", "en": "MOONSTONE", "mode": 6, "recommended_form": "oval_cabochon",
		"a": Color("b7cbd9"), "b": Color("4a9bed"), "ior": 1.52, "fire": 0.18, "density": 0.45, "transparency": 0.70},
	{"id": "black_opal", "name": "黑欧泊", "en": "BLACK OPAL", "mode": 3, "opal_kind": 1, "recommended_form": "pear",
		"a": Color("23313c"), "b": Color("42a975"), "ior": 1.45, "fire": 0.0, "density": 1.60},
]

var gem_material: ShaderMaterial
var floor_material: ShaderMaterial
var ground_optics: PrismGroundOptics
var metadata: Dictionary
var cut_catalog: Array = []
var current_cut_id: String = "round"
var model_root: Node3D
var top_view: bool = false
var yaw: float = 0.40
var pitch: float = -0.08
var clock_time: float = 0.0
var auto_rotate: bool = true
var animate: bool = true
var spin_speed: float = 0.27
var sparkle_enabled: bool = true
var current_tint: Color = Color("31c397")
var current_ior: float = 1.85
var current_dispersion: float = 0.48
var current_brilliance: float = 1.0
var current_caustic: float = 1.0
var current_absorption: float = 0.70
var light_angle: float = 0.0
var planes: PackedVector4Array
var material_index: int = 0
var illuminant: int = 0
var zone_position: float = 0.0
var zone_width: float = 0.10
var zone_angle: float = 0.0
var current_zone_a: Color = Color("1bb786")
var current_zone_b: Color = Color("ec679f")
var spectral_texture: ImageTexture
var spectral_image: Image
var spectral_max_path: float = 32.0
var opal_texture: ImageTexture3D
var black_opal_texture: ImageTexture3D
var opal_order_texture: ImageTexture3D
var opal_profiles: Dictionary = {
	OPAL_MATERIAL: Vector3(0.55, 1.15, 0.22),
	BLACK_OPAL_MATERIAL: Vector3(0.78, 1.10, 0.35),
}
var opal_patch_size: float = 0.55
var opal_strength: float = 1.15
var opal_haze: float = 0.22
var pearl_luster: float = 0.72
var pearl_orient: float = 0.45
var eye_strength: float = 1.0
var eye_width: float = 0.055
var eye_axis: float = 0.0
var moon_strength: float = 1.0
var moon_spread: float = 0.78
var moon_depth: float = 0.55
var moon_rainbow: float = 0.85
var current_facet_transparency: float = 0.70
var geometry_mode: int = 0
var analytic_axes: Vector3 = Vector3.ONE
var analytic_center: Vector3 = Vector3.ZERO

@onready var pivot: Node3D = $GemPivot
@onready var camera: Camera3D = $Camera


func _ready() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/gem/cut_catalog.json"))
	cut_catalog = catalog["cuts"]
	gem_material = ShaderMaterial.new()
	gem_material.shader = GEM_SHADER
	floor_material = ($Floor as MeshInstance3D).material_override.duplicate() as ShaderMaterial
	($Floor as MeshInstance3D).material_override = floor_material
	ground_optics = GROUND_OPTICS.new()
	add_child(ground_optics)
	ground_optics.setup(floor_material)
	_load_spectral_data()
	_load_opal_data()
	set_top_view(false)
	set_cut("round")
	set_tint(current_tint)
	set_optics(current_ior, current_dispersion, current_brilliance, current_absorption)
	set_caustics(current_caustic)
	set_material(0)
	set_illuminant(0)
	set_opal(opal_patch_size, opal_strength, opal_haze)
	set_soft_effects()
	update_pose()


func set_cut(cut_id: String) -> bool:
	var entry: Dictionary = {}
	for cut in cut_catalog:
		if cut["id"] == cut_id:
			entry = cut
			break
	if entry.is_empty():
		return false
	var next_metadata = JSON.parse_string(FileAccess.get_file_as_string(entry["metadata_path"]))
	var next_scene := load(str(entry["model_path"])) as PackedScene
	if not next_metadata is Dictionary or next_scene == null:
		push_error("Could not load cut: " + cut_id)
		return false
	var next_planes := PackedVector4Array()
	for row in next_metadata["planes"]:
		next_planes.append(Vector4(float(row[0]), float(row[1]), float(row[2]), float(row[3])))
	if (next_planes.is_empty() and int(next_metadata.get("geometry_mode", 0)) == 0) or next_planes.size() > MAX_FACETS:
		push_error("Invalid facet count: " + cut_id)
		return false
	if next_metadata["outline_planes"].size() > 32:
		push_error("Invalid silhouette: " + cut_id)
		return false
	if is_instance_valid(model_root):
		pivot.remove_child(model_root)
		model_root.queue_free()
	metadata = next_metadata
	geometry_mode = int(metadata.get("geometry_mode", 0))
	analytic_axes = Vector3.ONE
	analytic_center = Vector3.ZERO
	if geometry_mode > 0:
		var shape_axes: Array = metadata["analytic_axes"]
		var shape_center: Array = metadata["analytic_center"]
		analytic_axes = Vector3(shape_axes[0], shape_axes[1], shape_axes[2])
		analytic_center = Vector3(shape_center[0], shape_center[1], shape_center[2])
	gem_material.set_shader_parameter("geometry_mode", geometry_mode)
	gem_material.set_shader_parameter("geometry_axes", analytic_axes)
	gem_material.set_shader_parameter("geometry_center", analytic_center)
	planes = next_planes
	current_cut_id = cut_id
	model_root = next_scene.instantiate() as Node3D
	pivot.add_child(model_root)
	_assign_mesh_materials(model_root)
	gem_material.set_shader_parameter("facet_planes", planes)
	gem_material.set_shader_parameter("facet_count", planes.size())
	ground_optics.configure(metadata, planes, geometry_mode, analytic_axes, analytic_center)
	var axes: Array = metadata["footprint_axes"]
	floor_material.set_shader_parameter("footprint_axes", Vector2(float(axes[0]), float(axes[1])))
	# Growth zones scale with the cut, and stay fixed in the gemstone's coordinates.
	var lo: Array = metadata["bounds_min"]
	var hi: Array = metadata["bounds_max"]
	gem_material.set_shader_parameter("zone_extent", Vector3(
		maxf(absf(float(lo[0])), absf(float(hi[0]))),
		maxf(absf(float(lo[1])), absf(float(hi[1]))),
		maxf(absf(float(lo[2])), absf(float(hi[2])))))
	_place_camera()
	update_pose()
	return true


func set_top_view(enabled: bool) -> void:
	top_view = enabled
	if top_view:
		yaw = 0.0
		pitch = 0.0
	_place_camera()


func _place_camera() -> void:
	if top_view:
		camera.position = Vector3(0.0, 8.1, 0.001)
		camera.look_at(Vector3(0.0, 1.28, 0.0), Vector3(0, 0, -1))
	elif geometry_mode > 0:
		camera.position = Vector3(0.0, 5.5, 6.2)
		camera.look_at(Vector3(0.0, 1.05, 0.0), Vector3.UP)
	else:
		camera.position = Vector3(0.0, 3.4, 6.3)
		camera.look_at(Vector3(0.0, 0.66, 0.0), Vector3.UP)


func _assign_mesh_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.material_override = gem_material
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var outline := MeshInstance3D.new()
		outline.name = "PixelSilhouette"
		outline.mesh = mesh_node.mesh
		outline.scale = Vector3.ONE * 1.012
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var outline_material := ShaderMaterial.new()
		outline_material.shader = OUTLINE_SHADER
		outline.material_override = outline_material
		mesh_node.add_child(outline)
		return
	for child in node.get_children():
		_assign_mesh_materials(child)


func _process(delta: float) -> void:
	if animate:
		clock_time += delta
	if auto_rotate:
		yaw += delta * spin_speed
	update_pose()


func update_pose() -> void:
	pivot.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	pivot.position.y = 1.28 + sin(clock_time * 1.15) * 0.035
	gem_material.set_shader_parameter("camera_position_local", pivot.to_local(camera.global_position))
	gem_material.set_shader_parameter("object_rotation", pivot.global_basis)
	gem_material.set_shader_parameter("light_rotation", light_angle)
	if material_index >= OPAL_MATERIAL:
		var lighting_basis := Basis(Vector3.UP, -light_angle)
		var inverse_pose: Basis = pivot.global_basis.inverse()
		gem_material.set_shader_parameter("opal_key_local", inverse_pose * lighting_basis * Vector3(-0.45, 0.68, 1.0).normalized())
		gem_material.set_shader_parameter("opal_fill_local", inverse_pose * lighting_basis * Vector3(1.6, 0.7, -0.5).normalized())
		gem_material.set_shader_parameter("key_light_local", inverse_pose * lighting_basis * Vector3(-0.45, 0.68, 1.0).normalized())
		gem_material.set_shader_parameter("fill_light_local", inverse_pose * lighting_basis * Vector3(1.6, 0.7, -0.5).normalized())
	floor_material.set_shader_parameter("gem_height", pivot.position.y)
	ground_optics.update_ground(pivot.global_transform, light_angle, current_ior, current_dispersion, current_absorption, current_caustic, material_index)


func set_tint(value: Color) -> void:
	current_tint = value
	gem_material.set_shader_parameter("body_tint", value)
	_refresh_floor_colors()


func _load_spectral_data() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/materials/alexandrite_transmittance.json"))
	var data := FileAccess.get_file_as_bytes("res://assets/materials/alexandrite_transmittance.bin")
	var width: int = int(info["width"])
	assert(data.size() == width * 2 * 16, "Invalid spectral transmittance data")
	spectral_max_path = float(info["max_path"])
	spectral_image = Image.create_from_data(width, 2, false, Image.FORMAT_RGBAF, data)
	spectral_texture = ImageTexture.create_from_image(spectral_image)
	gem_material.set_shader_parameter("alex_transmittance", spectral_texture)
	gem_material.set_shader_parameter("alex_max_path", spectral_max_path)


func set_material(index: int) -> void:
	material_index = clampi(index, 0, MATERIALS.size() - 1)
	var entry: Dictionary = MATERIALS[material_index]
	gem_material.set_shader_parameter("material_mode", int(entry["mode"]))
	gem_material.set_shader_parameter("opal_kind", int(entry.get("opal_kind", 0)))
	if material_index > 0:
		gem_material.set_shader_parameter("zone_shape", int(entry.get("shape", 0)))
		set_zone_colors(entry["a"], entry["b"])
		set_tint(entry["a"])
		set_optics(float(entry["ior"]), float(entry["fire"]), 1.0, float(entry["density"]))
		set_facet_transparency(float(entry.get("transparency", current_facet_transparency)))
	if is_opal():
		var settings: Vector3 = opal_profiles[material_index]
		set_opal(settings.x, settings.y, settings.z)
	set_zones(zone_position, zone_width, zone_angle)
	_refresh_floor_colors()
	update_pose()


func _load_opal_data() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/materials/opal_domains.json"))
	var width: int = int(info["size"])
	var bytes := FileAccess.get_file_as_bytes("res://assets/materials/opal_domains.bin")
	var slice_size: int = width * width * 4
	assert(bytes.size() == slice_size * width, "Invalid opal domain volume")
	var slices: Array[Image] = []
	for z in range(width):
		slices.append(Image.create_from_data(width, width, false, Image.FORMAT_RGBA8,
			bytes.slice(z * slice_size, (z + 1) * slice_size)))
	opal_texture = ImageTexture3D.new()
	var result: Error = opal_texture.create(Image.FORMAT_RGBA8, width, width, width, false, slices)
	assert(result == OK, "Could not upload opal domain volume")
	gem_material.set_shader_parameter("opal_domains", opal_texture)
	# Use a separate GPU texture so its nearest filtering cannot alter the
	# crystal-opal sampler on Compatibility renderers.
	black_opal_texture = ImageTexture3D.new()
	result = black_opal_texture.create(Image.FORMAT_RGBA8, width, width, width, false, slices)
	assert(result == OK, "Could not upload coherent opal domains")
	gem_material.set_shader_parameter("black_opal_domains", black_opal_texture)
	var order_bytes := FileAccess.get_file_as_bytes("res://assets/materials/opal_domain_order.bin")
	var order_slice: int = width * width
	assert(order_bytes.size() == order_slice * width, "Invalid opal boundary volume")
	var order_slices: Array[Image] = []
	for z in range(width):
		order_slices.append(Image.create_from_data(width, width, false, Image.FORMAT_R8,
			order_bytes.slice(z * order_slice, (z + 1) * order_slice)))
	opal_order_texture = ImageTexture3D.new()
	result = opal_order_texture.create(Image.FORMAT_R8, width, width, width, false, order_slices)
	assert(result == OK, "Could not upload opal domain boundaries")
	gem_material.set_shader_parameter("opal_domain_order", opal_order_texture)


func set_opal(patch_size: float, strength: float, haze: float) -> void:
	opal_patch_size = clampf(patch_size, 0.0, 1.0)
	opal_strength = clampf(strength, 0.0, 2.0)
	opal_haze = clampf(haze, 0.0, 1.0)
	if is_opal():
		opal_profiles[material_index] = Vector3(opal_patch_size, opal_strength, opal_haze)
	gem_material.set_shader_parameter("opal_patch_size", opal_patch_size)
	gem_material.set_shader_parameter("opal_strength", opal_strength)
	gem_material.set_shader_parameter("opal_haze", opal_haze)


func is_opal() -> bool:
	return material_index in [OPAL_MATERIAL, BLACK_OPAL_MATERIAL]


func is_soft_material() -> bool:
	return int(MATERIALS[material_index]["mode"]) >= 4


func supports_decorative_sparkles() -> bool:
	return not is_soft_material() and material_index != BLACK_OPAL_MATERIAL


func set_soft_effects() -> void:
	gem_material.set_shader_parameter("pearl_luster", pearl_luster)
	gem_material.set_shader_parameter("pearl_orient", pearl_orient)
	gem_material.set_shader_parameter("eye_strength", eye_strength)
	gem_material.set_shader_parameter("eye_width", eye_width)
	gem_material.set_shader_parameter("eye_axis", Vector3(cos(eye_axis), 0.0, sin(eye_axis)))
	gem_material.set_shader_parameter("moon_strength", moon_strength)
	gem_material.set_shader_parameter("moon_spread", moon_spread)
	gem_material.set_shader_parameter("moon_depth", moon_depth)
	gem_material.set_shader_parameter("moon_rainbow", moon_rainbow)


func set_facet_transparency(value: float) -> void:
	current_facet_transparency = clampf(value, 0.0, 1.0)
	gem_material.set_shader_parameter("facet_transparency", current_facet_transparency)


func set_zone_colors(a: Color, b: Color) -> void:
	current_zone_a = a
	current_zone_b = b
	gem_material.set_shader_parameter("zone_color_a", a)
	gem_material.set_shader_parameter("zone_color_b", b)
	_refresh_floor_colors()


func set_zones(position_value: float, width_value: float, angle_value: float) -> void:
	zone_position = position_value
	zone_width = width_value
	zone_angle = angle_value
	gem_material.set_shader_parameter("zone_offset", zone_position)
	gem_material.set_shader_parameter("zone_softness", zone_width)
	gem_material.set_shader_parameter("zone_axis", Vector3(cos(zone_angle), 0.0, sin(zone_angle)))
	ground_optics.material.set_shader_parameter("zone_axis", Vector3(cos(zone_angle), 0.0, sin(zone_angle)))
	ground_optics.material.set_shader_parameter("zone_offset", zone_position)
	ground_optics.material.set_shader_parameter("zone_softness", zone_width)


func set_illuminant(index: int) -> void:
	illuminant = clampi(index, 0, 1)
	# The spectral table is Bradford-adapted; this mild lamp cast also lights the
	# achromatic surface reflections and the surrounding floor consistently.
	var light_tint := Vector3(1.0, 1.0, 1.0) if illuminant == 0 else Vector3(1.04, 0.96, 0.90)
	gem_material.set_shader_parameter("illuminant_tint", light_tint)
	gem_material.set_shader_parameter("illuminant_row", 0.25 if illuminant == 0 else 0.75)
	floor_material.set_shader_parameter("illuminant_tint", light_tint)
	ground_optics.material.set_shader_parameter("illuminant_tint", light_tint)
	_refresh_floor_colors()


func _refresh_floor_colors() -> void:
	var primary: Color = current_tint
	var secondary: Color = current_tint
	if material_index > 0:
		primary = current_zone_a
		secondary = current_zone_b
	if is_soft_material():
		primary = current_tint
	if material_index == 4 and spectral_image != null:
		# Representative transmitted color, not a traced ground caustic.
		var sample_x: int = roundi(1.65 / spectral_max_path * float(spectral_image.get_width() - 1))
		var transmitted: Color = spectral_image.get_pixel(sample_x, illuminant)
		var peak: float = maxf(transmitted.r, maxf(transmitted.g, transmitted.b))
		primary = Color(transmitted.r / peak, transmitted.g / peak, transmitted.b / peak).linear_to_srgb()
		secondary = primary
	ground_optics.material.set_shader_parameter("gem_color", primary)
	ground_optics.material.set_shader_parameter("secondary_color", secondary)
	ground_optics.material.set_shader_parameter("material_mode", int(MATERIALS[material_index]["mode"]))
	ground_optics.material.set_shader_parameter("zone_shape", int(MATERIALS[material_index].get("shape", 0)))


func set_optics(index: float, fire: float, shine: float, density: float = 0.70) -> void:
	current_ior = index
	current_dispersion = fire
	current_brilliance = shine
	current_absorption = density
	gem_material.set_shader_parameter("refractive_index", index)
	gem_material.set_shader_parameter("dispersion", fire)
	gem_material.set_shader_parameter("brilliance", shine)
	gem_material.set_shader_parameter("absorption", density)


func set_caustics(value: float) -> void:
	current_caustic = value


func orbit(relative: Vector2) -> void:
	yaw += relative.x * 0.008
	pitch = clampf(pitch + relative.y * 0.006, -0.85, 0.85)
	update_pose()


func zoom_by(factor: float) -> void:
	camera.fov = clampf(camera.fov * factor, 22.0, 43.0)


func reset_view() -> void:
	yaw = 0.0 if top_view else 0.40
	pitch = 0.0 if top_view else -0.08
	camera.fov = 30.5
	update_pose()


func projected_sparkles() -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not sparkle_enabled or current_brilliance < 0.05 or not supports_decorative_sparkles():
		return result
	var rows: Array = metadata["facet_centres"]
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var p: Array = row["position"]
		if float(p[1]) < 0.05:
			continue
		var n: Array = row["normal"]
		var normal_world: Vector3 = pivot.global_basis * Vector3(n[0], n[1], n[2])
		if normal_world.dot(camera.global_basis.z) < 0.32:
			continue
		var phase: float = fposmod(clock_time + float(i) * 0.719, 4.4)
		if phase > 0.32:
			continue
		var world: Vector3 = pivot.to_global(Vector3(p[0], p[1], p[2]))
		var screen_point: Vector2 = camera.unproject_position(world)
		var life: float = sin(phase / 0.32 * PI)
		result.append(Vector3(roundf(screen_point.x), roundf(screen_point.y), life))
		if result.size() >= 2:
			break
	return result


func validate_exported_geometry() -> Dictionary:
	# Integration check: imported GLB positions must agree with the JSON halfspaces.
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(pivot, meshes)
	var max_error: float = 0.0
	var surface_error: float = 0.0
	var checked: int = 0
	for instance in meshes:
		if instance.name == "PixelSilhouette":
			continue
		for surface in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v in vertices:
				if geometry_mode > 0:
					var q: Vector3 = (v - analytic_center) / analytic_axes
					var quadric_error: float = q.length_squared() - 1.0
					max_error = maxf(max_error, quadric_error)
					var contact_error: float = absf(quadric_error)
					if geometry_mode == 2:
						max_error = maxf(max_error, analytic_center.y - v.y)
						contact_error = minf(contact_error, absf(v.y - analytic_center.y))
					surface_error = maxf(surface_error, contact_error)
				for plane in planes:
					max_error = maxf(max_error, Vector3(plane.x, plane.y, plane.z).dot(v) - plane.w)
				checked += 1
	return {"passed": max_error < 0.0001 and surface_error < 0.0001 and checked > 0, "maximum_plane_error": max_error,
		"maximum_surface_error": surface_error, "geometry_mode": geometry_mode,
		"imported_vertices_checked": checked, "facet_count": planes.size()}


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, result)
