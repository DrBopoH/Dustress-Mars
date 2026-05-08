extends ColorRect
class_name GraphGenerator

export var max_points: int = 60
export var margin: float = 20.0 
export var left_margin: float = 50.0 
export var grid_alpha: float = 0.1

export var grid_lines_x: int = 16
export var grid_lines_y: int = 16
export var y_label_step: int = 4

export var use_fixed_min: bool = false
export var fixed_min: float = 0.0
export var use_fixed_max: bool = false
export var fixed_max: float = 100.0

export var custom_font: Font
export var label_scale: float = 1.0 
export var text_update_interval: float = 0.1 

var lines: Dictionary = {}

var _last_text_time: int = 0
var _cached_max_val: float = 0.0
var _cached_min_val: float = 0.0

func setup_line(id: String, color: Color) -> void:
	lines[id] = {
		"data": [],
		"color": color,
		"width": 2.0,
		"gradient": {}
	}

func set_line_width(id: String, width: float) -> void:
	if lines.has(id):
		lines[id]["width"] = width

func set_line_gradient(id: String, gradient: Dictionary) -> void:
	if lines.has(id):
		lines[id]["gradient"] = gradient

func append(id: String, value: float) -> void:
	if not lines.has(id):
		return
		
	var data = lines[id]["data"]
	data.append(value)
	
	if data.size() > max_points:
		data.pop_front()
		
	update()

func _get_gradient_color(grad: Dictionary, percent: float) -> Color:
	var keys = grad.keys()
	keys.sort()
	
	if keys.empty():
		return Color.white
	if percent <= keys[0]:
		return grad[keys[0]]
	if percent >= keys[-1]:
		return grad[keys[-1]]
		
	for i in range(keys.size() - 1):
		if percent >= keys[i] and percent <= keys[i+1]:
			var span = keys[i+1] - keys[i]
			var weight = (percent - keys[i]) / span
			return grad[keys[i]].linear_interpolate(grad[keys[i+1]], weight)
			
	return Color.white

