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
export var R_polarization_ratio: float = 0.4 

export var FreeVolume: float = 0.00002
export var BoilingPoint: float = 90.0
export var HeatOfVaporization: float = 250000.0
export var GasConstant: float = 120.0

export var ElectrolyteMass: float = 0.005
var Liquid_Mass: float = ElectrolyteMass

var Pressure: float = 101325.0
var Vapor_Mass: float = 0.0
var CID_popped: bool = false

var _V_table: Array 
var _V_table_resolution: int = 1000

var C_stress: float = Capacity
var C: float = Capacity
var V: float = Voltage[-1]

var V_polarization: float = 0.0

var T: float = TAmbient
var is_dead: bool = false
var is_burning: bool = false
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
	var safe_T = min(T, 220.0) 
	return 1.0 * exp(0.08 * (safe_T - 80.0))

func get_degradation_rate(current_I: float) -> float:
	var cold_charge_damage = 0.0
	if current_I > 0.0 and T < 5.0:
		cold_charge_damage = current_I * abs(min(0.0, T - 5.0)) * 0.0001 
	
	var thermal_damage = 0.0
	if T > 60.0:
		thermal_damage = (exp((T - 60.0) * 0.08) - 1.0) * 0.000005
	
	var low_voltage_damage = 0.0
	if V < 2.5:
		low_voltage_damage = pow(2.5 - V, 2) * 0.001 
	
	var base_cycle_wear = abs(current_I) * 0.0000002
	var soc_stress_multiplier = 1.0 + pow(abs(0.5 - get_SoC()) * 2.0, 2) 
	var cycle_damage = base_cycle_wear * soc_stress_multiplier
	
	return thermal_damage + cold_charge_damage + low_voltage_damage + cycle_damage

func request(t_delta: float, I: float) -> float:
	if is_dead:
		V = 0.0
		T += (((T - TAmbient) * -CoolingRate * 5.0) / HeatCapacity) * t_delta
		return 0.0
	
	if CID_popped:
		I = 0.0
	
	var v_ideal = get_v_ideal()
	var r_total = get_r_actual()
	var r_ohmic = r_total * (1.0 - R_polarization_ratio)
	var r_pol = r_total * R_polarization_ratio
	
	var g_short = get_internal_conductance()
	var I_int = v_ideal * g_short
	
	if not CID_popped:
		var max_discharge_amps = -(v_ideal / max(0.0001, r_total))
		if I < max_discharge_amps: I = max_discharge_amps
	
	# 1. Потребление емкости (РАБОТАЕТ ВСЕГДА)
	var t_h = t_delta / 3600.0
	var total_drain = (I_int - I) * t_h 
	
	if C >= total_drain:
		C -= total_drain
	else:
		var available_I = C / t_h
		if I < 0.0: I = -available_I 
		C = 0.0
	
	if C > C_stress:
		I = (C_stress - C) / max(0.00001, t_h)
		C = C_stress
	
	C_stress = max(0.001, C_stress - get_degradation_rate(I) * t_delta)
	
	# 2. Тепло и горение
	var p_tr = get_thermal_runaway_power()
	
	if C <= 0.0:
		I_int = 0.0
		g_short = 0.001
		# ИСПРАВЛЕНО: p_tr = 0.0 УДАЛЕНО! Химия горит даже без заряда!
	
	var P_heat = (I * I * r_total) + (I_int * I_int * (1.0 / max(0.001, g_short))) + p_tr
	var P_cool = (T - TAmbient) * CoolingRate
	var P_boil = 0.0
	
	# 3. Термодинамика и Давление
	if T > BoilingPoint and Liquid_Mass > 0.0:
		var safe_boil_T = min(T, 200.0) 
		var max_boil_rate = exp((safe_boil_T - BoilingPoint) * 0.15) * 0.000001
		var actual_boiled = min(max_boil_rate * t_delta, Liquid_Mass)
		
		Liquid_Mass -= actual_boiled
		Vapor_Mass += actual_boiled
		P_boil = (actual_boiled / t_delta) * HeatOfVaporization
		
	# ИСПРАВЛЕНО: Давление считается по-разному до и после пробития клапана
	if not CID_popped:
		Pressure = 101325.0 + ((Vapor_Mass * GasConstant * (T + 273.15)) / FreeVolume)
		if Pressure > 2000000.0:
			CID_popped = true
			Vapor_Mass = 0.0 # Пшиииик!
	else:
		# Если клапан уже открыт, пар сразу улетает, давление падает
		Pressure = lerp(Pressure, 101325.0, 0.1)
		Vapor_Mass = 0.0 
	
	# Применяем температуру
	T += ((P_heat - P_cool - P_boil) / HeatCapacity) * t_delta
	
	if T >= 200.0 and not is_burning and not is_dead:
		is_burning = true
		
	if is_burning:
		var burn_speed = Capacity * 0.5 * t_delta 
		var actual_burn = min(C, burn_speed)
		
		C -= actual_burn
		T += (actual_burn * 50000.0) / HeatCapacity 
		
		if C <= 0.0:
			is_burning = false
			is_dead = true
			C_stress = 0.0
			C = 0.0
		
	# 4. Обновление напряжения
	var target_polarization = (I - I_int) * r_pol
	var alpha = 1.0 - exp(-t_delta / PolarizationTau)
	V_polarization = lerp(V_polarization, target_polarization, alpha)
	
	var instant_drop = (I - I_int) * r_ohmic 
	
	if not CID_popped:
		V = max(0.0, v_ideal + instant_drop + V_polarization)
	else:
		V = 0.0
		
	return I
