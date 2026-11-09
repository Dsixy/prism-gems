extends RefCounted

var app: Control
var stage: PrismGemStage
var viewport: SubViewport
var directory: String


func capture(name: String) -> void:
	stage.update_pose()
	await app.get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(directory.path_join("cutdetail_" + name + ".png"))


func run(scene: Control, before: bool = false) -> void:
	app = scene
	stage = app.get("stage") as PrismGemStage
	viewport = app.get("viewport") as SubViewport
	directory = ProjectSettings.globalize_path("res://artifacts/cut_refinement_before" if before else "res://artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	if before and FileAccess.file_exists(directory.path_join("cutdetail_qa_report.json")):
		push_error("Cut-detail baseline already exists; refusing to overwrite the archived comparison.")
		app.get_tree().quit(1)
		return
	stage.auto_rotate = false
	stage.animate = false
	stage.sparkle_enabled = false
	stage.clock_time = 1.42
	stage.set_caustics(0.0)
	var report: Dictionary = {"passed": true, "cuts": [], "materials": [], "before": before}
	for cut_id in ["pear", "oval"]:
		stage.set_cut(cut_id)
		stage.set_top_view(false)
		stage.reset_view()
		app.call("_select_light", 0)
		var geometry: Dictionary = stage.validate_exported_geometry()
		report["cuts"].append({"cut": cut_id, "geometry": geometry, "volume": stage.metadata["volume"],
			"bounds_min": stage.metadata["bounds_min"], "bounds_max": stage.metadata["bounds_max"]})
		report["passed"] = bool(report["passed"]) and bool(geometry["passed"])
		for preset in [1, 4]:
			app.call("select_preset", preset)
			var tag: String = cut_id + ("_pink" if preset == 1 else "_diamond")
			stage.set_top_view(true)
			await capture(tag + "_top")
			stage.set_top_view(false)
			stage.reset_view()
			await capture(tag + "_hero")
			for frame in range(60):
				stage.yaw = 0.40 + TAU * frame / 60.0
				await capture(tag + "_turn_%03d" % frame)
			stage.reset_view()
			stage.gem_material.set_shader_parameter("bounce_count", 1)
			await capture(tag + "_single_bounce")
			stage.gem_material.set_shader_parameter("bounce_count", 10)
			await capture(tag + "_deep_reflections")
			var fire: float = stage.current_dispersion
			stage.set_optics(stage.current_ior, 0.0, stage.current_brilliance, stage.current_absorption)
			await capture(tag + "_no_fire")
			stage.set_optics(stage.current_ior, fire, stage.current_brilliance, stage.current_absorption)
			await capture(tag + "_fire")
			app.call("_select_light", 1)
			await capture(tag + "_warm")
			app.call("_select_light", 0)
		app.call("select_preset", 1)
		stage.set_caustics(1.0)
		await capture(cut_id + "_ground")
		stage.set_caustics(0.0)
		for material_id in range(PrismGemStage.MATERIALS.size()):
			app.call("select_material", material_id)
			stage.set_cut(cut_id)
			stage.reset_view()
			for light_id in range(2):
				app.call("_select_light", light_id)
				var id: String = PrismGemStage.MATERIALS[material_id]["id"]
				await capture("%s_%s_%s" % [cut_id, id, "day" if light_id == 0 else "warm"])
				report["materials"].append({"cut": cut_id, "material": id, "light": light_id})
		app.call("select_preset", 1)
		app.call("_select_light", 0)
		stage.set_cut(cut_id)
		stage.reset_view()
		await capture(cut_id + "_static_a")
		for frame in range(12):
			await app.get_tree().process_frame
		await capture(cut_id + "_static_b")
		if not before:
			var times: Array[float] = []
			stage.auto_rotate = true
			stage.set_caustics(1.0)
			for frame in range(45):
				var started: int = Time.get_ticks_usec()
				await app.get_tree().process_frame
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image()
				if frame >= 10:
					times.append((Time.get_ticks_usec() - started) / 1000.0)
			times.sort()
			report[cut_id + "_render_readback_ms_median"] = times[times.size() / 2]
			report[cut_id + "_render_readback_ms_p95"] = times[int(times.size() * 0.95)]
			stage.auto_rotate = false
			stage.set_caustics(0.0)
	app.call("select_preset", 1)
	app.call("_select_light", 0)
	app.call("_on_cut_selected", 2)
	stage.reset_view()
	stage.set_caustics(1.0)
	await capture("final")
	await RenderingServer.frame_post_draw
	app.get_viewport().get_texture().get_image().save_png(directory.path_join("interface_cutdetail.png"))
	var file := FileAccess.open(directory.path_join("cutdetail_qa_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PRISM_CUT_DETAIL_QA_COMPLETE: before=", before, ", passed=", report["passed"])
	app.get_tree().quit(0 if report["passed"] else 1)
