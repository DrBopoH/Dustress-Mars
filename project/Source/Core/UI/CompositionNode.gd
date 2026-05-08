class_name CompositionNode

var name: String
var instance: String
var parent: CompositionNode
var childrens: Array = []
#var shared_layers: Array = []
#var scene
#var cache_policy

func _init(_name: String, _parent: CompositionNode = null):
	name = _name
	parent = parent
