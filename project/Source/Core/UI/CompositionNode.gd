class_name CompositionNode

var name: String
var parent: CompositionNode
var childrens: Array = []

var path_to_instance: String
var instance: Node



func _init(reference: Node, parent: CompositionNode = null) -> void:
	self.name = reference.name
	self.instance = reference
	self.parent = parent
