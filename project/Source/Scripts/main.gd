extends Node

var font_alagard = preload("res://Assets/alagard-12px-unicode.ttf")
var font_PixeloidSans = preload("res://Assets/PixeloidSans-mLxMm.ttf")

var HealthGradient_scheme = {
	0.0: Color.red,
	0.5: Color.yellow,
	1.0: Color.green
}

var TemperatureGradient_scheme = {
	0.000: Color(0.0, 0.0, 0.5), # -273.15°C (Абсолютный ноль)
	0.282: Color(0.0, 0.8, 1.0), # -10.0°C (Холод)
	0.293: Color(0.7, 0.9, 1.0), # 0.0°C (Замерзание воды)
	0.319: Color(1.0, 1.0, 1.0), # 25.0°C (Комнатная температура - старт)
	0.400: Color(0.3, 0.0, 0.0), # 100.0°C (Кипение воды)
	0.421: Color(0.5, 0.0, 0.0), # 120.0°C (TCritical - старт теплового разгона)
	0.507: Color(0.8, 0.0, 0.0), # 200.0°C (TIgnition - точка воспламенения электролита)
	0.700: Color(1.0, 0.0, 0.0), # 380.0°C (Активное горение)
	0.855: Color(1.0, 0.5, 0.0), # 525.0°C (Точка Дрейпера - начало видимого красного свечения)
	1.000: Color(1.0, 1.0, 0.0)  # 660.3°C (Плавление алюминиевого корпуса/контактов)
}

var graphs: Array
var font: DynamicFont

var battery: Battery

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
	setup_graphs(4)
	
	graphs[0].setup_line("Ah", Color.green)
	graphs[0].setup_line("V", Color.red)
	
	graphs[1].setup_line("I", Color.blue)
	graphs[1].rect_position = Vector2(0, 150)
	
	graphs[2].setup_line("SoC", Color.yellow)
	graphs[2].set_line_gradient("SoC", HealthGradient_scheme)
	graphs[2].setup_line("Health", Color.red)
	graphs[2].set_line_gradient("Health", HealthGradient_scheme)
	graphs[2].rect_position = Vector2(450, 0)
	graphs[2].use_fixed_min = true
	graphs[2].use_fixed_max = true
	
	graphs[3].setup_line("T", Color.red)
	graphs[3].set_line_gradient("T", TemperatureGradient_scheme)
	graphs[3].rect_position = Vector2(450, 150)
	graphs[3].use_fixed_min = true
	graphs[3].use_fixed_max = true
	graphs[3].fixed_min = -273.15
	graphs[3].fixed_max = 660.3

func power_request(delta: float, P: float) -> float:
	return battery.request(delta, P/max(0.001, battery.V))

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
	
	var requested_power = target_power * final_throttle

	graphs[1].append("I", power_request(delta, -requested_power))

func _physics_process(delta):
	if false:
		if graphs[3].lines["T"]["data"].size() == 3600:
			save_data()
			get_tree().quit()
	
	graphs[0].append("Ah", battery.C)
	graphs[0].append("V", battery.V)
	
	#droccel_request(delta)
	graphs[1].append("I", power_request(delta, -850))
	
	graphs[2].append("Health", battery.get_Health()*100)
	graphs[2].append("SoC", battery.get_SoC()*100)
	
	graphs[3].append("T", battery.T)
	
	
