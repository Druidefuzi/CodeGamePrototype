extends CharacterBody2D

@export var start_state := "idle"

const JUMP_VELOCITY := -400.0
var stamina := 100.0
var user_script_instance: RefCounted = null
var state := "idle"

# --- deine Collisionboxen (idealerweise Area2D mit Monitoring) ---
@onready var left_collisionbox = $Left
@onready var right_collisionbox = $Right
@onready var danger_collisionbox =$Danger

# Flags für den Script-Code
var left_collision := false
var right_collision := false
var dangerous := false

# UI
var text_edit: TextEdit
var run_button: Button
var reset_button: Button
var stamina_bar: ProgressBar
var toggle_button: Button
var code_container: VBoxContainer
var error_label: Label

const SanitizerAuto = preload("res://sanitizer_auto.gd")
const ScriptLoaderAuto = preload("res://script_loader_auto.gd")

var user_code = """# Auto-Logik mit if/else
# Verfügbare Werte: left_collision, right_collision, dangerous, on_ground, stamina, state
# Verfügbare Aufrufe: idle(), walk_left(), walk_right(), jump()
# Optional: set_state_idle(), set_state_walk_left(), set_state_walk_right(), set_state_jump()
##Ergänze not vor start um die erste Bewegung zu starten.
# Beispiel:
if start():
	walk_right()
"""

var default_code = """# Standard-Logik: laufe nach rechts, pralle an Wänden ab; springe bei Gefahr
if dangerous and on_ground and stamina > 20:
	jump()
	walk_left()
elif right_collision:
	walk_left()
elif left_collision:
	walk_right()

"""

func _ready():
	state = start_state
	call_deferred("create_ui")
	load_user_script()

func create_ui():
	var canvas = CanvasLayer.new()
	get_parent().add_child(canvas)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = Vector2(420, 540)
	canvas.add_child(vbox)

	toggle_button = Button.new()
	toggle_button.text = "◄ Code Editor verstecken"
	toggle_button.custom_minimum_size = Vector2(200, 30)
	toggle_button.pressed.connect(_on_toggle_pressed)
	vbox.add_child(toggle_button)

	code_container = VBoxContainer.new()
	vbox.add_child(code_container)

	var label = Label.new()
	label.text = "Auto-Navigation (if/else; Aktionen: walk_left/right, idle, jump)"
	code_container.add_child(label)

	text_edit = TextEdit.new()
	text_edit.custom_minimum_size = Vector2(400, 360)
	text_edit.text = user_code
	text_edit.placeholder_text = "Schreib einfache if/else-Regeln hier..."
	code_container.add_child(text_edit)

	run_button = Button.new()
	run_button.text = "Run Code"
	run_button.custom_minimum_size = Vector2(100, 40)
	run_button.pressed.connect(_on_run_pressed)
	code_container.add_child(run_button)

	reset_button = Button.new()
	reset_button.text = "Reset"
	reset_button.custom_minimum_size = Vector2(100, 40)
	reset_button.pressed.connect(_on_reset_pressed)
	code_container.add_child(reset_button)

	error_label = Label.new()
	error_label.text = ""
	error_label.modulate = Color.RED
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	code_container.add_child(error_label)

	var stamina_label = Label.new()
	stamina_label.text = "Stamina:"
	vbox.add_child(stamina_label)

	stamina_bar = ProgressBar.new()
	stamina_bar.max_value = 100
	stamina_bar.value = stamina
	stamina_bar.custom_minimum_size = Vector2(200, 20)
	vbox.add_child(stamina_bar)

func _on_toggle_pressed():
	code_container.visible = !code_container.visible
	toggle_button.text = ("◄ Code Editor verstecken" if code_container.visible else "► Code Editor zeigen")

func _on_run_pressed():
	user_code = text_edit.text
	var preview := SanitizerAuto.sanitize_for_display(user_code)
	if preview != "":
		text_edit.text = preview
	load_user_script()
	if error_label and error_label.text == "":
		run_button.modulate = Color.GREEN
		await get_tree().create_timer(0.3).timeout
		run_button.modulate = Color.WHITE

func _on_reset_pressed():
	text_edit.text = default_code
	user_code = default_code
	load_user_script()
	if error_label:
		error_label.text = ""
	state = start_state

func load_user_script():
	var res := ScriptLoaderAuto.load_with_fallback(user_code, default_code)
	user_script_instance = res.instance

	match res.status:
		"user":
			if error_label: error_label.text = ""
		"default":
			if error_label: error_label.text = "⚠ Fehler im Code! Verwende Standard-Code als Fallback."
		"emergency":
			if error_label: error_label.text = "💀 System-Fehler! Notfall-Logik aktiv."

func _physics_process(delta: float) -> void:
	# --- Collision-Flags setzen (Area2D mit Monitoring vorausgesetzt) ---
	left_collision = _area_has_overlap(left_collisionbox)
	right_collision = _area_has_overlap(right_collisionbox)
	dangerous = _area_has_overlap(danger_collisionbox)

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 🔥 Hazard-Drain: in "dangerous" 20 Stamina pro Sekunde abziehen
	if dangerous:
		stamina -= 20.0 * delta
	else:
		# Nur regenerieren, wenn NICHT dangerous
		#if stamina < 100.0:
		#	stamina += 20.0 * delta
		pass

	var speed := 0
	var do_jump := false

	if user_script_instance:
		# run_logic(left_collision, right_collision, dangerous, stamina, on_ground, state)
		var result: Variant = user_script_instance.call(
			"run_logic", left_collision, right_collision, dangerous, stamina, is_on_floor(), state
		)
		if result and result is Array and result.size() == 2:
			speed = int(result[0])
			do_jump = bool(result[1])
			var new_state = user_script_instance.get("state")
			if typeof(new_state) == TYPE_STRING:
				state = new_state
		else:
			if error_label:
				error_label.text = "⚠ Laufzeit-Fehler! Verwende Standard-Code."
			var res := ScriptLoaderAuto.load_with_fallback(default_code, default_code)
			user_script_instance = res.instance

	# Jump-Kosten
	if do_jump and is_on_floor(): #and stamina >= 20.0:
		velocity.y = JUMP_VELOCITY
		#stamina -= 20.0

	# Laufkosten
	if abs(speed) > 0:
		velocity.x = speed
		#stamina -= abs(speed) * 0.1 * delta
	else:
		velocity.x = move_toward(velocity.x, 0, 300)

	# Grenzen
	stamina = clamp(stamina, 0.0, 100.0)

	# UI
	if stamina_bar:
		stamina_bar.value = stamina

	move_and_slide()

# --- Helper ---
func _area_has_overlap(area: Node) -> bool:
	if area == null:
		return false
	# Unterstütze sowohl Area2D als auch CollisionShape2D unter einer Area2D
	if area is Area2D:
		var bodies := (area as Area2D).get_overlapping_bodies()
		var areas := (area as Area2D).get_overlapping_areas()
		return bodies.size() > 0 or areas.size() > 0
	# Falls der Nutzer eine andere Node übergibt, nicht crashen:
	return false
