class_name ScreenCompositor
extends Node

var layers: Dictionary

func _ready():
	for child in get_children():
		layers[child.name] = bake_graph_recursively(child)
	
	print_composition_layers(layers.keys())



func print_composition_layers(layers_list: Array):
	for layer in layers:
		print(layer)
		print_composition_graph(layers[layer])



func print_composition_graph(composition_node: CompositionNode, depth: int = 0):
	var tab: String
	for i in range(depth): tab += " |_ "
	
	if composition_node.parent != null:
		print(tab, composition_node.name)
	
	for child in composition_node.childrens:
		print_composition_graph(child, depth + 1)



func bake_graph_recursively(reference_node: Node, parent_composition_node: CompositionNode = null) -> CompositionNode:
	var next := CompositionNode.new(reference_node.name, parent_composition_node)
	
	if parent_composition_node != null:
		next.parent = parent_composition_node
		parent_composition_node.childrens.append(next)
	
	for child in reference_node.get_children():
		bake_graph_recursively(child, next)
	
	return next
