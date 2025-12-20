extends Area3D

enum ColorType { NONE, RED, GREEN, BLUE, YELLOW }

@export var color_type: ColorType = ColorType.NONE:
	set(value):
		color_type = value
		_update_material()

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	_update_material()

func _update_material() -> void:
	if not mesh_instance:
		return
		
	var material = StandardMaterial3D.new()
	match color_type:
		ColorType.RED:
			material.albedo_color = Color.RED
		ColorType.GREEN:
			material.albedo_color = Color.GREEN
		ColorType.BLUE:
			material.albedo_color = Color.BLUE
		ColorType.YELLOW:
			material.albedo_color = Color.YELLOW
		_:
			material.albedo_color = Color.GRAY # Default/None
	
	mesh_instance.material_override = material
