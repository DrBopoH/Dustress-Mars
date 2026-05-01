extends Reference
class_name Battery

export var Capacity: float = 1.0
export var Voltage: Array = [3.0, 3.6, 4.1]
export var VoltageCurve: Array = [0.1, 0.2, 0.15]
export var Resistance: float = 0.02

export var TAmbient: float = 25.0
export var TCritical: float = 120.0
export var TIgnition: float = 200.0
export var TDegrade: float = 60.0
export var HeatCapacity: float = 50.0 
export var CoolingRate: float = 0.5

var _V_table: Array 
var _V_table_resolution: int = 1000

var C_stress: float = Capacity
var C: float = Capacity
var V: float = Voltage[-1]

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
		multiplier = clamp(multiplier, 0.0, 1.0)
		
		_V_table.append(multiplier)
		
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
	var idx_upper = int(ceil(exact_index))
	
	if idx_lower < 0: idx_lower = 0
	if idx_upper > _V_table_resolution: idx_upper = _V_table_resolution
	
	var weight = exact_index - float(idx_lower)
	var curve_multiplier = lerp(_V_table[idx_lower], _V_table[idx_upper], weight)
	
	return lerp(Voltage[0], Voltage[2], curve_multiplier)

func get_r_actual() -> float:
	var t_eff = clamp(T, -50.0, 40.0) 
	var t_kelvin = t_eff + 273.15
	var exponent = 3608.0 * (1.0 / t_kelvin - 1.0 / 298.15)
	var r_arrhenius = Resistance * exp(exponent)
	
	return max(Resistance * 0.5, r_arrhenius)

func _update_voltage(I_ext: float, I_int: float):
	if is_dead:
		V = 0.0
		return
		
	var r_act = get_r_actual()
	var v_ideal = get_v_ideal()
	
	v_ideal -= I_int * r_act
	
	V = max(0.0, v_ideal + I_ext * r_act) 

func _update_temp(t: float, I_ext: float, I_int: float):
	var P_heat = 0.0
	var P_cool = 0.0
	
	if not is_dead:
		var r_act = get_r_actual()
		
		P_heat += I_ext * I_ext * r_act
		
		if I_int > 0.0:
			var r_short = exp(-0.5 * (T - 140.0))
			P_heat += I_int * I_int * max(0.001, r_short)
		
		if T > 80.0:
			P_heat += 10.0 * exp(0.069 * (T - TCritical))
			
		P_cool = (T - TAmbient) * CoolingRate
		
		if T > TDegrade:
			C_stress = max(0.001, C_stress - (T - TDegrade) * 0.0001 * t)
			
		if T >= TIgnition:
			T += (C * 50000.0) / HeatCapacity
			is_dead = true
			C = 0.0
			C_stress = 0.0
	else:
		P_cool = (T - TAmbient) * (CoolingRate * 5.0)
		
	T += ((P_heat - P_cool) / HeatCapacity) * t

func request(t: float, I: float) -> float:
	if is_dead:
		_update_temp(t, 0.0, 0.0)
		_update_voltage(0.0, 0.0)
		return 0.0
	
	var r_act = get_r_actual()
	var max_discharge_amps = -(get_v_ideal() / max(0.0001, r_act))
	
	if I < max_discharge_amps: I = max_discharge_amps
	
	var t_h = t / 3600.0
	
	var I_int = 0.0
	if T > 130.0:
		var r_short = exp(-0.5 * (T - 140.0))
		I_int = get_v_ideal() / max(0.001, r_short)
		
	var c_drain_int = I_int * t_h
	if C >= c_drain_int:
		C -= c_drain_int
	else:
		I_int = C / t_h
		C = 0.0
		
	var current = C + I * t_h
	
	if current > C_stress:
		I = (C_stress - C) / t_h
		C = C_stress
	elif current <= 0.0:
		if I < 0.0 and C > 0.0:
			I = -(C / t_h)
		else:
			I = 0.0
		C = 0.0
	else: 
		C = current
	
	_update_temp(t, I, I_int)
	_update_voltage(I, I_int)
	
	if is_dead: return 0.0
	return I
