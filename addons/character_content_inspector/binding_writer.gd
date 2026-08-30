@tool
extends RefCounted

# Minimal-diff edits to a character presentation .tres.
#
# ResourceSaver.save() cannot be used here. Saving a presentation resource
# unchanged rewrites all of it: every ext_resource id is randomised, entries
# appear for binding types the file does not use, and the document is reordered.
# A one-line binding change would arrive as an unreviewable diff whose ids differ
# again on the next save, in the one file art, balance, skill, and frontend
# contributors all touch.
#
# So these are string transforms that touch only what they must:
#   rebind      -> one changed line
#   add_binding -> one inserted sub-resource block, one array entry, load_steps
#
# They refuse rather than guess whenever the file does not match the shape they
# expect. Both are pure: the input string is never mutated, and callers decide
# whether to write the result.

const BINDING_SCRIPT := "res://presentation/data/move_presentation_binding.gd"

static func rebind(text: String, move_id: StringName, animation_key: StringName) -> Dictionary:
    var block := _binding_block(text, move_id)
    if block.is_empty():
        return _failure("no unconditional binding for move '%s'" % String(move_id))
    if block["conditioned"]:
        return _failure("move '%s' is bound through resource-conditioned variants; edit those by hand" % String(move_id))
    var line_index: int = block["animation_line"]
    if line_index < 0:
        return _failure("binding for move '%s' has no animation_key line" % String(move_id))
    var lines := text.split("\n")
    lines[line_index] = 'animation_key = &"%s"' % String(animation_key)
    return _success("\n".join(lines))

static func add_binding(text: String, move_id: StringName, animation_key: StringName) -> Dictionary:
    if not _binding_block(text, move_id).is_empty():
        return _failure("move '%s' already has a binding; rebind it instead" % String(move_id))
    var script_id := _ext_resource_id(text, BINDING_SCRIPT)
    if script_id.is_empty():
        return _failure("no ext_resource for move_presentation_binding.gd")
    var lines := text.split("\n")
    var array_index := _line_starting_with(lines, "move_bindings = ")
    if array_index < 0:
        return _failure("no move_bindings array")
    var resource_index := _line_starting_with(lines, "[resource]")
    if resource_index < 0:
        return _failure("no [resource] section")

    var sub_id := "Move_%s" % String(move_id)
    if text.contains('id="%s"' % sub_id):
        return _failure("sub-resource id '%s' is already taken" % sub_id)

    # Insert immediately before [resource] so the block sits with its peers and
    # nothing already in the file moves relative to anything else.
    var insert_at := resource_index
    while insert_at > 0 and lines[insert_at - 1].strip_edges().is_empty():
        insert_at -= 1

    var block := PackedStringArray([
        '[sub_resource type="Resource" id="%s"]' % sub_id,
        'script = ExtResource("%s")' % script_id,
        'move_id = &"%s"' % String(move_id),
        'animation_key = &"%s"' % String(animation_key),
    ])

    var updated := PackedStringArray()
    for index in range(lines.size()):
        if index == insert_at:
            updated.append_array(block)
        var line := lines[index]
        if index == array_index:
            line = _append_to_array(line, sub_id)
            if line.is_empty():
                return _failure("move_bindings array is not in the expected form")
        if index == 0:
            line = _bump_load_steps(line)
            if line.is_empty():
                return _failure("resource header has no load_steps")
        updated.append(line)
    return _success("\n".join(updated))

# --- inspection --------------------------------------------------------------

# Returns {} when the move has no binding block at all. `conditioned` reports a
# variant binding, which this writer will not touch.
static func _binding_block(text: String, move_id: StringName) -> Dictionary:
    var lines := text.split("\n")
    var target := 'move_id = &"%s"' % String(move_id)
    var found := false
    var unconditional_line := -1
    var conditioned := false
    for index in range(lines.size()):
        if lines[index].strip_edges() != target:
            continue
        if not _inside_move_binding(lines, index):
            continue
        found = true
        var animation_line := -1
        var block_conditioned := false
        var cursor := index + 1
        while cursor < lines.size() and not lines[cursor].begins_with("["):
            var line := lines[cursor].strip_edges()
            if line.begins_with("animation_key = "):
                animation_line = cursor
            elif line.begins_with("resource_id = ") and not line.ends_with('&""'):
                block_conditioned = true
            cursor += 1
        # A move can own several blocks: one fallback plus resource-conditioned
        # variants. Editing any of them in isolation would silently change which
        # one wins, so the whole group is refused if any block is conditioned.
        if block_conditioned:
            conditioned = true
        elif unconditional_line < 0:
            unconditional_line = animation_line
    if not found:
        return {}
    return {"animation_line": unconditional_line, "conditioned": conditioned}

# A move_id line only counts when it belongs to a move binding sub-resource:
# projectile and effect blocks carry a move_id too.
static func _inside_move_binding(lines: PackedStringArray, index: int) -> bool:
    var script_id := ""
    var cursor := index
    while cursor >= 0:
        var line := lines[cursor].strip_edges()
        if line.begins_with("script = ExtResource("):
            script_id = line
        if line.begins_with("[sub_resource"):
            break
        cursor -= 1
    if script_id.is_empty():
        return false
    var binding_id := _ext_resource_id("\n".join(lines), BINDING_SCRIPT)
    return not binding_id.is_empty() and script_id == 'script = ExtResource("%s")' % binding_id

static func _ext_resource_id(text: String, script_path: String) -> String:
    var expression := RegEx.new()
    expression.compile('\\[ext_resource type="Script" path="%s" id="([^"]+)"\\]' % script_path.replace("/", "\\/"))
    var found := expression.search(text)
    if found != null:
        return found.get_string(1)
    # Fall back to a plain scan so a different attribute order still resolves.
    for line: String in text.split("\n"):
        if line.begins_with("[ext_resource") and line.contains(script_path):
            var id_expression := RegEx.new()
            id_expression.compile('id="([^"]+)"')
            var id_found := id_expression.search(line)
            if id_found != null:
                return id_found.get_string(1)
    return ""

static func _line_starting_with(lines: PackedStringArray, prefix: String) -> int:
    for index in range(lines.size()):
        if lines[index].begins_with(prefix):
            return index
    return -1

static func _append_to_array(line: String, sub_id: String) -> String:
    var close := line.rfind("])")
    if close < 0:
        return ""
    var entry := 'SubResource("%s")' % sub_id
    var open := line.rfind("([")
    if open >= 0 and line.substr(open + 2, close - open - 2).strip_edges().is_empty():
        return line.substr(0, close) + entry + line.substr(close)
    return line.substr(0, close) + ", " + entry + line.substr(close)

static func _bump_load_steps(header: String) -> String:
    var expression := RegEx.new()
    expression.compile("load_steps=(\\d+)")
    var found := expression.search(header)
    if found == null:
        return ""
    var updated := int(found.get_string(1)) + 1
    return header.replace("load_steps=%s" % found.get_string(1), "load_steps=%d" % updated)

static func _success(text: String) -> Dictionary:
    return {"ok": true, "text": text, "error": ""}

static func _failure(message: String) -> Dictionary:
    return {"ok": false, "text": "", "error": message}
