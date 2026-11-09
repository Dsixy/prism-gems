extends Control

const STAGE_SCENE = preload("res://scenes/gem_stage.tscn")
const SPARKLES = preload("res://scripts/sparkles.gd")
const PRESETS: Array[Dictionary] = [
	{"name": "祖母绿", "en": "VERDANT", "color": Color("32cd9a"), "ior": 1.85, "fire": 0.62, "density": 1.02, "shine": 0.92},
	{"name": "粉钻", "en": "ROSE", "color": Color("f37baa"), "ior": 2.42, "fire": 0.82, "density": 1.15, "shine": 0.90},
	{"name": "蓝宝石", "en": "AZURE", "color": Color("537bf0"), "ior": 1.77, "fire": 0.58, "density": 0.90, "shine": 0.92},
	{"name": "紫水晶", "en": "VIOLET", "color": Color("bb75e9"), "ior": 1.65, "fire": 0.62, "density": 0.82, "shine": 0.92},
	{"name": "无色钻石", "en": "DIAMOND", "color": Color("e4edee"), "ior": 2.42, "fire": 0.90, "density": 0.22, "shine": 0.98},
	{"name": "琥珀金", "en": "HONEY", "color": Color("efb34e"), "ior": 1.70, "fire": 0.58, "density": 0.72, "shine": 0.92},
]
const INK = Color("203f36")
const MUTED = Color("849087")
const ACCENT = Color("1e6553")
const BORDER = Color("d9ded4")

var stage: PrismGemStage
var viewport: SubViewport
var preview: TextureRect
var left_panel: VBoxContainer
var right_panel: VBoxContainer
var material_name: Label
var specimen_name: Label
var specimen_color: Label
var status: Label
var rotation_button: Button
var material_buttons: Array[Button] = []
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var color_picker: ColorPickerButton
var resolution_picker: OptionButton
var cut_picker: OptionButton
var view_button: Button
var sparkle_toggle: CheckButton
var current_preset: int = 0
var dragging: bool = false
var was_rotating: bool = false
var updating_controls: bool = false
var pixel_resolution: int = 256
var toast_time: float = 0.0
var keyboard_hint: Label
var sidebar_scroll: ScrollContainer
var material_picker: OptionButton
var material_hint: Label
var palette_panel: VBoxContainer
var zone_panel: VBoxContainer
var density_panel: VBoxContainer
var light_buttons: Array[Button] = []
var light_description: Label
var zone_pickers: Array[ColorPickerButton] = []
var advanced_panel: VBoxContainer
var advanced_button: Button
var opal_panel: VBoxContainer
var soft_panel: VBoxContainer
var pearl_panel: VBoxContainer
var eye_panel: VBoxContainer
var moon_panel: VBoxContainer
var surface_color_picker: ColorPickerButton
var soft_fire_panel: VBoxContainer
var facet_details: VBoxContainer


func _ready() -> void:
	_build_theme()
	_build_scene()
	_build_interface()
	select_preset(1)
	_on_cut_selected(2)
	get_viewport().size_changed.connect(_layout)
	_layout()
	if OS.has_feature("web"):
		_notify_web_ready.call_deferred()
	if "--qa" in OS.get_cmdline_user_args():
		_run_visual_checks.call_deferred()
	elif "--qa-opal" in OS.get_cmdline_user_args():
		_run_opal_checks.call_deferred()
	elif "--qa-soft" in OS.get_cmdline_user_args():
		_run_soft_checks.call_deferred()
	elif "--qa-fire" in OS.get_cmdline_user_args():
		_run_fire_checks.call_deferred()
	elif "--qa-refinement" in OS.get_cmdline_user_args():
		_run_refinement_checks.call_deferred()
	elif "--qa-moon" in OS.get_cmdline_user_args():
		_run_moon_checks.call_deferred()
	elif "--qa-ground" in OS.get_cmdline_user_args():
		_run_ground_checks.call_deferred()
	elif "--qa-cut-detail" in OS.get_cmdline_user_args() or "--qa-cut-detail-before" in OS.get_cmdline_user_args():
		_run_cut_detail_checks.call_deferred()


func _build_theme() -> void:
	var design := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	design.default_font = load("res://assets/fonts/PrismUI-Regular.otf") if OS.has_feature("web") else font
	design.default_font_size = 15
	design.set_color("font_color", "Label", INK)
	design.set_color("font_color", "Button", INK)
	design.set_color("font_hover_color", "Button", ACCENT)
	design.set_color("font_pressed_color", "Button", Color("f5faf5"))
	design.set_color("font_focus_color", "Button", INK)
	design.set_stylebox("normal", "Button", _box(Color("f5f6ef"), BORDER, 7, 12))
	design.set_stylebox("hover", "Button", _box(Color("e4eee2"), Color("a2b9a5"), 7, 12))
	design.set_stylebox("pressed", "Button", _box(ACCENT, ACCENT, 7, 12))
	design.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color("5f9f88"), 7, 12, 2))
	design.set_stylebox("normal", "OptionButton", _box(Color("f5f6ef"), BORDER, 6, 10))
	design.set_stylebox("hover", "OptionButton", _box(Color("e4eee2"), BORDER, 6, 10))
	design.set_color("font_color", "OptionButton", INK)
	design.set_stylebox("slider", "HSlider", _box(Color("d9e1d5"), Color(0, 0, 0, 0), 3, 0))
	design.set_stylebox("grabber_area", "HSlider", _box(ACCENT, Color(0, 0, 0, 0), 3, 0))
	design.set_stylebox("grabber_area_highlight", "HSlider", _box(Color("3d9275"), Color(0, 0, 0, 0), 3, 0))
	theme = design


