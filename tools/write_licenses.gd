extends SceneTree

func _initialize() -> void:
	var text: String = "Godot Engine\n============\n\n" + Engine.get_license_text()
	text += "\n\nBundled third-party notices\n===========================\n\n"
	for component in Engine.get_copyright_info():
		text += str(component["name"]) + "\n"
		for part in component["parts"]:
			for copyright_line in part["copyright"]:
				text += str(copyright_line) + "\n"
			text += "License: " + str(part["license"]) + "\n\n"
	var licenses: Dictionary = Engine.get_license_info()
	for name in licenses:
		text += "\n" + str(name) + "\n" + str(licenses[name]) + "\n"
	var file := FileAccess.open("res://build/GODOT_LICENSES.txt", FileAccess.WRITE)
	file.store_string(text)
	print("PRISM_LICENSES_WRITTEN")
	quit()
