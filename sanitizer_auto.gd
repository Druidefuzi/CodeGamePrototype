extends RefCounted
class_name SanitizerAuto

# ---- Whitelist ----
static func _is_allowed_identifier(id: String) -> bool:
	var allowed_vars := {
		# neue Namen
		"left_collision": true, "right_collision": true, "dangerous": true,
		# alte Synonyme
		"collision_left": true, "collision_right": true,
		# Status/Umgebungswerte
		"on_ground": true, "stamina": true, "state": true,
		# start (als Funktion genutzt)
		"start": true,
		# booleans
		"true": true, "false": true, "True": true, "False": true
	}
	var keywords := {"and": true, "or": true, "not": true}
	return allowed_vars.has(id) or keywords.has(id)

static func _looks_if(line: String) -> bool: return line.begins_with("if ") and line.ends_with(":")
static func _looks_elif(line: String) -> bool: return line.begins_with("elif ") and line.ends_with(":")
static func _looks_else(line: String) -> bool: return line == "else:"

# erlaubte Aufrufe ohne Argumente
static func _looks_call_noarg(line: String) -> bool:
	var allowed := {
		"idle()": true,
		"walk_left()": true, "walk_right()": true,
		"jump()": true,
		"start()": true,
		"set_state_idle()": true, "set_state_walk_left()": true,
		"set_state_walk_right()": true, "set_state_jump()": true
	}
	return allowed.has(line)

# expr nur mit erlaubten Bezeichnern?
static func _expr_ok(expr: String) -> bool:
	var re := RegEx.new()
	re.compile("[A-Za-z_][A-Za-z0-9_]*")
	for m in re.search_all(expr):
		var id := m.get_string()
		if not _is_allowed_identifier(id):
			return false
	return true

# ---------- Anzeige im TextEdit ----------
static func sanitize_for_display(raw_code: String) -> String:
	var clean := (raw_code if raw_code != null else "").strip_edges()
	var lines := clean.split("\n")

	var out: Array[String] = []
	var open_if := false
	var have_body := false

	for i in range(lines.size()):
		var trimmed := lines[i].strip_edges()

		# Autokorrektur: if start: -> if start():
		if trimmed == "if start:":
			trimmed = "if start():"

		if trimmed == "":
			continue

		var is_control := _looks_if(trimmed) or _looks_elif(trimmed) or _looks_else(trimmed)
		if is_control and open_if and not have_body:
			out.append("\tpass  # automatisch eingefügt")
			have_body = true

		if _looks_if(trimmed):
			var expr := trimmed.substr(3, trimmed.length() - 4).strip_edges()
			if _expr_ok(expr):
				out.append(trimmed)
				open_if = true
				have_body = false
			else:
				out.append("# INVALID IF: " + trimmed + "  # UNGÜLTIG!")
				open_if = false
				have_body = false
			continue

		if _looks_elif(trimmed):
			if open_if:
				var expr2 := trimmed.substr(5, trimmed.length() - 6).strip_edges()
				if _expr_ok(expr2):
					out.append(trimmed)
					have_body = false
				else:
					out.append("# INVALID ELIF: " + trimmed + "  # UNGÜLTIG!")
			else:
				out.append("# ORPHAN ELIF: " + trimmed + "  # UNGÜLTIG!")
			continue

		if _looks_else(trimmed):
			if open_if:
				out.append(trimmed)
				have_body = false
			else:
				out.append("# ORPHAN ELSE: " + trimmed + "  # UNGÜLTIG!")
			continue

		if trimmed.begins_with("#"):
			out.append(trimmed)
			continue

		if _looks_call_noarg(trimmed):
			if open_if:
				out.append("\t" + trimmed)   # 1× Tab für Anzeige im Block
				have_body = true
			else:
				out.append(trimmed)          # keine Extratabs auf Top-Level
			continue

		out.append("# INVALID: " + trimmed + "  # UNGÜLTIG!")

	if open_if and not have_body:
		out.append("\tpass  # automatisch eingefügt")

	return "\n".join(out)

# ---------- Ausführung ----------
static func sanitize_for_execution(raw_code: String) -> String:
	var clean := (raw_code if raw_code != null else "").strip_edges()
	var lines := clean.split("\n")

	var indented := ""
	var has_exec := false
	var open_if := false
	var have_body := false

	for i in range(lines.size()):
		var trimmed := lines[i].strip_edges()

		# Autokorrektur: if start: -> if start():
		if trimmed == "if start:":
			trimmed = "if start():"

		if trimmed == "":
			continue

		var is_control := _looks_if(trimmed) or _looks_elif(trimmed) or _looks_else(trimmed)
		if is_control and open_if and not have_body:
			indented += "\t\tpass\n"
			have_body = true

		if _looks_if(trimmed):
			var expr := trimmed.substr(3, trimmed.length() - 4).strip_edges()
			if _expr_ok(expr):
				indented += "\t" + trimmed + "\n"   # Top-Level in run_logic: 1× Tab
				open_if = true
				have_body = false
			else:
				indented += "\t# INVALID IF: " + trimmed + " # UNGÜLTIG!\n"
				open_if = false
				have_body = false
			continue

		if _looks_elif(trimmed):
			if open_if:
				var expr2 := trimmed.substr(5, trimmed.length() - 6).strip_edges()
				if _expr_ok(expr2):
					indented += "\t" + trimmed + "\n"
					have_body = false
				else:
					indented += "\t# INVALID ELIF: " + trimmed + " # UNGÜLTIG!\n"
			else:
				indented += "\t# ORPHAN ELIF: " + trimmed + " # UNGÜLTIG!\n"
			continue

		if _looks_else(trimmed):
			if open_if:
				indented += "\t" + trimmed + "\n"
				have_body = false
			else:
				indented += "\t# ORPHAN ELSE: " + trimmed + " # UNGÜLTIG!\n"
			continue

		if trimmed.begins_with("#"):
			indented += "\t" + trimmed + "\n"
			continue

		if _looks_call_noarg(trimmed):
			if open_if:
				indented += "\t\t" + trimmed + "\n"  # im Block: 2× Tabs
				have_body = true
			else:
				indented += "\t" + trimmed + "\n"    # Top-Level: 1× Tab
			has_exec = true
			continue

		indented += "\t# INVALID: " + trimmed + " # UNGÜLTIG!\n"

	if open_if and not have_body:
		indented += "\t\tpass\n"

	if not has_exec and indented.strip_edges() == "":
		indented += "\tpass\n"

	return indented
