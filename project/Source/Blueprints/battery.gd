extends Reference
class_name Battery

export var Capacity: float = 1.0
export var Voltage: Array = [3.0, 3.6, 4.1]
export var VoltageCurve: Array = [0.1, 0.2, 0.15]

export var R_base: float = 0.02
export var HeatCapacity: float = 50.0 
export var CoolingRate: float = 0.5
export var TAmbient: float = 25.0

export var PolarizationTau: float = 2.0 

var _V_table: Array 
var _V_table_resolution: int = 1000

var C_stress: float = Capacity
var C: float = Capacity
var V: float = Voltage[-1]

var V_polarization: float = 0.0

var T: float = TAmbient
var is_dead: bool = false
var ln_treshhold: float = 4.605

func _init():
	_bake_shepherd_curve()
	
func _bake_shepherd_curve():
	_V_table = []
	var a = Voltage[2] - Voltage[1]
	var k_drop = (Voltage[1] - Voltage[0]) - VoltageCurve[1]
	var b = ln_treshhold/VoltageCurve[2]
	var c = ln_treshhold/VoltageCurve[0]
	for i in range(_V_table_resolution + 1):
		var soc = float(i)/float(_V_table_resolution) 
		var term_linear = VoltageCurve[1]*(1.0 - soc)
		var term_exp_top = a*exp(-b*(1.0 - soc))
		var term_exp_bot = k_drop*exp(-c*soc)
		var v_calc = Voltage[1] - term_linear + term_exp_top - term_exp_bot
		var multiplier = (v_calc - Voltage[0]) / (Voltage[2] - Voltage[0])
		_V_table.append(clamp(multiplier, 0.0, 1.0))
	_V_table[0] = 0.0
	_V_table[_V_table_resolution] = 1.0

func get_SoC() -> float:
	return C / max(0.0001, C_stress)

func get_Health() -> float:
	return C_stress / Capacity

func get_v_ideal() -> float:
	var soc = clamp(get_SoC(), 0.0, 1.0)
	var exact_index = soc * float(_V_table_resolution)
	var idx_lower = int(floor(exact_index))
	var curve_multiplier = lerp(_V_table[idx_lower], _V_table[min(idx_lower + 1, _V_table_resolution)], exact_index - float(idx_lower))
	return lerp(Voltage[0], Voltage[2], curve_multiplier)

func get_r_actual() -> float:
	var t_eff = clamp(T, -50.0, 40.0) 
	var exponent = 3608.0 * (1.0 / (t_eff + 273.15) - 1.0 / 298.15)
	return max(R_base * 0.5, R_base * exp(exponent))

func get_internal_conductance() -> float:
	return 100.0 / (1.0 + exp(-0.15 * (T - 135.0)))

func get_thermal_runaway_power() -> float:
	return 0.02 * exp(0.08 * (T - 80.0))

func get_degradation_rate() -> float:
	return pow(max(0.0, T - 60.0), 2) * 0.000005


func request(t_delta: float, I: float) -> float:
	if is_dead:
		V = 0.0
		T += (((T - TAmbient) * -CoolingRate * 5.0) / HeatCapacity) * t_delta
		return 0.0
		
	var v_ideal = get_v_ideal()
	var r_act = get_r_actual()
	
	var g_short = get_internal_conductance()
	var I_int = v_ideal * g_short
	
	var max_discharge_amps = -(v_ideal / max(0.0001, r_act))
	if I < max_discharge_amps: I = max_discharge_amps
	
	var t_h = t_delta / 3600.0
	
	var total_drain = (I_int - I) * t_h
	
	if C >= total_drain:
		C -= total_drain
	else:
		I_int = C / t_h
		if I < 0.0: I = -I_int
		C = 0.0
		
	if C > C_stress:
		I = (C_stress - C) / t_h
		C = C_stress
		
	C_stress = max(0.001, C_stress - get_degradation_rate() * t_delta)
	
	var P_heat = (I * I * r_act) + (I_int * I_int * (1.0 / max(0.001, g_short))) + get_thermal_runaway_power()
	var P_cool = (T - TAmbient) * CoolingRate
	T += ((P_heat - P_cool) / HeatCapacity) * t_delta
	
	if T >= 200.0:
		T += (C * 50000.0) / HeatCapacity
		is_dead = true
		C = 0.0
		C_stress = 0.0
		
	var target_polarization = I * r_act - I_int * r_act
	V_polarization = lerp(V_polarization, target_polarization, clamp(t_delta / PolarizationTau, 0.0, 1.0))
	
	V = max(0.0, v_ideal + V_polarization)
	
	return I
