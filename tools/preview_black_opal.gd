extends SceneTree

var app: Node

func _initialize() -> void:
	root.size = Vector2i(1280, 860)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	run.call_deferred()

func run() -> void:
	var stage := app.get("stage") as PrismGemStage
	var viewport := app.get("viewport") as SubViewport
	stage.animate = false
	stage.auto_rotate = false
	stage.clock_time = 1.42
	stage.set_process(false)
	stage.set_material(PrismGemStage.BLACK_OPAL_MATERIAL)
	stage.set_cut("pear")
	stage.reset_view()
	var directory := ProjectSettings.globalize_path("res://artifacts/black_opal_candidates")
	DirAccess.make_dir_recursive_absolute(directory)
	for i in range(12):
		var offset := Vector3(0.41, 0.57, 0.23) + Vector3(0.173, 0.079, 0.237) * float(i)
		stage.gem_material.set_shader_parameter("black_opal_pattern_offset", offset)
		stage.update_pose()
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(directory.path_join("%02d.png" % i))
	quit()