func _draw() -> void:
	if lines.empty():
		return
		
	var data_min = INF
	var data_max = -INF
	var total_sum = 0.0
	var total_count = 0
	var has_data = false
	
	for id in lines:
		var data = lines[id]["data"]
		if data.size() > 0:
			has_data = true
			for v in data:
				if v > data_max: data_max = v
				if v < data_min: data_min = v
				total_sum += v
				total_count += 1
				
	if not has_data:
		return
		
	var min_val = data_min
	var max_val = data_max
	
	if not (use_fixed_min and use_fixed_max):
		var average = total_sum / float(total_count)
		
		if data_min >= 0.0:
			min_val = 0.0
			var ideal_max = average * 2.0 if average > 0.0 else 1.0
			max_val = max(data_max * 1.1, ideal_max)
		elif data_max <= 0.0:
			max_val = 0.0
			var ideal_min = average * 2.0 if average < 0.0 else -1.0
			min_val = min(data_min * 1.1, ideal_min)
		else:
			var abs_max = max(abs(data_max), abs(data_min))
			max_val = max(data_max * 1.1, average + abs_max)
			min_val = min(data_min * 1.1, average - abs_max)

	if use_fixed_min: min_val = fixed_min
	if use_fixed_max: max_val = fixed_max
			
	var value_range = max_val - min_val
	if value_range == 0.0:
		value_range = 1.0

	var current_time = OS.get_ticks_msec()
	if _last_text_time == 0:
		_cached_max_val = max_val
		_cached_min_val = min_val
		
	if current_time - _last_text_time >= int(text_update_interval * 1000.0):
		_cached_max_val = max_val
		_cached_min_val = min_val
		_last_text_time = current_time

	var cached_value_range = _cached_max_val - _cached_min_val
	if cached_value_range == 0.0:
		cached_value_range = 1.0
		
	var draw_w = rect_size.x - left_margin - margin
	var draw_h = rect_size.y - margin * 2.0
	
	var axis_color = Color(1, 1, 1, 0.8)
	var axis_width = 2.0
	
	draw_line(Vector2(left_margin, margin), Vector2(left_margin, rect_size.y - margin), axis_color, axis_width)
	
	var decimal_anchor_x = left_margin
	if custom_font:
		var tail_width = custom_font.get_string_size(".000").x * label_scale
		var axis_padding = 8.0 * label_scale
		decimal_anchor_x = left_margin - tail_width - axis_padding
	
	if grid_lines_x > 0:
		for i in range(grid_lines_x + 1):
			var x = left_margin + draw_w * (float(i) / grid_lines_x)
			draw_line(Vector2(x, margin), Vector2(x, rect_size.y - margin), Color(1, 1, 1, grid_alpha), 1.0)

	if grid_lines_y > 0:
		for i in range(grid_lines_y + 1):
			var y = margin + draw_h * (float(i) / grid_lines_y)
			draw_line(Vector2(left_margin, y), Vector2(rect_size.x - margin, y), Color(1, 1, 1, grid_alpha), 1.0)
			
			if custom_font and y_label_step > 0 and i % y_label_step == 0:
				var val_at_y = _cached_max_val - (cached_value_range * (float(i) / grid_lines_y))
				var text = str(stepify(val_at_y, 0.001))
				
				var dot_idx = text.find(".")
				var int_str = text
				if dot_idx != -1:
					int_str = text.substr(0, dot_idx) 
					
				var int_w = custom_font.get_string_size(int_str).x * label_scale
				
				var text_x = decimal_anchor_x - int_w
				var text_y = y + 4.0 
				
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(label_scale, label_scale))
				draw_string(custom_font, Vector2(text_x / label_scale, text_y / label_scale), text, Color(1, 1, 1, 0.8))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE) 
			
	var zero_norm = clamp((0.0 - min_val) / value_range, 0.0, 1.0)
	var zero_y = rect_size.y - margin - (zero_norm * draw_h)
	draw_line(Vector2(left_margin, zero_y), Vector2(rect_size.x - margin, zero_y), axis_color, axis_width)
	
	var text_offset_y = margin
	
	var gradient_range = fixed_max - fixed_min
	if gradient_range <= 0.0: 
		gradient_range = 1.0 
	
	for id in lines:
		var line = lines[id]
		var data = line["data"]
		
		if data.size() < 2:
			continue
			
		var points = PoolVector2Array()
		var colors = PoolColorArray()
		var has_gradient = not line["gradient"].empty()
		
		var last_drawn_x = -100.0
		
		for i in range(data.size()):
			var x = left_margin + (float(i) / float(max_points - 1)) * draw_w
			
			if abs(x - last_drawn_x) < 1.0 and i != 0 and i != data.size() - 1:
				continue
				
			var norm_y = clamp((data[i] - min_val) / value_range, 0.0, 1.0)
			var y = rect_size.y - margin - (norm_y * draw_h)
			
			points.append(Vector2(x, y))
			
			if has_gradient:
				var color_norm = norm_y 
				if fixed_max > fixed_min:
					color_norm = clamp((data[i] - fixed_min) / gradient_range, 0.0, 1.0)
					
				colors.append(_get_gradient_color(line["gradient"], color_norm))
				
			last_drawn_x = x
				
		if has_gradient:
			draw_polyline_colors(points, colors, line["width"], true)
		else:
			draw_polyline(points, line["color"], line["width"], true)
			
		if custom_font:
			var last_val = data[-1]
			var text = "%s: %.3f" % [id, last_val]
			
			var leg_x = rect_size.x - margin + 5.0
			var leg_y = text_offset_y + 10.0
			
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(label_scale, label_scale))
			draw_string(custom_font, Vector2(leg_x / label_scale, leg_y / label_scale), text, line["color"])
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			
			text_offset_y += 15.0 * label_scale
