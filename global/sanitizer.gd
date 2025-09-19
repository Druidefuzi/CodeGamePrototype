extends RefCounted
class_name Sanitizer

static func _is_allowed_identifier(id: String) -> bool:
	var allowed_vars := {
		"left_pressed": true, "right_pressed": true, "jump_pressed": true,
		"stamina": true, "on_ground": true, "true": true, "false": true,
		"True": true, "False": true
	}
	var keywords := {"and": true, "or": true, "not": true}
	return allowed_vars.has(id) or keywords.has(id)

static func _expr_contains_only_allowed_identifiers(expr: String) -> bool:
	var re := RegEx.new()
	re.compile("[A-Za-z_][A-Za-z0-9_]*")
	for m in re.search_all(expr):
		var id := m.get_string()
		if not _is_allowed_identifier(id):
			return false
	return true

static func _looks_if(line: String) -> bool: return line.begins_with("if ") and line.ends_with(":")
static func _looks_elif(line: String) -> bool: return line.begins_with("elif ") and line.ends_with(":")
static func _looks_else(line: String) -> bool: return line == "else:"
static func _looks_call(line: String) -> bool:
	var allowed_calls := {
		"move_right_fast()": true, "move_right_slow()": true,
		"move_left_fast()": true, "move_left_slow()": true,
		"jump()": true
	}
	return allowed_calls.has(line)

static func sanitize_for_display(raw_code: String) -> String:
	var clean_code := (raw_code if raw_code != null else "").strip_edges()
	var lines := clean_code.split("\n")
	var out: Array[String] = []
	var open_if := false
	var have_body := false
	for i in range(lines.size()):
		var trimmed := lines[i].strip_edges()
		if trimmed == "":
			continue
		var is_control := _looks_if(trimmed) or _looks_elif(trimmed) or _looks_else(trimmed)
		if is_control and open_if and not have_body:
			out.append("\tpass  # automatisch eingefügt")
			have_body = true
		if _looks_if(trimmed):
			var expr := trimmed.substr(3, trimmed.length() - 4).strip_edges()
			if _expr_contains_only_allowed_identifiers(expr):
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
				if _expr_contains_only_allowed_identifiers(expr2):
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
		if _looks_call(trimmed):
			if open_if:
				out.append("\t" + trimmed)
				have_body = true
			else:
				out.append(trimmed)
			continue
		out.append("# INVALID: " + trimmed + "  # UNGÜLTIG!")
	if open_if and not have_body:
		out.append("\tpass  # automatisch eingefügt")
	return "\n".join(out)

static func sanitize_for_execution(raw_code: String) -> String:
	var clean_code := (raw_code if raw_code != null else "").strip_edges()
	var lines := clean_code.split("\n")
	var indented := ""
	var has_exec := false
	var open_if := false
	var have_body := false
	for i in range(lines.size()):
		var trimmed := lines[i].strip_edges()
		if trimmed == "":
			continue
		var is_control := _looks_if(trimmed) or _looks_elif(trimmed) or _looks_else(trimmed)
		if is_control and open_if and not have_body:
			indented += "\t\tpass\n"
			have_body = true
		if _looks_if(trimmed):
			var expr := trimmed.substr(3, trimmed.length() - 4).strip_edges()
			if _expr_contains_only_allowed_identifiers(expr):
				indented += "\t" + trimmed + "\n"
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
				if _expr_contains_only_allowed_identifiers(expr2):
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
		if _looks_call(trimmed):
			if open_if:
				indented += "\t\t" + trimmed + "\n"
				have_body = true
			else:
				indented += "\t\t" + trimmed + "\n"
			has_exec = true
			continue
		indented += "\t# INVALID: " + trimmed + " # UNGÜLTIG!\n"
	if open_if and not have_body:
		indented += "\t\tpass\n"
	if not has_exec and indented.strip_edges() == "":
		indented += "\tpass\n"
	return indented
