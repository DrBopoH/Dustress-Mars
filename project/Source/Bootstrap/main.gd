extends ScreenCompositor

var mem_before_bake: int = 0
var nodes_before_bake: int = 0

func _input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		
		if event.button_index == BUTTON_LEFT:
			mem_before_bake = OS.get_static_memory_usage()
			nodes_before_bake = get_tree().get_node_count()
			
			var time_start = OS.get_ticks_usec()
			
			for child in self.get_children():
				self.layers[child.name] = self.bake_graph_recursively(child)
				
			var bake_time_ms = (OS.get_ticks_usec() - time_start) / 1000.0
			print("Бейк завершен за: ", bake_time_ms, " мс. Жми правую кнопку для проверки памяти.")
		
		elif event.button_index == BUTTON_RIGHT:
			var mem_after = OS.get_static_memory_usage()
			var nodes_after = get_tree().get_node_count()
			
			var mem_diff_mb = float(mem_before_bake - mem_after) / 1048576.0
			
			print("Ноды: ", nodes_before_bake, " -> ", nodes_after, " (Удалено: ", nodes_before_bake - nodes_after, ")")
			print("Память ДО: ", float(mem_before_bake) / 1048576.0, " MB")
			print("Память ПОСЛЕ: ", float(mem_after) / 1048576.0, " MB")
			
			if mem_diff_mb > 0:
				print("Освобождено: ", mem_diff_mb, " MB")
			else:
				print("Память выросла на: ", abs(mem_diff_mb), " MB (структуры графа весят больше, чем удаленные ноды)")
