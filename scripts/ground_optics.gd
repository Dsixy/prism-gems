class_name PrismGroundOptics
extends Node3D

const PHOTON_SHADER = preload("res://shaders/caustic_photons.gdshader")
const SAMPLE_GRID: int = 56
var material: ShaderMaterial
var floor_material: ShaderMaterial
var photons: MeshInstance3D
var shadow_cloud := PackedVector3Array()
var shadow_softness: float = 0.65
var shadow_enabled: bool = true
var _last_pose := Transform3D()
var _last_angle: float = -1000.0


func setup(floor_shader: ShaderMaterial) -> void:
	floor_material = floor_shader
	material = ShaderMaterial.new()
	material.shader = PHOTON_SHADER
	material.render_priority = 2
	photons = MeshInstance3D.new()
	photons.name = "RefractedGroundPhotons"
	photons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	photons.custom_aabb = AABB(Vector3(-5, -0.1, -5), Vector3(10, 0.3, 10))
	photons.material_override = material
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var seeds := PackedVector2Array()
	var indices := PackedInt32Array()
	for band in range(3):
		for y in range(SAMPLE_GRID):
			for x in range(SAMPLE_GRID):
				var start: int = vertices.size()
				for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					vertices.append(Vector3(corner.x, band, corner.y))
					uv.append(corner)
					seeds.append(Vector2((float(x) + 0.5) / SAMPLE_GRID, (float(y) + 0.5) / SAMPLE_GRID))
				for i in [0, 1, 2, 0, 2, 3]:
					indices.append(start + i)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = seeds
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	photons.mesh = mesh
	add_child(photons)
	material.set_shader_parameter("seed_step", 1.0 / SAMPLE_GRID)


func configure(data: Dictionary, planes: PackedVector4Array, mode: int, axes: Vector3, center: Vector3) -> void:
	material.set_shader_parameter("facet_planes", planes)
	material.set_shader_parameter("facet_count", planes.size())
	material.set_shader_parameter("geometry_mode", mode)
	material.set_shader_parameter("geometry_axes", axes)
	material.set_shader_parameter("geometry_center", center)
	var lo: Array = data["bounds_min"]
	var hi: Array = data["bounds_max"]
	var extent := Vector3(maxf(absf(lo[0]), absf(hi[0])), maxf(absf(lo[1]), absf(hi[1])), maxf(absf(lo[2]), absf(hi[2])))
	material.set_shader_parameter("zone_extent", extent)
	material.set_shader_parameter("source_radius", extent.length() * 1.05)
	shadow_cloud.clear()
	if mode == 0:
		for p in data["vertices"]:
			shadow_cloud.append(Vector3(p[0], p[1], p[2]))
	else:
		# Cached samples supply the silhouette; refraction still uses an exact
		# ellipsoid (or the same ellipsoid clipped by the cabochon base).
		for ring in range(13):
			var latitude: float = (0.0 if mode == 2 else -PI * 0.5) + (PI * 0.5 if mode == 2 else PI) * ring / 12.0
			for side in range(32):
				var angle: float = TAU * side / 32.0
				shadow_cloud.append(center + axes * Vector3(cos(latitude) * cos(angle), sin(latitude), cos(latitude) * sin(angle)))
	_last_angle = -1000.0


func update_ground(pose: Transform3D, angle: float, ior: float, fire: float, density: float, caustics: float, material_index: int) -> void:
	# Broad overhead studio source, sharing the user-controlled light azimuth.
	var light: Vector3 = Basis(Vector3.UP, -angle) * Vector3(-0.45, 1.60, 0.80).normalized()
	material.set_shader_parameter("gem_rotation", pose.basis)
	material.set_shader_parameter("gem_position", pose.origin)
	material.set_shader_parameter("light_direction", light)
	material.set_shader_parameter("refractive_index", ior)
	material.set_shader_parameter("dispersion", fire)
	material.set_shader_parameter("absorption", density)
	material.set_shader_parameter("strength", caustics)
	var transmission: float = 1.0
	var opacity: float = 0.50 + minf(density, 1.5) * 0.08
	if material_index in [6, 9]:
		transmission = 0.0
		opacity = 0.95
	elif material_index == 5:
		transmission = 0.35
	elif material_index == 7:
		transmission = 0.28
	elif material_index == 8:
		transmission = 0.45
	material.set_shader_parameter("material_transmission", transmission)
	photons.visible = caustics > 0.0 and transmission > 0.0
	floor_material.set_shader_parameter("shadow_opacity", opacity)
	floor_material.set_shader_parameter("shadow_softness", shadow_softness)
	floor_material.set_shader_parameter("shadow_enabled", 1.0 if shadow_enabled else 0.0)
	if pose == _last_pose and is_equal_approx(angle, _last_angle):
		return
	_last_pose = pose
	_last_angle = angle
	var projected := PackedVector2Array()
	for local in shadow_cloud:
		var world: Vector3 = pose * local
		projected.append(Vector2(world.x - world.y * light.x / light.y, world.z - world.y * light.z / light.y))
	var hull := Geometry2D.convex_hull(projected)
	var hull_center := Vector2.ZERO
	for p in hull:
		hull_center += p
	hull_center /= maxf(hull.size(), 1)
	var edges := PackedVector4Array()
	for i in range(hull.size() - 1):
		var a: Vector2 = hull[i]
		var b: Vector2 = hull[i + 1]
		var edge: Vector2 = b - a
		var normal := Vector2(edge.y, -edge.x).normalized()
		if normal.dot(hull_center - a) > 0.0:
			normal = -normal
		edges.append(Vector4(normal.x, normal.y, normal.dot(a), 0.0))
	assert(edges.size() <= 96, "Projected shadow exceeds plane capacity")
	floor_material.set_shader_parameter("shadow_planes", edges)
	floor_material.set_shader_parameter("shadow_count", edges.size())