func _box(fill: Color, border: Color, radius: int, padding: int, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box


func _build_scene() -> void:
	viewport = SubViewport.new()
	viewport.name = "PixelViewport"
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	add_child(viewport)
	stage = STAGE_SCENE.instantiate() as PrismGemStage
	viewport.add_child(stage)
	var sparkles: Node2D = SPARKLES.new()
	sparkles.stage = stage
	viewport.add_child(sparkles)


func _label(text: String, font_size: int = 15, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _space(parent: Control, amount: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = amount
	parent.add_child(gap)


func _rule(parent: Control) -> void:
	var line := HSeparator.new()
	var rule := StyleBoxLine.new()
	rule.color = BORDER
	rule.thickness = 1
	line.add_theme_stylebox_override("separator", rule)
	line.custom_minimum_size.y = 1
	parent.add_child(line)


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.pressed.connect(callback)
	return button


func _build_interface() -> void:
	sidebar_scroll = ScrollContainer.new()
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sidebar_scroll)
	var sidebar_inset := MarginContainer.new()
	sidebar_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_inset.add_theme_constant_override("margin_right", 14)
	sidebar_scroll.add_child(sidebar_inset)
	left_panel = VBoxContainer.new()
	left_panel.add_theme_constant_override("separation", 5)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_inset.add_child(left_panel)
	left_panel.add_child(_label("P R I S M   /   0 1", 14, ACCENT))
	_space(left_panel, 9)
	left_panel.add_child(_label("光，藏在切面里。", 30))
	left_panel.add_child(_label("一颗可以把玩的像素宝石", 15, MUTED))
	_space(left_panel, 10)
	_rule(left_panel)
	_space(left_panel, 10)
	left_panel.add_child(_label("01   选择材质", 13, MUTED))
	material_picker = OptionButton.new()
	material_picker.custom_minimum_size.y = 38
	for entry in PrismGemStage.MATERIALS:
		material_picker.add_item(str(entry["name"]))
	material_picker.item_selected.connect(select_material)
	left_panel.add_child(material_picker)
	material_hint = _label("", 12, MUTED)
	material_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	material_hint.custom_minimum_size.y = 38
	left_panel.add_child(material_hint)
	palette_panel = VBoxContainer.new()
	palette_panel.add_theme_constant_override("separation", 5)
	left_panel.add_child(palette_panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	palette_panel.add_child(grid)
	for i in range(PRESETS.size()):
		var button := _button("●  " + str(PRESETS[i]["name"]), select_preset.bind(i))
		button.toggle_mode = true
		button.custom_minimum_size.y = 34
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", (PRESETS[i]["color"] as Color).darkened(0.28))
		grid.add_child(button)
		material_buttons.append(button)
	var custom_row := HBoxContainer.new()
	palette_panel.add_child(custom_row)
	var custom_label := _label("自选颜色", 14, MUTED)
	custom_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_row.add_child(custom_label)
	color_picker = ColorPickerButton.new()
	color_picker.custom_minimum_size = Vector2(68, 30)
	color_picker.edit_alpha = false
	color_picker.color_changed.connect(_on_custom_color)
	custom_row.add_child(color_picker)
	zone_panel = VBoxContainer.new()
	zone_panel.add_theme_constant_override("separation", 4)
	left_panel.add_child(zone_panel)
	var zone_colors := HBoxContainer.new()
	zone_panel.add_child(zone_colors)
	var color_label := _label("两侧颜色", 14)
	color_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone_colors.add_child(color_label)
	for i in range(2):
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(56, 30)
		picker.edit_alpha = false
		picker.color_changed.connect(_on_zone_color.bind(i))
		zone_colors.add_child(picker)
		zone_pickers.append(picker)
	_add_slider("zone_position", "色带位置 / 范围", -0.48, 0.48, 0.01, 0.0, zone_panel)
	_add_slider("zone_width", "交界柔和度", 0.02, 0.32, 0.01, 0.10, zone_panel)
	_add_slider("zone_angle", "色带方向", 0.0, 180.0, 1.0, 0.0, zone_panel)
	density_panel = VBoxContainer.new()
	density_panel.add_theme_constant_override("separation", 4)
	left_panel.add_child(density_panel)
	_add_slider("density", "颜色浓度", 0.35, 1.25, 0.01, 0.74, density_panel)
	opal_panel = VBoxContainer.new()
	opal_panel.add_theme_constant_override("separation", 4)
	left_panel.add_child(opal_panel)
	_add_slider("opal_size", "彩斑大小", 0.0, 1.0, 0.01, 0.55, opal_panel)
	_add_slider("opal_strength", "变彩亮度", 0.0, 2.0, 0.01, 1.15, opal_panel)
	_add_slider("opal_haze", "乳浊程度", 0.0, 1.0, 0.01, 0.22, opal_panel)
	_add_slider("opal_light", "灯光方向", 0.0, 360.0, 1.0, 0.0, opal_panel)
	soft_panel = VBoxContainer.new()
	soft_panel.add_theme_constant_override("separation", 4)
	left_panel.add_child(soft_panel)
	var surface_row := HBoxContainer.new()
	soft_panel.add_child(surface_row)
	var surface_label := _label("体色", 14)
	surface_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface_row.add_child(surface_label)
	surface_color_picker = ColorPickerButton.new()
	surface_color_picker.edit_alpha = false
	surface_color_picker.custom_minimum_size = Vector2(68, 30)
	surface_color_picker.color_changed.connect(_on_surface_color)
	surface_row.add_child(surface_color_picker)
	pearl_panel = VBoxContainer.new()
	pearl_panel.add_theme_constant_override("separation", 4)
	soft_panel.add_child(pearl_panel)
	_add_slider("pearl_luster", "珍珠光泽", 0.0, 1.0, 0.01, 0.72, pearl_panel)
	_add_slider("pearl_orient", "粉绿晕彩", 0.0, 1.0, 0.01, 0.45, pearl_panel)
	eye_panel = VBoxContainer.new()
	eye_panel.add_theme_constant_override("separation", 4)
	soft_panel.add_child(eye_panel)
	_add_slider("eye_strength", "眼线亮度", 0.0, 1.8, 0.01, 1.0, eye_panel)
	_add_slider("eye_width", "眼线宽度", 0.015, 0.15, 0.001, 0.055, eye_panel)
	_add_slider("eye_axis", "纤维方向", 0.0, 180.0, 1.0, 0.0, eye_panel)
	moon_panel = VBoxContainer.new()
	moon_panel.add_theme_constant_override("separation", 4)
	soft_panel.add_child(moon_panel)
	_add_slider("moon_strength", "月光亮度", 0.0, 1.8, 0.01, 1.0, moon_panel)
	_add_slider("moon_spread", "光晕范围", 0.0, 1.0, 0.01, 0.78, moon_panel)
	_add_slider("moon_rainbow", "彩虹晕彩", 0.0, 1.0, 0.01, 0.85, moon_panel)
	_add_slider("moon_depth", "浮光深度", 0.0, 1.0, 0.01, 0.55, moon_panel)
	soft_fire_panel = VBoxContainer.new()
	soft_fire_panel.add_theme_constant_override("separation", 4)
	soft_panel.add_child(soft_fire_panel)
	_add_slider("soft_fire", "刻面火彩", 0.0, 1.0, 0.01, 0.18, soft_fire_panel)
	_add_slider("soft_light", "灯光方向", 0.0, 360.0, 1.0, 0.0, soft_panel)
	_space(left_panel, 12)
	_rule(left_panel)
	_space(left_panel, 10)
	left_panel.add_child(_label("02   换一种光", 13, MUTED))
	var lights := HBoxContainer.new()
	lights.add_theme_constant_override("separation", 8)
	left_panel.add_child(lights)
	for i in range(2):
		var button := _button("日光" if i == 0 else "暖灯", _select_light.bind(i))
		button.toggle_mode = true
		button.custom_minimum_size.y = 38
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lights.add_child(button)
		light_buttons.append(button)
	light_description = _label("", 12, MUTED)
	light_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	light_description.custom_minimum_size.y = 32
	left_panel.add_child(light_description)
	advanced_button = _button("展开光效微调" if OS.has_feature("web") else "▸  光效微调", _toggle_advanced)
	advanced_button.custom_minimum_size.y = 34
	left_panel.add_child(advanced_button)
	advanced_panel = VBoxContainer.new()
	advanced_panel.add_theme_constant_override("separation", 5)
	advanced_panel.visible = false
	left_panel.add_child(advanced_panel)
	_add_slider("brilliance", "内部闪光", 0.0, 1.8, 0.01, 1.0, advanced_panel)
	_add_slider("dispersion", "彩色火彩", 0.0, 1.0, 0.01, 0.42, advanced_panel)
	_add_slider("caustics", "地面焦散", 0.0, 1.5, 0.01, 1.0, advanced_panel)
	_add_slider("shadow_softness", "阴影柔和度", 0.0, 1.0, 0.01, 0.65, advanced_panel)
	_add_slider("light", "灯光方向", 0.0, 360.0, 1.0, 0.0, advanced_panel)
	facet_details = VBoxContainer.new()
	facet_details.add_theme_constant_override("separation", 4)
	advanced_panel.add_child(facet_details)
	_add_slider("facet_transparency", "刻面通透度", 0.0, 1.0, 0.01, 0.70, facet_details)
	(sliders["dispersion"] as HSlider).tooltip_text = "调整色散产生的彩色火彩；0 保留白色反光和材质光晕。"
	(sliders["soft_fire"] as HSlider).tooltip_text = "与光效微调中的彩色火彩同步。高数值用于美术增强。"
	sparkle_toggle = CheckButton.new()
	sparkle_toggle.text = "十字星闪光"
	sparkle_toggle.button_pressed = true
	sparkle_toggle.add_theme_color_override("font_color", INK)
	sparkle_toggle.toggled.connect(func(value: bool) -> void: stage.sparkle_enabled = value)
	advanced_panel.add_child(sparkle_toggle)
	_space(left_panel, 9)
	_rule(left_panel)
	_space(left_panel, 8)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	left_panel.add_child(actions)
	rotation_button = _button("Ⅱ  暂停旋转", _toggle_rotation)
	rotation_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(rotation_button)
	var reset := _button("重置视角", _reset_view)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(reset)
	var export_button := _button("↓  保存当前宝石 PNG", _save_image)
	left_panel.add_child(export_button)
	status = _label("拖动宝石转一转，看看光的变化。", 12, MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 36
	left_panel.add_child(status)

	right_panel = VBoxContainer.new()
	right_panel.add_theme_constant_override("separation", 0)
	add_child(right_panel)
	var title_row := HBoxContainer.new()
	material_name = _label("VERDANT / 祖母绿", 15)
	material_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(material_name)
	cut_picker = OptionButton.new()
	cut_picker.name = "CutSelector"
	cut_picker.custom_minimum_size.x = 168
	cut_picker.fit_to_longest_item = false
	cut_picker.tooltip_text = "选择外形；材质、颜色和光效独立保留。"
	for i in range(stage.cut_catalog.size()):
		var cut: Dictionary = stage.cut_catalog[i]
		var icon := load(str(cut["icon_path"])) as Texture2D
		cut_picker.add_icon_item(icon, str(cut["name"]), i)
	cut_picker.item_selected.connect(_on_cut_selected)
	title_row.add_child(cut_picker)
	view_button = _button("俯视", _toggle_view)
	view_button.custom_minimum_size.y = 34
	view_button.tooltip_text = "切换俯视 / 斜视（T）"
	title_row.add_child(view_button)
	resolution_picker = OptionButton.new()
	for value in [192, 256, 320]:
		resolution_picker.add_item("%d px" % value, value)
	resolution_picker.select(1)
	resolution_picker.item_selected.connect(_on_resolution_changed)
	title_row.add_child(resolution_picker)
	right_panel.add_child(title_row)
	_space(right_panel, 14)
	preview = TextureRect.new()
	preview.name = "InteractiveGem"
	preview.texture = viewport.get_texture()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_default_cursor_shape = Control.CURSOR_DRAG
	preview.gui_input.connect(_on_preview_input)
	preview.resized.connect(queue_redraw)
	right_panel.add_child(preview)
	_space(right_panel, 17)
	var caption := HBoxContainer.new()
	var specimen := VBoxContainer.new()
	specimen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	specimen_name = _label("BRILLIANT / 圆形混合切", 13)
	specimen.add_child(specimen_name)
	specimen_color = _label("", 12, MUTED)
	specimen.add_child(specimen_color)
	caption.add_child(specimen)
	var edition := _label("PRISM COLLECTION\nFIRST LIGHT  /  VOL. 01", 11, MUTED)
	edition.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.add_child(edition)
	right_panel.add_child(caption)
	_space(right_panel, 16)
	_rule(right_panel)
	_space(right_panel, 12)
	keyboard_hint = _label("拖动旋转 · 滚轮缩放 · 空格暂停 · L 换光 · [ ] 换型 · T 俯视 · 1—6 单色 · R 复位", 12, MUTED)
	keyboard_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_panel.add_child(keyboard_hint)


func _add_slider(key: String, title: String, minimum: float, maximum: float, step: float, value: float, parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var name_label := _label(title, 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var number := _label("", 12, MUTED)
	row.add_child(number)
	parent.add_child(row)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.y = 18
	slider.value_changed.connect(_on_slider_changed.bind(key))
	parent.add_child(slider)
	sliders[key] = slider
	value_labels[key] = number
	_set_value_text(key, value)


func _set_value_text(key: String, value: float) -> void:
	(value_labels[key] as Label).text = ("%d°" % int(value)) if key in ["light", "zone_angle", "opal_light", "soft_light", "eye_axis"] else ("%d%%" % roundi(value * 100.0))


func select_preset(index: int) -> void:
	current_preset = index
	var preset: Dictionary = PRESETS[index]
	updating_controls = true
	stage.set_material(0)
	material_picker.select(0)
	stage.set_tint(preset["color"])
	stage.set_optics(float(preset["ior"]), float(preset["fire"]), float(preset["shine"]), float(preset["density"]))
	(sliders["brilliance"] as HSlider).value = float(preset["shine"])
	(sliders["dispersion"] as HSlider).value = float(preset["fire"])
	(sliders["soft_fire"] as HSlider).value = float(preset["fire"])
	color_picker.color = preset["color"]
	for i in range(material_buttons.size()):
		material_buttons[i].set_pressed_no_signal(i == index)
	material_name.text = str(preset["en"]) + "  /  " + str(preset["name"])
	_update_caption()
	_sync_material_panels()
	updating_controls = false


func select_material(index: int) -> void:
	if index == 0:
		select_preset(current_preset)
		return
	updating_controls = true
	var entry: Dictionary = PrismGemStage.MATERIALS[index]
	if entry.has("recommended_form") and stage.material_index != index:
		for i in range(stage.cut_catalog.size()):
			if stage.cut_catalog[i]["id"] == entry["recommended_form"]:
				stage.set_cut(str(entry["recommended_form"]))
				cut_picker.select(i)
				break
	stage.set_material(index)
	material_picker.select(index)
	material_name.text = str(entry["name"])
	(sliders["brilliance"] as HSlider).value = stage.current_brilliance
	(sliders["dispersion"] as HSlider).value = stage.current_dispersion
	(sliders["soft_fire"] as HSlider).value = stage.current_dispersion
	(sliders["facet_transparency"] as HSlider).value = stage.current_facet_transparency
	(sliders["density"] as HSlider).value = stage.current_absorption
	(sliders["opal_size"] as HSlider).value = stage.opal_patch_size
	(sliders["opal_strength"] as HSlider).value = stage.opal_strength
	(sliders["opal_haze"] as HSlider).value = stage.opal_haze
	zone_pickers[0].color = stage.current_zone_a
	zone_pickers[1].color = stage.current_zone_b
	surface_color_picker.color = stage.current_tint
	for button in material_buttons:
		button.set_pressed_no_signal(false)
	_sync_material_panels()
	_update_caption()
	updating_controls = false


func _sync_material_panels() -> void:
	var index: int = stage.material_index
	palette_panel.visible = index == 0
	zone_panel.visible = index in [1, 2, 3]
	density_panel.visible = index == 4
	opal_panel.visible = stage.is_opal()
	soft_panel.visible = stage.is_soft_material()
	pearl_panel.visible = index == PrismGemStage.PEARL_MATERIAL
	eye_panel.visible = index == PrismGemStage.CATSEYE_MATERIAL
	moon_panel.visible = index == PrismGemStage.MOONSTONE_MATERIAL
	var has_facet_optics: bool = index in [PrismGemStage.CATSEYE_MATERIAL, PrismGemStage.MOONSTONE_MATERIAL] and stage.geometry_mode == 0
	soft_fire_panel.visible = has_facet_optics
	facet_details.visible = has_facet_optics
	(sliders["dispersion"] as HSlider).editable = index < PrismGemStage.PEARL_MATERIAL or has_facet_optics
	sparkle_toggle.disabled = not stage.supports_decorative_sparkles()
	sparkle_toggle.tooltip_text = "此材质使用自身的表面高光与内部光效。" if sparkle_toggle.disabled else "附加的像素十字星"
	(sliders["zone_angle"] as HSlider).editable = index != 3
	material_hint.text = [
		"均匀的体色。选择配色或调出自己的颜色。",
		"绿与粉在晶体内相遇；旋转时，切面会映出另一侧的颜色。",
		"紫色与金色分区生长，内部反射让色带交叠。",
		"粉色核心、绿色外圈。试试俯视，观察层次。",
		"日光下偏蓝绿，暖灯下偏紫红；厚薄切面也会呈现不同深浅。",
		"彩斑藏在通透的体内。转动宝石或灯光，观察不同色块依次亮起。",
		"圆珠上的柔和光泽与粉绿晕彩。也可以换成椭圆珠。",
		"弧面把细密纤维的反光聚成一条亮带。转动灯光，看眼线滑动。",
		"宽而柔和的彩虹浮光藏在通透底体中，转动宝石或灯光，看光晕滑过切面。",
		"深色底体衬出连贯的大块彩斑，细闪随角度点亮。可切换水晶欧泊比较。",
	][index]
	if has_facet_optics:
		material_hint.text = "柔和彩虹光晕与内部反射叠加。彩虹晕彩设为 0 可看蓝白月光；刻面火彩单独调节。" if index == PrismGemStage.MOONSTONE_MATERIAL else "刻面火彩与猫眼亮带叠加；想看清晰眼线可换回弧面。"
	_select_light(stage.illuminant)


func _select_light(index: int) -> void:
	stage.set_illuminant(index)
	for i in range(light_buttons.size()):
		light_buttons[i].set_pressed_no_signal(i == index)
	light_description.text = "日光 · D65 / 约 6500 K" if index == 0 else "暖灯 · 白炽灯 / 约 2856 K"
	_update_caption()


func _on_zone_color(color: Color, side: int) -> void:
	if updating_controls:
		return
	if side == 0:
		stage.set_zone_colors(color, stage.current_zone_b)
	else:
		stage.set_zone_colors(stage.current_zone_a, color)
	_update_caption()


func _on_surface_color(color: Color) -> void:
	if updating_controls:
		return
	stage.set_tint(color)
	_update_caption()


func _toggle_advanced() -> void:
	advanced_panel.visible = not advanced_panel.visible
	if OS.has_feature("web"):
		advanced_button.text = "收起光效微调" if advanced_panel.visible else "展开光效微调"
	else:
		advanced_button.text = "▾  收起光效微调" if advanced_panel.visible else "▸  光效微调"


func _update_caption() -> void:
	specimen_name.text = str(stage.metadata.get("en", "ROUND")) + " / " + str(stage.metadata.get("name", "圆形明亮式"))
	var geometry_label: String = "%d 切面" % stage.planes.size() if stage.geometry_mode == 0 else "光滑曲面"
	specimen_color.text = "%s   /   #%s" % [geometry_label, stage.current_tint.to_html(false).to_upper()]
	specimen_color.text += "   /   " + str(stage.metadata.get("style", "明亮式"))
	if stage.material_index > 0:
		specimen_color.text = "%s   /   %s   /   %s" % [geometry_label,
			PrismGemStage.MATERIALS[stage.material_index]["en"], "日光" if stage.illuminant == 0 else "暖灯"]


func _on_cut_selected(index: int) -> void:
	var cut: Dictionary = stage.cut_catalog[index]
	if stage.set_cut(str(cut["id"])):
		cut_picker.select(index)
		_sync_material_panels()
		_update_caption()
		_show_status(str(cut["description"]))


func _toggle_view() -> void:
	stage.set_top_view(not stage.top_view)
	view_button.text = "斜视" if stage.top_view else "俯视"
	stage.update_pose()


func _on_custom_color(color: Color) -> void:
	if updating_controls:
		return
	stage.set_tint(color)
	material_name.text = "CUSTOM  /  自选颜色"
	for button in material_buttons:
		button.set_pressed_no_signal(false)
	_update_caption()


func _on_slider_changed(value: float, key: String) -> void:
	_set_value_text(key, value)
	if updating_controls:
		return
	match key:
		"brilliance":
			stage.current_brilliance = value
			stage.gem_material.set_shader_parameter("brilliance", value)
		"dispersion", "soft_fire":
			stage.current_dispersion = value
			stage.gem_material.set_shader_parameter("dispersion", value)
			var other: String = "soft_fire" if key == "dispersion" else "dispersion"
			(sliders[other] as HSlider).set_value_no_signal(value)
			_set_value_text(other, value)
		"caustics":
			stage.set_caustics(value)
		"shadow_softness":
			stage.ground_optics.shadow_softness = value
		"light", "opal_light", "soft_light":
			stage.light_angle = deg_to_rad(value)
			for other in ["light", "opal_light", "soft_light"]:
				if other != key:
					(sliders[other] as HSlider).set_value_no_signal(value)
					_set_value_text(other, value)
		"opal_size", "opal_strength", "opal_haze":
			stage.set_opal(float(sliders["opal_size"].value), float(sliders["opal_strength"].value), float(sliders["opal_haze"].value))
		"zone_position", "zone_width", "zone_angle":
			stage.set_zones(float(sliders["zone_position"].value), float(sliders["zone_width"].value), deg_to_rad(float(sliders["zone_angle"].value)))
		"density":
			stage.set_optics(stage.current_ior, stage.current_dispersion, stage.current_brilliance, value)
		"pearl_luster", "pearl_orient", "eye_strength", "eye_width", "moon_strength", "moon_spread", "moon_depth", "moon_rainbow":
			stage.set(key, value)
			stage.set_soft_effects()
		"eye_axis":
			stage.eye_axis = deg_to_rad(value)
			stage.set_soft_effects()
		"facet_transparency":
			stage.set_facet_transparency(value)


func _on_resolution_changed(index: int) -> void:
	pixel_resolution = resolution_picker.get_item_id(index)
	viewport.size = Vector2i(pixel_resolution, pixel_resolution)
	_layout()


func _layout() -> void:
	if not is_instance_valid(left_panel):
		return
	var margin: float = 46.0
	var left_width: float = 300.0
	var available_width: float = size.x - margin * 2.0 - left_width - 60.0
	var available_height: float = size.y - 190.0
	var scale_factor: int = maxi(1, int(minf(available_width, available_height) / float(pixel_resolution)))
	var stage_size: float = float(pixel_resolution * scale_factor)
	sidebar_scroll.position = Vector2(margin, 32)
	sidebar_scroll.size = Vector2(left_width, maxf(240.0, size.y - 64.0))
	right_panel.position = Vector2(margin + left_width + 60.0 + maxf(0.0, (available_width - stage_size) * 0.5), 55)
	right_panel.size = Vector2(stage_size, 0)
	preview.custom_minimum_size = Vector2(stage_size, stage_size)
	preview.size = Vector2(stage_size, stage_size)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f6f6ef"))
	draw_line(Vector2(374, 40), Vector2(374, size.y - 40), BORDER, 1.0)
	# Small registration marks frame the specimen without covering the pixels.
	if is_instance_valid(preview):
		var rect := Rect2(preview.global_position, preview.size)
		var length: float = 11.0
		var color := Color("b4c0b1")
		for point in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
			var dx: float = -1.0 if point.x > rect.get_center().x else 1.0
			var dy: float = -1.0 if point.y > rect.get_center().y else 1.0
			draw_line(point, point + Vector2(length * dx, 0), color)
			draw_line(point, point + Vector2(0, length * dy), color)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			dragging = mouse.pressed
			if dragging:
				was_rotating = stage.auto_rotate
				stage.auto_rotate = false
			else:
				stage.auto_rotate = was_rotating
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			stage.zoom_by(0.93)
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			stage.zoom_by(1.07)
		preview.accept_event()
	elif event is InputEventMouseMotion and dragging:
		stage.orbit((event as InputEventMouseMotion).relative)
		preview.accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed and dragging:
		dragging = false
		stage.auto_rotate = was_rotating
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo or color_picker.get_popup().visible or surface_color_picker.get_popup().visible:
			return
		if key.keycode >= KEY_1 and key.keycode <= KEY_6:
			select_preset(int(key.keycode - KEY_1))
		elif key.keycode == KEY_SPACE:
			_toggle_rotation()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_R:
			_reset_view()
		elif key.keycode == KEY_T:
			_toggle_view()
		elif key.keycode == KEY_L:
			_select_light(1 - stage.illuminant)
		elif key.keycode == KEY_P:
			_save_image()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_BRACKETLEFT:
			_on_cut_selected(posmod(cut_picker.selected - 1, stage.cut_catalog.size()))
		elif key.keycode == KEY_BRACKETRIGHT:
			_on_cut_selected(posmod(cut_picker.selected + 1, stage.cut_catalog.size()))


func _toggle_rotation() -> void:
	stage.auto_rotate = not stage.auto_rotate
	rotation_button.text = "Ⅱ  暂停旋转" if stage.auto_rotate else "▷  自动旋转"


func _reset_view() -> void:
	stage.reset_view()
	_show_status("视角已复位。拖动旋转，滚轮缩放。")


func _save_image() -> void:
	var filename: String = "prism_%s_%s_%s_%s_%d.png" % [stage.current_cut_id,
		PrismGemStage.MATERIALS[stage.material_index]["id"], "day" if stage.illuminant == 0 else "warm",
		Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_msec()]
	var image: Image = viewport.get_texture().get_image()
	image.resize(pixel_resolution * 3, pixel_resolution * 3, Image.INTERPOLATE_NEAREST)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(image.save_png_to_buffer(), filename, "image/png")
		_show_status("PNG 已下载。", 6.0)
		return
	var directory: String = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(directory)
	var result: Error = image.save_png(directory.path_join(filename))
	if result == OK:
		_show_status("已保存 PNG：" + directory.path_join(filename), 8.0)
		OS.shell_open(directory)
	else:
		_show_status("保存失败，请检查目录权限。")


func _show_status(message: String, seconds: float = 4.0) -> void:
	status.text = message
	toast_time = seconds


func _notify_web_ready() -> void:
	await RenderingServer.frame_post_draw
	JavaScriptBridge.eval("window.dispatchEvent(new Event('prism-ready'));")


func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			status.text = "拖动宝石转一转，看看光的变化。"


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(path)


func _run_visual_checks() -> void:
	var directory: String = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	stage.auto_rotate = false
	stage.animate = false
	stage.clock_time = 1.42
	_on_cut_selected(0)
	stage.reset_view()
	stage.sparkle_enabled = false
	var report: Dictionary = {"geometry": stage.validate_exported_geometry(), "presets": []}
	await get_tree().process_frame
	for i in range(PRESETS.size()):
		# Exercise the same button connections used by the real interface.
		material_buttons[i].pressed.emit()
		await get_tree().process_frame
		await _capture(directory.path_join("preset_%d.png" % i))
		report["presets"].append({"index": i, "color": stage.current_tint.to_html(false),
			"ior": stage.current_ior, "selected": material_buttons[i].button_pressed})
	select_preset(0)
	stage.reset_view()
	await get_tree().process_frame
	await _capture(directory.path_join("baseline.png"))
	var initial_yaw: float = stage.yaw
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(71, -22)
	dragging = true
	_on_preview_input(move)
	dragging = false
	report["drag_rotates"] = absf(stage.yaw - initial_yaw) > 0.4
	await get_tree().process_frame
	await _capture(directory.path_join("rotated.png"))
	stage.reset_view()
	(sliders["caustics"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("no_caustics.png"))
	(sliders["caustics"] as HSlider).value = 1.0
	resolution_picker.select(0)
	resolution_picker.item_selected.emit(0)
	report["resolution_192"] = viewport.size == Vector2i(192, 192)
	resolution_picker.select(1)
	resolution_picker.item_selected.emit(1)
	color_picker.color_changed.emit(Color("dd5555"))
	report["custom_color"] = stage.current_tint.to_html(false) == "dd5555"
	# Separate the optical changes from the decorative cross-shaped sparkles.
	select_preset(4)
	(sliders["dispersion"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("fire_off.png"))
	(sliders["dispersion"] as HSlider).value = 1.0
	await get_tree().process_frame
	await _capture(directory.path_join("fire_on.png"))
	stage.gem_material.set_shader_parameter("bounce_count", 1)
	await get_tree().process_frame
	await _capture(directory.path_join("single_bounce.png"))
	stage.gem_material.set_shader_parameter("bounce_count", 10)
	await get_tree().process_frame
	await _capture(directory.path_join("deep_reflections.png"))
	select_preset(0)
	for i in range(4):
		stage.yaw = [0.15, 0.65, 1.30, 2.10][i]
		stage.update_pose()
		await get_tree().process_frame
		await _capture(directory.path_join("optics_yaw_%d.png" % i))
	var cut_results: Array = []
	var cuts_passed: bool = true
	for i in range(stage.cut_catalog.size()):
		var cut: Dictionary = stage.cut_catalog[i]
		stage.set_tint(Color("59cbb1"))
		stage.set_optics(1.91, 0.73, 1.12, 0.65)
		cut_picker.select(i)
		cut_picker.item_selected.emit(i)
		await get_tree().process_frame
		var geometry: Dictionary = stage.validate_exported_geometry()
		var preserves_optics: bool = stage.current_tint.to_html(false) == "59cbb1" and is_equal_approx(stage.current_ior, 1.91) and is_equal_approx(stage.current_dispersion, 0.73)
		var cut_ok: bool = bool(geometry["passed"]) and preserves_optics and stage.current_cut_id == cut["id"] and stage.pivot.get_child_count() == 1
		cuts_passed = cuts_passed and cut_ok
		select_preset(0)
		stage.set_top_view(false)
		stage.reset_view()
		await get_tree().process_frame
		await _capture(directory.path_join("cut_%s.png" % cut["id"]))
		stage.set_top_view(true)
		stage.reset_view()
		await get_tree().process_frame
		await _capture(directory.path_join("cut_%s_top.png" % cut["id"]))
		for color_index in range(PRESETS.size()):
			material_buttons[color_index].pressed.emit()
			await get_tree().process_frame
			await _capture(directory.path_join("cut_%s_color_%d.png" % [cut["id"], color_index]))
		cut_results.append({"id": cut["id"], "geometry": geometry, "preserves_optics": preserves_optics, "passed": cut_ok})
	report["cuts"] = cut_results
	report["cuts_passed"] = cuts_passed
	var materials_passed: bool = true
	var material_results: Array = []
	stage.set_top_view(false)
	stage.reset_view()
	for material_id in range(1, PrismGemStage.MATERIALS.size()):
		if material_id >= PrismGemStage.OPAL_MATERIAL:
			continue # The volume and angular response have their own GPU checks.
		material_picker.select(material_id)
		material_picker.item_selected.emit(material_id)
		for light_id in range(2):
			light_buttons[light_id].pressed.emit()
			for cut_id in range(stage.cut_catalog.size()):
				_on_cut_selected(cut_id)
				stage.reset_view()
				await get_tree().process_frame
				var kept: bool = stage.material_index == material_id and stage.illuminant == light_id
				kept = kept and is_equal_approx(stage.current_ior, float(PrismGemStage.MATERIALS[material_id]["ior"]))
				kept = kept and stage.current_zone_a == PrismGemStage.MATERIALS[material_id]["a"]
				materials_passed = materials_passed and kept
				var tag: String = "%s_%s_%s" % [PrismGemStage.MATERIALS[material_id]["id"], stage.current_cut_id, "day" if light_id == 0 else "warm"]
				await _capture(directory.path_join("material_" + tag + ".png"))
				material_results.append({"combination": tag, "preserves_material_and_light": kept})
	_on_cut_selected(0)
	_select_light(0)
	select_material(1)
	(sliders["zone_position"] as HSlider).value = 0.34
	(sliders["zone_angle"] as HSlider).value = 90.0
	(sliders["zone_width"] as HSlider).value = 0.26
	await get_tree().process_frame
	await _capture(directory.path_join("material_zones_adjusted.png"))
	report["zone_controls"] = is_equal_approx(stage.zone_position, 0.34) and is_equal_approx(stage.zone_angle, PI * 0.5) and is_equal_approx(stage.zone_width, 0.26)
	zone_pickers[0].color_changed.emit(Color("268bde"))
	zone_pickers[1].color_changed.emit(Color("f1b239"))
	_on_cut_selected(5)
	report["custom_zones_preserved"] = stage.current_zone_a == Color("268bde") and stage.current_zone_b == Color("f1b239") and is_equal_approx(stage.zone_position, 0.34)
	(sliders["zone_position"] as HSlider).value = 0.0
	(sliders["zone_angle"] as HSlider).value = 0.0
	(sliders["zone_width"] as HSlider).value = 0.10
	select_material(4)
	(sliders["density"] as HSlider).value = 0.40
	_on_cut_selected(0)
	await get_tree().process_frame
	await _capture(directory.path_join("material_alexandrite_thin.png"))
	(sliders["density"] as HSlider).value = 1.15
	await get_tree().process_frame
	await _capture(directory.path_join("material_alexandrite_dense.png"))
	report["materials"] = material_results
	report["materials_passed"] = materials_passed
	_on_cut_selected(0)
	stage.set_top_view(false)
	stage.reset_view()
	select_preset(0)
	select_preset(0)
	stage.reset_view()
	stage.sparkle_enabled = true
	stage.clock_time = 1.45
	stage.update_pose()
	await get_tree().process_frame
	await _capture(directory.path_join("hero.png"))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("interface.png"))
	select_material(1)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("interface_materials.png"))
	select_material(4)
	_select_light(1)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("interface_alexandrite.png"))
	var file := FileAccess.open(directory.path_join("qa_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PRISM_VISUAL_QA_COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if report["geometry"]["passed"] and report["drag_rotates"] and report["custom_color"] and report["resolution_192"] and cuts_passed and materials_passed and report["zone_controls"] and report["custom_zones_preserved"] else 1)


func _run_opal_checks() -> void:
	stage.set_caustics(0.0)
	var directory: String = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	stage.auto_rotate = false
	stage.animate = false
	stage.sparkle_enabled = false
	stage.clock_time = 1.42
	select_material(PrismGemStage.OPAL_MATERIAL)
	var report: Dictionary = {"combinations": [], "passed": true, "decorative_stars_disabled": true}
	for light_id in range(2):
		light_buttons[light_id].pressed.emit()
		for i in range(stage.cut_catalog.size()):
			_on_cut_selected(i)
			stage.set_top_view(false)
			stage.reset_view()
			await get_tree().process_frame
			var kept: bool = stage.material_index == PrismGemStage.OPAL_MATERIAL and stage.illuminant == light_id
			kept = kept and is_equal_approx(stage.opal_patch_size, 0.55) and is_equal_approx(stage.opal_haze, 0.22)
			kept = kept and bool(stage.validate_exported_geometry()["passed"])
			report["passed"] = bool(report["passed"]) and kept
			report["combinations"].append({"cut": stage.current_cut_id, "light": light_id, "parameters_and_geometry": kept})
			await _capture(directory.path_join("opal_%s_%s.png" % [stage.current_cut_id, "day" if light_id == 0 else "warm"]))
	_on_cut_selected(1)
	_select_light(0)
	stage.reset_view()
	for i in range(72):
		stage.yaw = 0.40 + TAU * float(i) / 72.0
		stage.update_pose()
		await get_tree().process_frame
		await _capture(directory.path_join("opal_turn_%03d.png" % i))
	stage.reset_view()
	(sliders["opal_light"] as HSlider).value = 90.0
	await get_tree().process_frame
	await _capture(directory.path_join("opal_light_90.png"))
	(sliders["opal_strength"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("opal_no_color_light_90.png"))
	(sliders["opal_light"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("opal_no_color.png"))
	(sliders["opal_strength"] as HSlider).value = 1.15
	(sliders["opal_haze"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("opal_clear.png"))
	(sliders["opal_haze"] as HSlider).value = 0.90
	await get_tree().process_frame
	await _capture(directory.path_join("opal_milky.png"))
	(sliders["opal_haze"] as HSlider).value = 0.22
	(sliders["opal_size"] as HSlider).value = 0.05
	await get_tree().process_frame
	await _capture(directory.path_join("opal_small_patches.png"))
	(sliders["opal_size"] as HSlider).value = 0.90
	await get_tree().process_frame
	await _capture(directory.path_join("opal_large_patches.png"))
	(sliders["opal_size"] as HSlider).value = 0.55
	(sliders["opal_size"] as HSlider).value = 0.72
	(sliders["opal_strength"] as HSlider).value = 1.43
	(sliders["opal_haze"] as HSlider).value = 0.36
	_on_cut_selected(5)
	select_material(4)
	select_material(PrismGemStage.OPAL_MATERIAL)
	report["custom_settings_preserved"] = is_equal_approx(stage.opal_patch_size, 0.72) and is_equal_approx(stage.opal_strength, 1.43) and is_equal_approx(stage.opal_haze, 0.36)
	report["light_controls_synchronized"] = is_equal_approx(float(sliders["light"].value), float(sliders["opal_light"].value))
	(sliders["opal_size"] as HSlider).value = 0.55
	(sliders["opal_strength"] as HSlider).value = 1.15
	(sliders["opal_haze"] as HSlider).value = 0.22
	_on_cut_selected(1)
	stage.reset_view()
	await get_tree().process_frame
	await _capture(directory.path_join("opal_static_a.png"))
	for i in range(12):
		await get_tree().process_frame
	await _capture(directory.path_join("opal_static_b.png"))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("interface_opal.png"))
	var file := FileAccess.open(directory.path_join("opal_qa_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PRISM_OPAL_QA_COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if report["passed"] and report["custom_settings_preserved"] and report["light_controls_synchronized"] else 1)


func _run_soft_checks() -> void:
	stage.set_caustics(0.0)
	var directory: String = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	stage.auto_rotate = false
	stage.animate = false
	stage.sparkle_enabled = false
	stage.clock_time = 1.42
	rotation_button.text = "▷  自动旋转"
	var report: Dictionary = {"passed": true, "combinations": [], "recommended_shapes": []}
	for material_id in range(PrismGemStage.PEARL_MATERIAL, PrismGemStage.MOONSTONE_MATERIAL + 1):
		material_picker.item_selected.emit(material_id)
		var entry: Dictionary = PrismGemStage.MATERIALS[material_id]
		var recommended: bool = stage.current_cut_id == entry["recommended_form"]
		report["recommended_shapes"].append({"material": entry["id"], "passed": recommended})
		report["passed"] = bool(report["passed"]) and recommended
		for light_id in range(2):
			light_buttons[light_id].pressed.emit()
			for cut_id in range(stage.cut_catalog.size()):
				_on_cut_selected(cut_id)
				stage.set_top_view(false)
				stage.reset_view()
				await get_tree().process_frame
				var geometry: Dictionary = stage.validate_exported_geometry()
				var kept: bool = stage.material_index == material_id and stage.illuminant == light_id and bool(geometry["passed"])
				report["passed"] = bool(report["passed"]) and kept
				report["combinations"].append({"material": entry["id"], "cut": stage.current_cut_id, "light": light_id, "passed": kept, "geometry": geometry})
				await _capture(directory.path_join("soft_%s_%s_%s.png" % [entry["id"], stage.current_cut_id, "day" if light_id == 0 else "warm"]))
		for cut_id in range(stage.cut_catalog.size()):
			if stage.cut_catalog[cut_id]["id"] == entry["recommended_form"]:
				_on_cut_selected(cut_id)
				break
		_select_light(0)
		stage.reset_view()
		for frame in range(60):
			(sliders["soft_light"] as HSlider).value = float(frame) * 6.0
			stage.update_pose()
			await get_tree().process_frame
			await _capture(directory.path_join("soft_%s_light_%03d.png" % [entry["id"], frame]))
		(sliders["soft_light"] as HSlider).value = 0.0
		await get_tree().process_frame
		await _capture(directory.path_join("soft_%s_hero.png" % entry["id"]))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("interface_%s.png" % entry["id"]))
		if material_id == PrismGemStage.PEARL_MATERIAL:
			(sliders["pearl_orient"] as HSlider).value = 0.0
			await get_tree().process_frame
			await _capture(directory.path_join("soft_pearl_no_orient.png"))
			(sliders["pearl_orient"] as HSlider).value = 0.45
			(sliders["pearl_luster"] as HSlider).value = 0.0
			await get_tree().process_frame
			await _capture(directory.path_join("soft_pearl_no_luster.png"))
			(sliders["pearl_luster"] as HSlider).value = 0.72
		elif material_id == PrismGemStage.CATSEYE_MATERIAL:
			(sliders["eye_strength"] as HSlider).value = 0.0
			await get_tree().process_frame
			await _capture(directory.path_join("soft_catseye_no_eye.png"))
			(sliders["soft_light"] as HSlider).value = 90.0
			await get_tree().process_frame
			await _capture(directory.path_join("soft_catseye_no_eye_light_90.png"))
			(sliders["soft_light"] as HSlider).value = 0.0
			(sliders["eye_strength"] as HSlider).value = 1.0
			(sliders["eye_width"] as HSlider).value = 0.015
			await get_tree().process_frame
			await _capture(directory.path_join("soft_catseye_narrow.png"))
			(sliders["eye_width"] as HSlider).value = 0.13
			await get_tree().process_frame
			await _capture(directory.path_join("soft_catseye_wide.png"))
			(sliders["eye_width"] as HSlider).value = 0.055
			(sliders["eye_axis"] as HSlider).value = 90.0
			await get_tree().process_frame
			await _capture(directory.path_join("soft_catseye_axis_90.png"))
			(sliders["eye_axis"] as HSlider).value = 0.0
		else:
			(sliders["moon_strength"] as HSlider).value = 0.0
			await get_tree().process_frame
			await _capture(directory.path_join("soft_moonstone_no_glow.png"))
			(sliders["soft_light"] as HSlider).value = 90.0
			await get_tree().process_frame
			await _capture(directory.path_join("soft_moonstone_no_glow_light_90.png"))
			(sliders["soft_light"] as HSlider).value = 0.0
			(sliders["moon_strength"] as HSlider).value = 1.0
			(sliders["moon_depth"] as HSlider).value = 0.0
			await get_tree().process_frame
			await _capture(directory.path_join("soft_moonstone_shallow.png"))
			(sliders["moon_depth"] as HSlider).value = 1.0
			await get_tree().process_frame
			await _capture(directory.path_join("soft_moonstone_deep.png"))
			(sliders["moon_depth"] as HSlider).value = 0.55
	await get_tree().process_frame
	await _capture(directory.path_join("soft_static_a.png"))
	for frame in range(12):
		await get_tree().process_frame
	await _capture(directory.path_join("soft_static_b.png"))
	(sliders["pearl_orient"] as HSlider).value = 0.81
	(sliders["eye_width"] as HSlider).value = 0.094
	(sliders["eye_axis"] as HSlider).value = 65.0
	(sliders["moon_depth"] as HSlider).value = 0.73
	surface_color_picker.color_changed.emit(Color("d7d2c9"))
	_on_cut_selected(9)
	_on_cut_selected(11)
	report["custom_parameters_preserved"] = is_equal_approx(stage.pearl_orient, 0.81) and is_equal_approx(stage.eye_width, 0.094) and is_equal_approx(stage.eye_axis, deg_to_rad(65.0)) and is_equal_approx(stage.moon_depth, 0.73) and stage.current_tint == Color("d7d2c9")
	report["lights_synchronized"] = is_equal_approx(float(sliders["light"].value), float(sliders["soft_light"].value)) and is_equal_approx(float(sliders["opal_light"].value), float(sliders["soft_light"].value))
	var file := FileAccess.open(directory.path_join("soft_qa_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PRISM_SOFT_QA_COMPLETE: passed=", report["passed"], ", combinations=", report["combinations"].size())
	get_tree().quit(0 if report["passed"] and report["custom_parameters_preserved"] and report["lights_synchronized"] else 1)


func _run_fire_checks() -> void:
	stage.set_caustics(0.0)
	var directory: String = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	stage.auto_rotate = false
	stage.animate = false
	stage.sparkle_enabled = false
	stage.clock_time = 1.42
	var report: Dictionary = {"passed": true, "combinations": [], "decorative_stars_disabled": true}
	for material_id in [PrismGemStage.CATSEYE_MATERIAL, PrismGemStage.MOONSTONE_MATERIAL]:
		select_material(material_id)
		var entry: Dictionary = PrismGemStage.MATERIALS[material_id]
		for light_id in range(2):
			_select_light(light_id)
			for cut_id in range(stage.cut_catalog.size()):
				_on_cut_selected(cut_id)
				stage.set_top_view(false)
				stage.reset_view()
				var kept: bool = stage.material_index == material_id and stage.illuminant == light_id
				kept = kept and is_equal_approx(stage.current_facet_transparency, float(entry["transparency"]))
				report["passed"] = bool(report["passed"]) and kept
				report["combinations"].append({"material": entry["id"], "cut": stage.current_cut_id,
					"light": light_id, "faceted": stage.geometry_mode == 0, "passed": kept})
				for fire_id in range(2):
					(sliders["soft_fire"] as HSlider).value = float(fire_id)
					await get_tree().process_frame
					await _capture(directory.path_join("mixed_%s_%s_%s_fire_%d.png" % [entry["id"],
						stage.current_cut_id, "day" if light_id == 0 else "warm", fire_id]))
	select_material(PrismGemStage.MOONSTONE_MATERIAL)
	_select_light(0)
	_on_cut_selected(0)
	stage.reset_view()
	await get_tree().process_frame
	await _capture(directory.path_join("moonfire_default.png"))
	(sliders["soft_fire"] as HSlider).value = 1.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonfire_enhanced.png"))
	(sliders["soft_fire"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonfire_glow_without_fire.png"))
	(sliders["moon_strength"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonfire_neither.png"))
	(sliders["soft_fire"] as HSlider).value = 1.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonfire_fire_without_glow.png"))
	(sliders["moon_strength"] as HSlider).value = 1.0
	(sliders["facet_transparency"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonfire_legacy_body.png"))
	(sliders["facet_transparency"] as HSlider).value = 0.70
	stage.gem_material.set_shader_parameter("bounce_count", 1)
	await get_tree().process_frame
	await _capture(directory.path_join("moonfire_single_bounce.png"))
	stage.gem_material.set_shader_parameter("bounce_count", 10)
	await get_tree().process_frame
	await _capture(directory.path_join("moonfire_deep_reflections.png"))
	for frame in range(60):
		stage.yaw = 0.40 + TAU * float(frame) / 60.0
		stage.update_pose()
		for variant in range(3):
			(sliders["soft_fire"] as HSlider).value = 0.0 if variant == 0 else 1.0
			(sliders["moon_strength"] as HSlider).value = 0.0 if variant == 2 else 1.0
			await get_tree().process_frame
			await _capture(directory.path_join("moonfire_turn_%d_%03d.png" % [variant, frame]))
	stage.reset_view()
	(sliders["moon_strength"] as HSlider).value = 1.0
	(sliders["soft_fire"] as HSlider).value = 0.63
	(sliders["facet_transparency"] as HSlider).value = 0.46
	_on_cut_selected(5)
	report["parameters_preserved"] = is_equal_approx(stage.current_dispersion, 0.63) and is_equal_approx(stage.current_facet_transparency, 0.46)
	report["fire_controls_synchronized"] = is_equal_approx(float(sliders["dispersion"].value), float(sliders["soft_fire"].value))
	(sliders["soft_fire"] as HSlider).value = 0.18
	(sliders["facet_transparency"] as HSlider).value = 0.70
	_on_cut_selected(0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("interface_moonfire.png"))
	var file := FileAccess.open(directory.path_join("fire_qa_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PRISM_FIRE_QA_COMPLETE: passed=", report["passed"], ", combinations=", report["combinations"].size())
	get_tree().quit(0 if report["passed"] and report["parameters_preserved"] and report["fire_controls_synchronized"] else 1)


func _run_ground_checks() -> void:
	var checks = preload("res://scripts/ground_checks.gd").new()
	await checks.run(self)


func _run_cut_detail_checks() -> void:
	var checks = preload("res://scripts/cut_detail_checks.gd").new()
	await checks.run(self, "--qa-cut-detail-before" in OS.get_cmdline_user_args())


func _run_moon_checks() -> void:
	stage.set_caustics(0.0)
	var directory: String = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	stage.auto_rotate = false
	stage.animate = false
	stage.sparkle_enabled = false
	stage.clock_time = 1.42
	select_material(PrismGemStage.MOONSTONE_MATERIAL)
	var report: Dictionary = {"passed": true, "combinations": [], "decorative_stars_disabled": sparkle_toggle.disabled}
	for light_id in range(2):
		_select_light(light_id)
		for cut_id in range(stage.cut_catalog.size()):
			_on_cut_selected(cut_id)
			stage.set_top_view(false)
			stage.reset_view()
			var tag: String = "moonrainbow_%s_%s" % [stage.current_cut_id, "day" if light_id == 0 else "warm"]
			await get_tree().process_frame
			await _capture(directory.path_join(tag + ".png"))
			(sliders["moon_strength"] as HSlider).value = 0.0
			await get_tree().process_frame
			await _capture(directory.path_join(tag + "_no_glow.png"))
			(sliders["moon_strength"] as HSlider).value = 1.0
			for fire_id in range(2):
				(sliders["soft_fire"] as HSlider).value = float(fire_id)
				await get_tree().process_frame
				await _capture(directory.path_join(tag + "_fire_%d.png" % fire_id))
			(sliders["soft_fire"] as HSlider).value = 0.18
			var kept: bool = stage.material_index == PrismGemStage.MOONSTONE_MATERIAL and stage.illuminant == light_id
			kept = kept and is_equal_approx(stage.moon_rainbow, 0.85) and is_equal_approx(stage.moon_spread, 0.78)
			kept = kept and bool(stage.validate_exported_geometry()["passed"])
			report["combinations"].append({"cut": stage.current_cut_id, "light": light_id,
				"faceted": stage.geometry_mode == 0, "passed": kept})
			report["passed"] = bool(report["passed"]) and kept
	_select_light(0)
	_on_cut_selected(7)
	stage.reset_view()
	for frame in range(60):
		stage.yaw = 0.40 + TAU * float(frame) / 60.0
		stage.update_pose()
		await get_tree().process_frame
		await _capture(directory.path_join("moonrainbow_turn_%03d.png" % frame))
	stage.reset_view()
	(sliders["soft_light"] as HSlider).value = 90.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_light_90.png"))
	(sliders["moon_strength"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_no_glow_light_90.png"))
	(sliders["soft_light"] as HSlider).value = 0.0
	(sliders["moon_strength"] as HSlider).value = 1.0
	(sliders["moon_rainbow"] as HSlider).value = 0.0
	(sliders["moon_spread"] as HSlider).value = 0.48
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_legacy_blue.png"))
	(sliders["moon_strength"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_legacy_no_glow.png"))
	(sliders["moon_strength"] as HSlider).value = 1.0
	(sliders["moon_spread"] as HSlider).value = 0.78
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_blue.png"))
	(sliders["moon_rainbow"] as HSlider).value = 1.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_full_rainbow.png"))
	(sliders["moon_rainbow"] as HSlider).value = 0.85
	(sliders["moon_spread"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_narrow.png"))
	(sliders["moon_spread"] as HSlider).value = 1.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_wide.png"))
	(sliders["moon_spread"] as HSlider).value = 0.78
	(sliders["moon_depth"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_shallow.png"))
	(sliders["moon_depth"] as HSlider).value = 1.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_deep.png"))
	(sliders["moon_depth"] as HSlider).value = 0.55
	(sliders["facet_transparency"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_soft_body.png"))
	(sliders["facet_transparency"] as HSlider).value = 1.0
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_clear_body.png"))
	(sliders["facet_transparency"] as HSlider).value = 0.70
	stage.gem_material.set_shader_parameter("bounce_count", 1)
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_single_bounce.png"))
	stage.gem_material.set_shader_parameter("bounce_count", 10)
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_deep_reflections.png"))
	(sliders["moon_rainbow"] as HSlider).value = 0.37
	(sliders["moon_spread"] as HSlider).value = 0.64
	(sliders["moon_depth"] as HSlider).value = 0.61
	(sliders["soft_fire"] as HSlider).value = 0.63
	(sliders["facet_transparency"] as HSlider).value = 0.46
	_on_cut_selected(5)
	report["optics_preserved"] = is_equal_approx(stage.current_dispersion, 0.63) and is_equal_approx(stage.current_facet_transparency, 0.46)
	select_material(PrismGemStage.CATSEYE_MATERIAL)
	select_material(PrismGemStage.MOONSTONE_MATERIAL)
	report["sheen_settings_preserved"] = is_equal_approx(stage.moon_rainbow, 0.37) and is_equal_approx(stage.moon_spread, 0.64) and is_equal_approx(stage.moon_depth, 0.61)
	report["controls_synchronized"] = is_equal_approx(float(sliders["moon_rainbow"].value), stage.moon_rainbow) and is_equal_approx(float(stage.gem_material.get_shader_parameter("moon_rainbow")), stage.moon_rainbow)
	(sliders["moon_rainbow"] as HSlider).value = 0.85
	(sliders["moon_spread"] as HSlider).value = 0.78
	(sliders["moon_depth"] as HSlider).value = 0.55
	_on_cut_selected(7)
	stage.reset_view()
	await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_static_a.png"))
	for frame in range(12):
		await get_tree().process_frame
	await _capture(directory.path_join("moonrainbow_static_b.png"))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("interface_moonrainbow.png"))
	var file := FileAccess.open(directory.path_join("moonrainbow_qa_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	var passed: bool = report["passed"] and report["optics_preserved"] and report["sheen_settings_preserved"] and report["controls_synchronized"]
	print("PRISM_MOON_QA_COMPLETE: passed=", passed, ", combinations=", report["combinations"].size())
	get_tree().quit(0 if passed else 1)


func _run_refinement_checks() -> void:
	stage.set_caustics(0.0)
	var directory: String = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	stage.auto_rotate = false
	stage.animate = false
	stage.sparkle_enabled = false
	stage.clock_time = 1.42
	_on_cut_selected(0)
	stage.set_top_view(false)
	stage.reset_view()
	for i in range(PRESETS.size()):
		select_preset(i)
		stage.gem_material.set_shader_parameter("studio_refinement", 0.0)
		await get_tree().process_frame
		await _capture(directory.path_join("refine_lighting_old_%d.png" % i))
		stage.gem_material.set_shader_parameter("studio_refinement", 1.0)
		await get_tree().process_frame
		await _capture(directory.path_join("refine_lighting_new_%d.png" % i))
	select_material(PrismGemStage.BLACK_OPAL_MATERIAL)
	var report: Dictionary = {"passed": true, "combinations": [],
		"decorative_stars_disabled": sparkle_toggle.disabled and not stage.supports_decorative_sparkles()}
	report["recommended_form"] = stage.current_cut_id == "pear"
	for light_id in range(2):
		_select_light(light_id)
		for i in range(stage.cut_catalog.size()):
			_on_cut_selected(i)
			stage.set_top_view(false)
			stage.reset_view()
			await get_tree().process_frame
			var geometry: Dictionary = stage.validate_exported_geometry()
			var kept: bool = stage.material_index == PrismGemStage.BLACK_OPAL_MATERIAL and stage.illuminant == light_id
			kept = kept and is_equal_approx(stage.opal_patch_size, 0.78) and is_equal_approx(stage.opal_haze, 0.35)
			kept = kept and int(stage.gem_material.get_shader_parameter("opal_kind")) == 1 and bool(geometry["passed"])
			report["passed"] = bool(report["passed"]) and kept
			report["combinations"].append({"cut": stage.current_cut_id, "light": light_id, "passed": kept})
			await _capture(directory.path_join("black_opal_%s_%s.png" % [stage.current_cut_id, "day" if light_id == 0 else "warm"]))
	_on_cut_selected(2)
	_select_light(0)
	stage.reset_view()
	for frame in range(60):
		stage.yaw = 0.40 + TAU * float(frame) / 60.0
		stage.update_pose()
		await get_tree().process_frame
		await _capture(directory.path_join("black_opal_turn_%03d.png" % frame))
	stage.reset_view()
	(sliders["opal_light"] as HSlider).value = 90.0
	await get_tree().process_frame
	await _capture(directory.path_join("black_opal_light_90.png"))
	(sliders["opal_strength"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("black_opal_no_color_light_90.png"))
	(sliders["opal_light"] as HSlider).value = 0.0
	await get_tree().process_frame
	await _capture(directory.path_join("black_opal_no_color.png"))
	(sliders["opal_strength"] as HSlider).value = 1.10
	(sliders["opal_size"] as HSlider).value = 0.05
	await get_tree().process_frame
	await _capture(directory.path_join("black_opal_small_patches.png"))
	(sliders["opal_size"] as HSlider).value = 0.95
	await get_tree().process_frame
	await _capture(directory.path_join("black_opal_large_patches.png"))
	(sliders["opal_size"] as HSlider).value = 0.64
	(sliders["opal_strength"] as HSlider).value = 1.35
	(sliders["opal_haze"] as HSlider).value = 0.41
	select_material(PrismGemStage.OPAL_MATERIAL)
	report["crystal_defaults_separate"] = is_equal_approx(stage.opal_patch_size, 0.55) and is_equal_approx(stage.opal_haze, 0.22)
	(sliders["opal_size"] as HSlider).value = 0.37
	(sliders["opal_haze"] as HSlider).value = 0.17
	select_material(PrismGemStage.BLACK_OPAL_MATERIAL)
	report["black_settings_preserved"] = is_equal_approx(stage.opal_patch_size, 0.64) and is_equal_approx(stage.opal_strength, 1.35) and is_equal_approx(stage.opal_haze, 0.41)
	select_material(PrismGemStage.OPAL_MATERIAL)
	report["crystal_settings_preserved"] = is_equal_approx(stage.opal_patch_size, 0.37) and is_equal_approx(stage.opal_haze, 0.17)
	(sliders["opal_size"] as HSlider).value = 0.55
	(sliders["opal_haze"] as HSlider).value = 0.22
	select_material(PrismGemStage.BLACK_OPAL_MATERIAL)
	(sliders["opal_size"] as HSlider).value = 0.78
	(sliders["opal_strength"] as HSlider).value = 1.10
	(sliders["opal_haze"] as HSlider).value = 0.35
	stage.reset_view()
	await get_tree().process_frame
	await _capture(directory.path_join("black_opal_static_a.png"))
	for frame in range(12):
		await get_tree().process_frame
	await _capture(directory.path_join("black_opal_static_b.png"))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("interface_black_opal.png"))
	var file := FileAccess.open(directory.path_join("refinement_qa_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PRISM_REFINEMENT_QA_COMPLETE: ", JSON.stringify(report))
	get_tree().quit(0 if report["passed"] and report["recommended_form"] and report["crystal_defaults_separate"] and report["black_settings_preserved"] and report["crystal_settings_preserved"] else 1)
