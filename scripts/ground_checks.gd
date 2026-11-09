extends RefCounted

var app: Control
var stage: PrismGemStage
var viewport: SubViewport
var directory: String


func capture(name: String) -> void:
	stage.update_pose()
	await app.get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(directory.path_join("ground_" + name + ".png"))


func pair(name: String) -> void:
	stage.set_caustics(1.0)
	await capture(name + "_on")
	stage.set_caustics(0.0)
	await capture(name + "_off")
	stage.set_caustics(1.0)


func gem_mask(name: String = "gem_mask") -> void:
	var mesh_nodes: Array[Node] = stage.model_root.find_children("*", "MeshInstance3D", true, false)
	var saved: Array = []
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	for node in mesh_nodes:
		saved.append(node.material_override)
		node.material_override = white
	var environment: Environment = stage.get_node("WorldEnvironment").environment
	var background: Color = environment.background_color
	environment.background_color = Color.BLACK
	stage.get_node("Floor").visible = false
	stage.set_caustics(0.0)
	await capture(name)
	for i in range(mesh_nodes.size()):
		mesh_nodes[i].material_override = saved[i]
	stage.get_node("Floor").visible = true
	environment.background_color = background
	stage.set_caustics(1.0)


func run(scene: Control) -> void:
	app = scene
	stage = app.get("stage") as PrismGemStage
	viewport = app.get("viewport") as SubViewport
	directory = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	stage.auto_rotate = false
	stage.animate = false
	stage.sparkle_enabled = false
	stage.clock_time = 1.42
	app.call("select_preset", 0)
	var report: Dictionary = {"passed": true, "combinations": [], "materials": [],
		"photons_per_band": PrismGroundOptics.SAMPLE_GRID * PrismGroundOptics.SAMPLE_GRID}
	for light_id in range(2):
		app.call("_select_light", light_id)
		for cut_id in range(stage.cut_catalog.size()):
			app.call("_on_cut_selected", cut_id)
			stage.set_top_view(false)
			stage.reset_view()
			var tag: String = "%s_%s" % [stage.current_cut_id, "day" if light_id == 0 else "warm"]
			await pair(tag)
			if light_id == 0:
				await gem_mask("mask_" + stage.current_cut_id)
			var valid: bool = stage.validate_exported_geometry()["passed"] and stage.ground_optics.shadow_cloud.size() > 0
			report["combinations"].append({"cut": stage.current_cut_id, "light": light_id, "passed": valid})
			report["passed"] = bool(report["passed"]) and valid
	for material_id in range(PrismGemStage.MATERIALS.size()):
		app.call("select_preset", 0)
		if material_id > 0:
			app.call("select_material", material_id)
		app.call("_select_light", 0)
		app.call("_on_cut_selected", 0)
		stage.reset_view()
		var entry: Dictionary = PrismGemStage.MATERIALS[material_id]
		await pair("material_" + str(entry["id"]))
		report["materials"].append({"id": entry["id"], "opaque": material_id in [PrismGemStage.PEARL_MATERIAL, PrismGemStage.BLACK_OPAL_MATERIAL]})
	app.call("select_preset", 0)
	app.call("_on_cut_selected", 0)
	stage.reset_view()
	await pair("hero")
	await gem_mask()
	for i in range(60):
		stage.yaw = 0.40 + TAU * i / 60.0
		await pair("turn_%03d" % i)
	stage.reset_view()
	for i in range(60):
		stage.light_angle = TAU * i / 60.0
		await pair("light_%03d" % i)
	stage.light_angle = 0.0
	stage.reset_view()
	stage.set_caustics(0.0)
	stage.ground_optics.shadow_enabled = false
	await capture("no_shadow")
	stage.ground_optics.shadow_enabled = true
	stage.ground_optics.shadow_softness = 0.0
	await capture("hard_shadow")
	stage.ground_optics.shadow_softness = 1.0
	await capture("soft_shadow")
	stage.ground_optics.shadow_softness = 0.65
	stage.light_angle = PI * 0.5
	await capture("shadow_light_90")
	stage.light_angle = 0.0
	stage.pitch = 0.46
	await capture("shadow_tilted")
	await gem_mask("mask_tilted")
	stage.set_caustics(0.0)
	stage.reset_view()
	app.call("select_preset", 4)
	stage.set_optics(2.42, 0.0, 0.98, 0.22)
	await pair("dispersion_0")
	stage.set_optics(2.42, 1.0, 0.98, 0.22)
	await pair("dispersion_1")
	stage.set_optics(1.01, 0.0, 0.98, 0.22)
	await pair("ior_neutral")
	stage.set_optics(2.42, 0.0, 0.98, 0.22)
	await pair("ior_diamond")
	app.call("select_preset", 0)
	stage.set_caustics(1.0)
	await capture("static_a")
	for frame in range(12):
		await app.get_tree().process_frame
	await capture("static_b")
	stage.set_caustics(0.5)
	await capture("half_strength")
	stage.set_caustics(1.0)
	var controls: Dictionary = app.get("sliders")
	(controls["shadow_softness"] as HSlider).value = 0.83
	app.call("_on_cut_selected", 7)
	report["softness_preserved"] = is_equal_approx(stage.ground_optics.shadow_softness, 0.83)
	(controls["shadow_softness"] as HSlider).value = 0.65
	app.call("_on_cut_selected", 0)
	stage.reset_view()
	stage.auto_rotate = true
	var timings: Array[float] = []
	for i in range(90):
		var started: int = Time.get_ticks_usec()
		await app.get_tree().process_frame
		await RenderingServer.frame_post_draw
		# Readback waits for GPU completion, so this includes rendering rather
		# than timing only the CPU submission of an asynchronous draw.
		viewport.get_texture().get_image()
		if i >= 15:
			timings.append((Time.get_ticks_usec() - started) / 1000.0)
	timings.sort()
	report["render_readback_ms_median"] = timings[timings.size() / 2]
	report["render_readback_ms_p95"] = timings[int(timings.size() * 0.95)]
	stage.auto_rotate = false
	stage.reset_view()
	await capture("final")
	await RenderingServer.frame_post_draw
	app.get_viewport().get_texture().get_image().save_png(directory.path_join("interface_ground.png"))
	var file := FileAccess.open(directory.path_join("ground_qa_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PRISM_GROUND_QA_COMPLETE: passed=", report["passed"], ", combinations=", report["combinations"].size(), ", render_readback_ms_median=", report["render_readback_ms_median"])
	app.get_tree().quit(0 if report["passed"] and report["softness_preserved"] else 1)
