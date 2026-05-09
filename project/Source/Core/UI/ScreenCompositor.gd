class_name ScreenCompositor
extends Node

var layers: Dictionary

#func _ready() -> void:
#	for child in self.get_children():
#		self.layers[child.name] = self.bake_graph_recursively(child)



func print_composition_graph(
	composition_node: CompositionNode,
	regular_tree: String = '└── ',
	regular_middletree: String = '├── ',
	regular_branch: String = '│   ',
	regular_intent: String = '    ',
	regular: String = ''

) -> void:
	if composition_node.parent != null:
		var full_regular: String = regular
		var endl: String = ''
		
		if composition_node == composition_node.parent.childrens[-1]:
			full_regular += regular_tree
			
			if composition_node.parent.parent != null:
				if composition_node.parent != composition_node.parent.parent.childrens[-1]:
					endl = regular
			
			regular += regular_intent
		
		else:
			full_regular += regular_middletree
			regular += regular_branch
		
		print(full_regular, composition_node.name + "::" + str(composition_node.instance), " (" + composition_node.path_to_instance + ")")
		if endl != '': 
			print(endl)
	
	for child in composition_node.childrens:
		self.print_composition_graph(
			child,
			regular_tree,
			regular_middletree,
			regular_branch,
			regular_intent,
			regular
		)



func print_composition_layers(layers_list: Array) -> void:
	for layer in layers_list:
		print(layer)
		self.print_composition_graph(layers[layer])



func bake_graph_recursively(
	reference_node: Node, 
	parent_composition_node: CompositionNode = null

) -> CompositionNode:
	var composition_node = CompositionNode.new(reference_node, parent_composition_node)
	
	if parent_composition_node != null:
		parent_composition_node.childrens.append(composition_node)
	composition_node.path_to_instance = reference_node.get_filename()
	
	for child in reference_node.get_children():
		self.bake_graph_recursively(child, composition_node)
		composition_node.instance.queue_free()
	
	return composition_node
