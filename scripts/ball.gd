class_name Ball
extends Node3D

enum ColorType { NONE, CORAL, MINT, AZURE, AMBER, VIOLET }

## Shared palette. Kept here so the 2D goal preview and the 3D board can never
## drift apart.
const PALETTE: Dictionary = {
	ColorType.CORAL: Color(1.00, 0.35, 0.42),
	ColorType.MINT: Color(0.24, 0.85, 0.70),
	ColorType.AZURE: Color(0.34, 0.60, 1.00),
	ColorType.AMBER: Color(1.00, 0.76, 0.24),
	ColorType.VIOLET: Color(0.72, 0.45, 1.00),
}

## Emission is kept low deliberately: with bloom on, anything much higher
## washes the ball out to white and the player loses the colour they are
## matching. The "this one is home" signal is carried mostly by the socket
## ring underneath and by the ball's albedo going from muted to full.
const IDLE_EMISSION := 0.10
const CORRECT_EMISSION := 0.34
const IDLE_DESATURATION := 0.30


static func color_for(color_type_value: int) -> Color:
	return PALETTE.get(color_type_value, Color(0.35, 0.38, 0.45))


@export var color_type: int = ColorType.NONE:
	set(value):
		color_type = value
		_apply_material()

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _material: StandardMaterial3D
var _is_correct := false
var _glow_tween: Tween


func _ready() -> void:
	_apply_material()


func _apply_material() -> void:
	if not is_inside_tree():
		return
	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance == null:
		return

	var base := color_for(color_type)

	if _material == null:
		_material = StandardMaterial3D.new()
		_material.roughness = 0.25
		_material.metallic = 0.35
		_material.rim_enabled = true
		_material.rim = 0.75
		_material.rim_tint = 0.4
		_material.emission_enabled = true
		mesh_instance.material_override = _material

	_material.albedo_color = base if _is_correct else base.darkened(IDLE_DESATURATION)
	_material.emission = base
	_material.emission_energy_multiplier = CORRECT_EMISSION if _is_correct else IDLE_EMISSION


## Lit up when the ball sits where the goal pattern wants it. This is the
## game's main feedback channel — without it the player is comparing two grids
## by eye on every single move.
func set_correct(correct: bool, animate: bool = true) -> void:
	if correct == _is_correct:
		return
	_is_correct = correct

	if _material == null:
		_apply_material()
		return

	var base := color_for(color_type)
	var target_emission := CORRECT_EMISSION if correct else IDLE_EMISSION
	var target_albedo := base if correct else base.darkened(IDLE_DESATURATION)

	if not animate:
		_material.emission_energy_multiplier = target_emission
		_material.albedo_color = target_albedo
		return

	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.set_parallel(true)
	_glow_tween.tween_property(_material, "emission_energy_multiplier", target_emission, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(_material, "albedo_color", target_albedo, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if correct:
		var pop := create_tween()
		pop.tween_property(self, "scale", Vector3.ONE * 1.10, 0.09) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_property(self, "scale", Vector3.ONE, 0.22) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func is_correct() -> bool:
	return _is_correct


## Staggered spawn so a new board assembles itself instead of just appearing.
func spawn_in(delay: float) -> void:
	scale = Vector3.ZERO
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "scale", Vector3.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
