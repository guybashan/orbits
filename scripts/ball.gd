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
## Headroom kept below white on a ball that is home, so its texture survives
## the lights instead of blowing out.
const CORRECT_HEADROOM := 0.08

## Each colour slot is a real body whose dominant hue matches the slot, so the
## socket tint still does the matching and the planet is a second, redundant
## channel rather than a replacement for colour.
const PLANETS: Dictionary = {
	ColorType.CORAL: preload("res://assets/planets/coral_mars.png"),
	ColorType.MINT: preload("res://assets/planets/mint_uranus.png"),
	ColorType.AZURE: preload("res://assets/planets/azure_earth.png"),
	ColorType.AMBER: preload("res://assets/planets/amber_jupiter.png"),
	ColorType.VIOLET: preload("res://assets/planets/violet_neptune.png"),
}


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
		# Planet surfaces are matte; the old high metallic read as plastic once
		# there was a texture on them.
		_material.roughness = 0.78
		_material.metallic = 0.0
		# metallic_specular, not specular: the latter is a Godot 3 name that 4.x
		# only warns about, so this was silently doing nothing and spamming the
		# log once per ball.
		_material.metallic_specular = 0.18
		_material.rim_enabled = true
		# A strong rim put a white halo around every ball, which cost the
		# textures their contrast exactly where the sphere curves away.
		_material.rim = 0.18
		_material.rim_tint = 0.7
		_material.emission_enabled = true
		mesh_instance.material_override = _material

	_material.albedo_texture = PLANETS.get(color_type)
	# albedo_color multiplies the texture, so it is a shade rather than the hue:
	# tinting by the slot colour on top of the planet would double-tint it.
	_material.albedo_color = _albedo_shade()
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

	var target_emission := CORRECT_EMISSION if correct else IDLE_EMISSION
	var target_albedo := _albedo_shade()

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


## A ball that is not yet home sits slightly in shadow. With a texture this is
## a brightness change, not a hue change, so the planet stays recognisable.
func _albedo_shade() -> Color:
	if _is_correct:
		# Just under white. At full white, a ball that was home took the key and
		# fill lights straight into clipping and its planet bleached to a plain
		# disc — the balls that mattered most were the ones you could not read.
		return Color.WHITE.darkened(CORRECT_HEADROOM)
	return Color.WHITE.darkened(IDLE_DESATURATION)


func is_correct() -> bool:
	return _is_correct


## Staggered spawn so a new board assembles itself instead of just appearing.
func spawn_in(delay: float) -> void:
	scale = Vector3.ZERO
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "scale", Vector3.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
