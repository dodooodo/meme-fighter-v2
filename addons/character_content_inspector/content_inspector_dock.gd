@tool
extends VBoxContainer

# Read-only dock over ContentIndex. Renders the same join CharacterValidator and
# scripts/content_report.gd read, so a red row here and a red CI check always
# mean the same thing. Nothing here writes to disk.

const PACKAGE_ROOT := "res://content/characters"

const COLOR_ERROR := Color(0.93, 0.42, 0.42)
const COLOR_WARNING := Color(0.95, 0.76, 0.36)
const COLOR_MUTED := Color(0.62, 0.64, 0.69)

var _index: ContentIndex = null
var _character_list: ItemList
var _summary_label: Label
var _moves_tree: Tree
var _states_tree: Tree
var _animations_tree: Tree
var _issues_tree: Tree
var _preview_frame: TextureRect
var _preview_label: Label
var _preview_timer: Timer

var _preview_frames: Array[Texture2D] = []
var _preview_loop: bool = true
var _preview_position: int = 0

func _init() -> void:
    custom_minimum_size = Vector2(360, 480)
    _build_ui()

func _ready() -> void:
    refresh()

# --- construction ------------------------------------------------------------

func _build_ui() -> void:
    add_theme_constant_override("separation", 6)

    var toolbar := HBoxContainer.new()
    add_child(toolbar)

    var refresh_button := Button.new()
    refresh_button.text = "Refresh"
    refresh_button.tooltip_text = "Rebuild the index from disk"
    refresh_button.pressed.connect(refresh)
    toolbar.add_child(refresh_button)

    # Reserved for A-COL-010. Present so the entry point has a settled home;
    # deliberately inert until the import path exists.
    var import_button := Button.new()
    import_button.text = "Import art pack"
    import_button.disabled = true
    import_button.tooltip_text = "Not implemented yet (A-COL-010). Build art packs with scripts/build_art_manifest.py."
    toolbar.add_child(import_button)

    _summary_label = Label.new()
    _summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    toolbar.add_child(_summary_label)

    var split := HSplitContainer.new()
    split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    split.split_offset = 130
    add_child(split)

    _character_list = ItemList.new()
    _character_list.custom_minimum_size = Vector2(120, 0)
    _character_list.item_selected.connect(_on_character_selected)
    split.add_child(_character_list)

    var right := VSplitContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.split_offset = 260
    split.add_child(right)

    var tabs := TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_child(tabs)

    _moves_tree = _make_tree(["Move", "Animation", "Frames", "Dmg", "Status"])
    _moves_tree.name = "Moves"
    _moves_tree.item_selected.connect(_on_move_selected)
    tabs.add_child(_moves_tree)

    _states_tree = _make_tree(["State", "Animation"])
    _states_tree.name = "States"
    _states_tree.item_selected.connect(_on_state_selected)
    tabs.add_child(_states_tree)

    _animations_tree = _make_tree(["Animation", "Frames", "FPS", "Loop", "Referenced"])
    _animations_tree.name = "Animations"
    _animations_tree.item_selected.connect(_on_animation_selected)
    tabs.add_child(_animations_tree)

    _issues_tree = _make_tree(["Severity", "Check", "Detail"])
    _issues_tree.name = "Issues"
    tabs.add_child(_issues_tree)

    right.add_child(_build_preview())

func _build_preview() -> Control:
    var panel := VBoxContainer.new()
    panel.custom_minimum_size = Vector2(0, 150)

    _preview_label = Label.new()
    _preview_label.text = "Select a move or animation"
    panel.add_child(_preview_label)

    _preview_frame = TextureRect.new()
    _preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _preview_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _preview_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    panel.add_child(_preview_frame)

    _preview_timer = Timer.new()
    _preview_timer.timeout.connect(_advance_preview)
    panel.add_child(_preview_timer)
    return panel

func _make_tree(titles: Array) -> Tree:
    var tree := Tree.new()
    tree.columns = titles.size()
    tree.column_titles_visible = true
    tree.hide_root = true
    tree.select_mode = Tree.SELECT_ROW
    tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    for column in range(titles.size()):
        tree.set_column_title(column, String(titles[column]))
        tree.set_column_expand(column, column == titles.size() - 1)
    return tree

# --- data --------------------------------------------------------------------

