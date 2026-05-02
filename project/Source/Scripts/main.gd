extends Node

var font_alagard = preload("res://Assets/alagard-12px-unicode.ttf")
var font_PixeloidSans = preload("res://Assets/PixeloidSans-mLxMm.ttf")

var HealthGradient_scheme = {
	0.0: Color(1.0, 0.0, 0.0),
	0.5: Color(1.0, 1.0, 0.0),
	1.0: Color(0.0, 1.0, 0.0) 
}

var TemperatureGradient_scheme = {
	0.000: Color(0.0, 0.0, 0.5),   
	0.151: Color(0.0, 0.8, 1.0),   
	0.165: Color(0.4, 0.4, 0.4),   
	0.206: Color(0.2, 0.0, 0.0),   
	0.316: Color(0.5, 0.0, 0.0),   
	0.440: Color(1.0, 0.0, 0.0),   
	0.537: Color(1.0, 0.3, 0.0),   
	0.648: Color(1.0, 0.6, 0.0),   
	0.758: Color(1.0, 0.9, 0.0),   
	0.869: Color(1.0, 1.0, 0.6),   
	1.000: Color(1.0, 1.0, 1.0)    
}

var graphs: Array
var font: DynamicFont
var battery: Battery

var requested_power_w: float = 0.0
var current_out_i: float = 0.0
var out_power_w: float = 0.0

func load_default_font():
	font = DynamicFont.new()
	font.size = 18
	font.font_data = font_PixeloidSans

func setup_graphs(count: int):
	for i in range(count):
		var graph = GraphGenerator.new()
		graph.rect_size = Vector2(400, 150)
		graph.color = Color(0.2, 0.2, 0.2, 0.2)
		graph.custom_font = font
		graph.label_scale = 0.5
		graph.max_points = 3600
		graph.grid_lines_y = 5
		graph.y_label_step = 2
		graphs.append(graph)
		add_child(graph)

func _ready():
	battery = Battery.new()
	load_default_font()
	setup_graphs(7)
	
	graphs[0].rect_position = Vector2(0, 0)
	graphs[1].rect_position = Vector2(0, 160)
	graphs[2].rect_position = Vector2(0, 320)
	
	graphs[3].rect_position = Vector2(420, 0)
	graphs[4].rect_position = Vector2(420, 160)
	graphs[5].rect_position = Vector2(420, 320)
	
	graphs[6].rect_position = Vector2(840, 160)
	
	graphs[0].setup_line("T", Color(1.0, 1.0, 1.0))
	graphs[0].set_line_gradient("T", TemperatureGradient_scheme)
	graphs[0].use_fixed_min = true
	graphs[0].use_fixed_max = true
	graphs[0].fixed_min = -273.15
	graphs[0].fixed_max = 1538.0
	
	graphs[1].setup_line("Atm", Color(0.0, 0.5, 1.0))
	graphs[1].setup_line("Press", Color(1.0, 1.0, 0.0))
	graphs[1].setup_line("Vent", Color(1.0, 0.0, 0.0)) 
	
	graphs[2].setup_line("Heat", Color(1.0, 0.5, 0.0))
	graphs[2].setup_line("Cool", Color(0.0, 0.5, 1.0))
	
	graphs[3].setup_line("V_i", Color(0.5, 0.5, 0.5))
	graphs[3].setup_line("V_r", Color(1.0, 0.2, 0.2))
	graphs[3].setup_line("Ah", Color(0.0, 1.0, 0.0))
	
	graphs[4].setup_line("I_out", Color(0.2, 0.8, 1.0))
	graphs[4].setup_line("I_short", Color(1.0, 0.0, 0.0))
	
	graphs[5].setup_line("Req", Color(0.5, 0.5, 0.5))
	graphs[5].setup_line("Out", Color(0.0, 1.0, 0.0))
	
	graphs[6].setup_line("Health", Color(1.0, 0.0, 0.0))
	graphs[6].setup_line("SoC", Color(1.0, 1.0, 0.0))
	graphs[6].set_line_gradient("Health", HealthGradient_scheme)
	graphs[6].set_line_gradient("SoC", HealthGradient_scheme)
	graphs[6].use_fixed_min = true
	graphs[6].use_fixed_max = true
	graphs[6].fixed_min = 0.0
	graphs[6].fixed_max = 100.0

func power_request(delta: float, P: float) -> float:
	return battery.request(delta, P/max(0.001, battery.V))

func droccel_request(delta: float):
	var target_power = 850.0 
	
	var throttle_window_ideal = 0.5 
	var ideal_v = battery.get_v_ideal()
	var margin_ideal = ideal_v - battery.Voltage[0]
	var throttle_ideal = clamp(margin_ideal / throttle_window_ideal, 0.0, 1.0)
	
	var throttle_window_real = 0.5
	var margin_real = battery.V - 2.6
	var throttle_real = clamp(margin_real / throttle_window_real, 0.0, 1.0)
	
	var final_throttle = min(throttle_ideal, throttle_real)
	
	requested_power_w = target_power * final_throttle
	current_out_i = power_request(delta, -requested_power_w)
	out_power_w = abs(current_out_i * battery.V)

func save_data():
	var data: Dictionary = {}
	
	for i in range(graphs.size()):
		var keys = graphs[i].lines.keys()
		for id in range(keys.size()):
			data[keys[id]] = graphs[i].lines[keys[id]]["data"]
	
	var file = File.new()
	file.open("user://data.json", File.WRITE)
	file.store_string(to_json(data))
	
	file.close()

func _physics_process(delta):
	if false:
		if graphs[3].lines["T"]["data"].size() == 3600:
			save_data()
			get_tree().quit()
	droccel_request(delta)
	
	var v_ideal = battery.get_v_ideal()
	var g_short = battery.get_internal_conductance()
	var i_short = v_ideal * g_short 
	
	var p_ohmic = current_out_i * current_out_i * battery.get_r_actual()
	var p_short = i_short * i_short * (1.0 / max(0.001, g_short))
	var p_tr = battery.get_thermal_runaway_power()
	var heat_gen_w = p_ohmic + p_short + p_tr
	
	var cooling_ambient = (battery.T - battery.TAmbient) * battery.CoolingRate
	var cooling_boil = 0.0
	if battery.T > battery.BoilingPoint and battery.Liquid_Mass > 0.0:
		var safe_boil_T = min(battery.T, 200.0)
		var max_boil_rate = exp((safe_boil_T - battery.BoilingPoint) * 0.15) * 0.000001
		var actual_boiled = min(max_boil_rate * delta, battery.Liquid_Mass)
		cooling_boil = (actual_boiled / delta) * battery.HeatOfVaporization
	var total_cooling_w = cooling_ambient + cooling_boil

	graphs[0].append("T", battery.T)
	graphs[1].append("Atm", 101.3)
	graphs[1].append("Press", battery.Pressure / 1000.0)
	graphs[1].append("Vent", 2000.0)
	graphs[2].append("Heat", heat_gen_w)
	graphs[2].append("Cool", total_cooling_w)
	
	graphs[3].append("V_i", v_ideal)
	graphs[3].append("V_r", battery.V)
	graphs[3].append("Ah", battery.C)
	graphs[4].append("I_out", abs(current_out_i))
	graphs[4].append("I_short", i_short)
	graphs[5].append("Req", requested_power_w)
	graphs[5].append("Out", out_power_w)
	
	graphs[6].append("Health", battery.get_Health() * 100.0)
	graphs[6].append("SoC", battery.get_SoC() * 100.0)
