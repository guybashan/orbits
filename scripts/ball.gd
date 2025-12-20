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
	material.roughness = 0.1
	material.metallic = 0.7
	material.emission_enabled = false
	material.rim_enabled = true
	material.rim = 0.5
	
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
			material.albedo_color = Color(0.3, 0.3, 0.3)
	
	mesh_instance.material_override = material