func refresh() -> void:
    _stop_preview()
    _index = ContentIndex.new()
    _index.build(_load_manifests(), CharacterValidator.load_unbound_allowlist())

    var previous := _selected_character_id()
    _character_list.clear()
    var restore_row := -1
    for entry: Dictionary in _index.characters:
        var errors := _count(entry, ContentIndex.SEVERITY_ERROR)
        var label := String(entry["character_id"])
        if errors > 0:
            label += "  (%d)" % errors
        var row := _character_list.add_item(label)
        _character_list.set_item_metadata(row, entry["character_id"])
        if errors > 0:
            _character_list.set_item_custom_fg_color(row, COLOR_ERROR)
        if entry["character_id"] == previous:
            restore_row = row

    var total_errors := _index.issues(ContentIndex.SEVERITY_ERROR).size()
    var total_warnings := _index.issues().size() - total_errors
    _summary_label.text = "%d error(s), %d warning(s)" % [total_errors, total_warnings]
    _summary_label.add_theme_color_override("font_color",
        COLOR_ERROR if total_errors > 0 else COLOR_MUTED)

    if _character_list.item_count == 0:
        return
    var select := restore_row if restore_row >= 0 else 0
    _character_list.select(select)
    _on_character_selected(select)

func _load_manifests() -> Array[CharacterManifest]:
    var manifests: Array[CharacterManifest] = []
    var directories := DirAccess.get_directories_at(PACKAGE_ROOT)
    if directories.is_empty():
        return manifests
    directories.sort()
    for directory: String in directories:
        if directory.begins_with("_"):
            continue
        var path := "%s/%s/character_manifest.tres" % [PACKAGE_ROOT, directory]
        if not ResourceLoader.exists(path):
            continue
        var manifest := load(path) as CharacterManifest
        if manifest != null:
            manifests.append(manifest)
    return manifests

func _selected_character_id() -> StringName:
    var selected := _character_list.get_selected_items()
    if selected.is_empty():
        return &""
    return _character_list.get_item_metadata(selected[0])

func _current_entry() -> Dictionary:
    if _index == null:
        return {}
    var character_id := _selected_character_id()
    return _index.character(character_id) if character_id != &"" else {}

# --- population --------------------------------------------------------------

func _on_character_selected(_row: int) -> void:
    _stop_preview()
    var entry := _current_entry()
    _fill_moves(entry)
    _fill_states(entry)
    _fill_animations(entry)
    _fill_issues(entry)

func _fill_moves(entry: Dictionary) -> void:
    _moves_tree.clear()
    var root := _moves_tree.create_item()
    for row: Dictionary in entry.get("moves", []):
        var item := _moves_tree.create_item(root)
        item.set_text(0, String(row["move_id"]))
        item.set_text(1, _binding_text(row["bindings"]))
        item.set_text(2, "%d/%d/%d" % [row["startup_frames"], row["active_frames"], row["recovery_frames"]])
        item.set_text(3, str(row["damage"]))
        item.set_text(4, _move_status(row, entry))
        item.set_metadata(0, _first_playable_key(row["bindings"]))
        if not row["bound"]:
            item.set_custom_color(4, COLOR_WARNING if row["allowlisted"] else COLOR_ERROR)
        elif _has_missing_binding(row["bindings"]):
            item.set_custom_color(4, COLOR_ERROR)

func _fill_states(entry: Dictionary) -> void:
    _states_tree.clear()
    var root := _states_tree.create_item()
    for row: Dictionary in entry.get("states", []):
        var item := _states_tree.create_item(root)
        item.set_text(0, String(row["state_key"]))
        item.set_text(1, _binding_text(row["bindings"]))
        item.set_metadata(0, _first_playable_key(row["bindings"]))
        if _has_missing_binding(row["bindings"]):
            item.set_custom_color(1, COLOR_ERROR)

func _fill_animations(entry: Dictionary) -> void:
    _animations_tree.clear()
    var root := _animations_tree.create_item()
    for row: Dictionary in entry.get("animations", []):
        var item := _animations_tree.create_item(root)
        item.set_text(0, String(row["animation_key"]))
        item.set_text(1, str(row["frame_count"]))
        item.set_text(2, "%.1f" % float(row["fps"]))
        item.set_text(3, "yes" if row["loop"] else "no")
        item.set_text(4, "yes" if row["referenced"] else "no — orphaned art")
        item.set_metadata(0, row["animation_key"])
        if not row["referenced"]:
            item.set_custom_color(4, COLOR_WARNING)

