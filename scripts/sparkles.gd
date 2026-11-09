extends Node2D

var stage: PrismGemStage


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(stage):
		return
	for point in stage.projected_sparkles():
		if point.z < 0.20:
			continue
		var center := Vector2(point.x, point.y)
		var arm: int = maxi(1, roundi(point.z * 4.0))
		var ink := Color(1.0, 1.0, 0.96, minf(1.0, point.z * 1.8))
		draw_rect(Rect2(center - Vector2(arm, 0), Vector2(arm * 2 + 1, 1)), ink)
		draw_rect(Rect2(center - Vector2(0, arm), Vector2(1, arm * 2 + 1)), ink)
		if point.z > 0.72:
			draw_rect(Rect2(center + Vector2(-1, -1), Vector2(3, 3)), Color(1.0, 1.0, 0.98))
