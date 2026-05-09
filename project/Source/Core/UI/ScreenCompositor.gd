class_name ScreenCompositor
extends Node

var layers: Dictionary

func _ready() -> void:
	for child in get_children():
		layers[child.name] = bake_graph_recursively(child)
	
	print_composition_layers(layers.keys())



func print_composition_layers(layers_list: Array):
func print_composition_layers(layers_list: Array) -> void:
	for layer in layers:
		print(layer)
		print_composition_graph(layers[layer])



func print_composition_graph(composition_node: CompositionNode, depth: int = 0, reg: String = ' |_ '):
	if composition_node.parent != null:
		print(reg.repeat(depth), composition_node.name, ": (" + composition_node.instance + ")")
	
	for child in composition_node.childrens:
		print_composition_graph(child, depth + 1)



func get_scene_path_from_node(reference_node: Node) -> String:
	if reference_node == null: return ''
	
	return reference_node.get_filename()



func bake_graph_recursively(reference_node: Node, parent_composition_node: CompositionNode = null) -> CompositionNode:
	var composition_node := CompositionNode.new(reference_node.name, parent_composition_node)
	
	composition_node.instance = get_scene_path_from_node(reference_node)
	
	if parent_composition_node != null:
		composition_node.parent = parent_composition_node
		parent_composition_node.childrens.append(composition_node)
	
	for child in reference_node.get_children():
		bake_graph_recursively(child, composition_node)
	
	return composition_node
