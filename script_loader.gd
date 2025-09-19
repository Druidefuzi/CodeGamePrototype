extends RefCounted
class_name ScriptLoader

const Sanitizer = preload("res://global/sanitizer.gd")

# Notfall-Implementierung, falls alles scheitert
class EmergencyUserScript:
	func run_logic(l, r, j, s, floor):
		var speed := 0
		if r and s > 10:
			speed = 200
		elif l and s > 10:
			speed = -200
		var should_jump = j and floor and s > 20
		return [speed, should_jump]

static func _compile_from_code(code_to_load: String) -> RefCounted:
	var indented_code := Sanitizer.sanitize_for_execution(code_to_load)

	var full_script := """extends RefCounted

var left_pressed = false
var right_pressed = false
var jump_pressed = false
var stamina = 100
var on_ground = true
var movement_speed = 0
var should_jump = false

func run_logic(l, r, j, s, floor):
	left_pressed = l
	right_pressed = r
	jump_pressed = j
	stamina = s
	on_ground = floor
	movement_speed = 0
	should_jump = false

""" + indented_code + """

	return [movement_speed, should_jump]

func move_right_fast():
	movement_speed = 300
func move_right_slow():
	movement_speed = 150
func move_left_fast():
	movement_speed = -300
func move_left_slow():
	movement_speed = -150
func jump():
	should_jump = true
"""

	var gd := GDScript.new()
	gd.source_code = full_script
	var err := gd.reload()
	if err != OK:
		return null

	var inst = gd.new()
	if inst == null:
		return null

	var result = inst.call("run_logic", false, false, false, 100, true)
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

	return {"instance": EmergencyUserScript.new(), "status": "emergency"}
