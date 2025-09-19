extends RefCounted
class_name ScriptLoaderAuto

const SanitizerAuto = preload("res://sanitizer_auto.gd")

# Fallback-Implementierung, falls alles scheitert
class EmergencyAutoScript:
	var state := "idle"
	var RUN_LOGIC_ARGC := 6
	var _first_frame := true

	func start() -> bool:
		if _first_frame:
			_first_frame = false
			return true
		return false

	func run_logic(c_left, c_right, c_danger, s, floor, st):
		state = st
		var movement_speed := 0
		var should_jump := false

		if start():
			state = "walk_right"
			movement_speed = 200
		elif c_left:
			movement_speed = 200
			state = "walk_right"
		elif c_right:
			movement_speed = -200
			state = "walk_left"
		elif c_danger and floor and s > 20:
			should_jump = true
			state = "jump"
		else:
			movement_speed = 200
			state = "walk_right"

		return [movement_speed, should_jump]

static func _compile_from_code(code_to_load: String) -> RefCounted:
	var indented_code := SanitizerAuto.sanitize_for_execution(code_to_load)

	var full_script := """extends RefCounted

const RUN_LOGIC_ARGC = 6

# Eingangsflags (werden pro Lauf gesetzt)
var left_collision = false
var right_collision = false
var dangerous = false
var on_ground = true
var stamina = 100
var state = "idle"

# Ausgabe
var movement_speed = 0
var should_jump = false

# nur im ersten Frame true
var _first_frame = true
func start() -> bool:
	if _first_frame:
		_first_frame = false
		return true
	return false

func run_logic(c_left, c_right, c_danger, s, floor, current_state):
	left_collision = c_left
	right_collision = c_right
	dangerous = c_danger
	stamina = s
	on_ground = floor
	state = str(current_state)
	movement_speed = 0
	should_jump = false

	# Rückwärtskompatible Synonyme
	var collision_left = left_collision
	var collision_right = right_collision

""" + indented_code + """

	return [movement_speed, should_jump]

# Aktionen: setzen Speed + State
func idle():
	movement_speed = 0
	state = "idle"

func walk_left():
	movement_speed = -200
	state = "walk_left"

func walk_right():
	movement_speed = 200
	state = "walk_right"

func jump():
	should_jump = true

# optionale State-Setter
func set_state_idle(): state = "idle"
func set_state_walk_left(): state = "walk_left"
func set_state_walk_right(): state = "walk_right"
func set_state_jump(): state = "jump"
"""

	var gd := GDScript.new()
	gd.source_code = full_script
	var err := gd.reload()
	if err != OK:
		return null

	var inst = gd.new()
	if inst == null:
		return null

	var result: Variant = inst.call("run_logic", false, false, false, 100, true, "idle")
	if result == null or not result is Array or result.size() != 2:
		return null

	return inst

# Versucht: user_code → default_code → Emergency
# Rückgabe: { "instance": RefCounted, "status": "user"|"default"|"emergency" }
static func load_with_fallback(user_code: String, default_code: String) -> Dictionary:
	var inst := _compile_from_code(user_code)
	if inst:
		return {"instance": inst, "status": "user"}

	inst = _compile_from_code(default_code)
	if inst:
		return {"instance": inst, "status": "default"}

	return {"instance": EmergencyAutoScript.new(), "status": "emergency"}