func _fill_issues(entry: Dictionary) -> void:
    _issues_tree.clear()
    var root := _issues_tree.create_item()
    for issue: Dictionary in entry.get("issues", []):
        var item := _issues_tree.create_item(root)
        item.set_text(0, String(issue["severity"]))
        item.set_text(1, String(issue["code"]))
        item.set_text(2, String(issue["message"]))
        var is_error: bool = issue["severity"] == ContentIndex.SEVERITY_ERROR
        item.set_custom_color(0, COLOR_ERROR if is_error else COLOR_WARNING)

func _binding_text(bindings: Array) -> String:
    if bindings.is_empty():
        return "(none)"
    var parts: Array[String] = []
    for binding: Dictionary in bindings:
        var text := String(binding["animation_key"])
        if not binding["exists"]:
            text += " [missing]"
        if String(binding["resource_id"]) != "":
            text += " [%s %d-%d]" % [
                String(binding["resource_id"]),
                binding["resource_min_value"],
                binding["resource_max_value"],
            ]
        parts.append(text)
    return ", ".join(parts)

func _move_status(row: Dictionary, entry: Dictionary) -> String:
    if not row["bound"]:
        var consequence := "renders nothing" if not entry.get("move_fallback_exists", true) else "falls back"
        return "allowlisted, %s" % consequence if row["allowlisted"] else "UNBOUND, %s" % consequence
    if _has_missing_binding(row["bindings"]):
        return "MISSING ANIMATION"
    return "ok"

func _has_missing_binding(bindings: Array) -> bool:
    for binding: Dictionary in bindings:
        if not binding["exists"]:
            return true
    return false

func _first_playable_key(bindings: Array) -> StringName:
    for binding: Dictionary in bindings:
        if binding["exists"]:
            return binding["animation_key"]
    return &""

# --- preview -----------------------------------------------------------------

func _on_move_selected() -> void:
    _preview_selected(_moves_tree)

func _on_state_selected() -> void:
    _preview_selected(_states_tree)

func _on_animation_selected() -> void:
    _preview_selected(_animations_tree)

func _preview_selected(tree: Tree) -> void:
    var item := tree.get_selected()
    if item == null:
        return
    _play(item.get_metadata(0))

func _play(animation_key: Variant) -> void:
    _stop_preview()
    if animation_key == null or String(animation_key) == "":
        _preview_label.text = "Nothing bound to preview"
        return
    var entry := _current_entry()
    var sprite_frames := entry.get("sprite_frames", null) as SpriteFrames
    var key := StringName(animation_key)
    if sprite_frames == null or not sprite_frames.has_animation(key):
        _preview_label.text = "%s — not in SpriteFrames" % String(key)
        return

    for frame in range(sprite_frames.get_frame_count(key)):
        _preview_frames.append(sprite_frames.get_frame_texture(key, frame))
    if _preview_frames.is_empty():
        _preview_label.text = "%s — no frames" % String(key)
        return

    var fps := _fps_for(entry, key, sprite_frames)
    _preview_loop = sprite_frames.get_animation_loop(key)
    _preview_label.text = "%s — %d frames @ %.1f fps%s" % [
        String(key), _preview_frames.size(), fps, "" if _preview_loop else " (once)",
    ]
    _preview_position = 0
    _preview_frame.texture = _preview_frames[0]
    if _preview_frames.size() > 1 and fps > 0.0:
        _preview_timer.wait_time = 1.0 / fps
        _preview_timer.start()

# The build manifest is authoritative for playback speed; SpriteFrames' own
# speed is the fallback when a package has no manifest.
func _fps_for(entry: Dictionary, key: StringName, sprite_frames: SpriteFrames) -> float:
    for row: Dictionary in entry.get("animations", []):
        if row["animation_key"] == key:
            return float(row["fps"])
    return sprite_frames.get_animation_speed(key)

func _advance_preview() -> void:
    if _preview_frames.is_empty():
        return
    _preview_position += 1
    if _preview_position >= _preview_frames.size():
        if not _preview_loop:
            _preview_timer.stop()
            return
        _preview_position = 0
    _preview_frame.texture = _preview_frames[_preview_position]

func _stop_preview() -> void:
    if _preview_timer != null:
        _preview_timer.stop()
    _preview_frames.clear()
    _preview_position = 0
    if _preview_frame != null:
        _preview_frame.texture = null

func _count(entry: Dictionary, severity: String) -> int:
    var total := 0
    for issue: Dictionary in entry["issues"]:
        if issue["severity"] == severity:
            total += 1
    return total
