extends CharacterBody2D

const JUMP_VELOCITY = -400.0
var stamina = 100.0
var user_script_instance = null

var text_edit: TextEdit
var run_button: Button
var reset_button: Button
var stamina_bar: ProgressBar
var toggle_button: Button
var code_container: VBoxContainer
var error_label: Label

const Sanitizer = preload("res://global/sanitizer.gd")
const ScriptLoader = preload("res://script_loader.gd")

var user_code = """# Bewegungs-Logik (einfach mit if/else schreiben!)
# Verfügbare Werte: left_pressed, right_pressed, jump_pressed, stamina, on_ground

if right_pressed and stamina > 10:
	move_right_fast()

if left_pressed and stamina > 10:
	move_left_fast()

if right_pressed and stamina <= 10:
	move_right_slow()

if left_pressed and stamina <= 10:
	move_left_slow()

# Sprung-Logik
if jump_pressed and on_ground and stamina > 20:
	jump()
"""

var default_code = """# Bewegungs-Logik (einfach mit if/else schreiben!)
# Verfügbare Werte: left_pressed, right_pressed, jump_pressed, stamina, on_ground

if right_pressed and stamina > 10:
	move_right_fast()

if left_pressed and stamina > 10:
	move_left_fast()

if right_pressed and stamina <= 10:
	move_right_slow()

if left_pressed and stamina <= 10:
	move_left_slow()

# Sprung-Logik
if jump_pressed and on_ground and stamina > 20:
	jump()
"""

func _ready():
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
	label.text = "Programmier den Charakter (einfache if/else Befehle):"
	code_container.add_child(label)

	text_edit = TextEdit.new()
	text_edit.custom_minimum_size = Vector2(400, 360)
	text_edit.text = user_code
	text_edit.placeholder_text = "Schreib einfach if/else Logik hier..."
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
	if code_container.visible:
		toggle_button.text = "◄ Code Editor verstecken"
	else:
		toggle_button.text = "► Code Editor zeigen"

func _on_run_pressed():
	user_code = text_edit.text
	var preview := Sanitizer.sanitize_for_display(user_code)
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

func load_user_script():
	var res := ScriptLoader.load_with_fallback(user_code, default_code)
	user_script_instance = res.instance

	match res.status:
		"user":
			if error_label: error_label.text = ""
		"default":
			if error_label: error_label.text = "⚠ Fehler im Code! Verwende Standard-Code als Fallback."
		"emergency":
			if error_label: error_label.text = "💀 System-Fehler! Neustart erforderlich."

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if stamina < 100:
		stamina += 20 * delta

	var left = Input.is_action_pressed("ui_left")
	var right = Input.is_action_pressed("ui_right")
	var jump = Input.is_action_just_pressed("ui_accept")

	var speed = 0
	var do_jump = false

	if user_script_instance:
		var result = user_script_instance.call("run_logic", left, right, jump, stamina, is_on_floor())
		if result and result is Array and result.size() == 2:
			speed = int(result[0])
			do_jump = bool(result[1])
		else:
			if error_label:
				error_label.text = "⚠ Laufzeit-Fehler! Verwende Standard-Code."
			var res := ScriptLoader.load_with_fallback(default_code, default_code)
			user_script_instance = res.instance

	if do_jump:
		velocity.y = JUMP_VELOCITY
		stamina -= 20

	if abs(speed) > 0:
		velocity.x = speed
		stamina -= abs(speed) * 0.1 * delta
	else:
		velocity.x = move_toward(velocity.x, 0, 300)

	stamina = clamp(stamina, 0, 100)

	if stamina_bar:
		stamina_bar.value = stamina

	move_and_slide()
