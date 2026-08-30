@tool
extends Window

# Art-pack import for MODE_FIGHTER packs.
#
# Every image rule -- crop, pivot, frame ordering, alpha, output naming -- stays
# in scripts/build_mode_character_assets.py. This dialog only gathers inputs,
# writes the spec and manifest those tools already accept, and runs
# scripts/build_art_manifest.py. It decodes no images and writes no assets
# itself, so the pipeline keeps exactly one definition.
#
# The order is fixed and enforced by the UI: validate, show, confirm, build,
# report. Building is unavailable until validation has passed for the inputs as
# they currently stand.

signal build_completed

const SPEC_DIR := "res://assets/presentation/specs"
const BUILDER := "scripts/build_art_manifest.py"
const IMAGE_EXTENSIONS: Array[String] = ["png", "webp", "jpg", "jpeg"]
const DEFAULT_FPS := 10.0
const DEFAULT_PYTHON := "python3"
# scripts/presentation_asset_pipeline/common.py uses a backslash inside an
# f-string expression, which only parses on 3.12+ (PEP 701), and every builder
# needs Pillow. Neither requirement is declared anywhere, and no CI job runs the
# builders, so the failure otherwise reaches contributors as a raw SyntaxError.
const PYTHON_MIN_MAJOR := 3
const PYTHON_MIN_MINOR := 12
const PREFLIGHT_SOURCE := "import sys; import PIL; print('PYOK %d.%d %s' % (sys.version_info[0], sys.version_info[1], PIL.__version__))"

const COLUMN_ANIMATION := 0
const COLUMN_FRAMES := 1
const COLUMN_FPS := 2
const COLUMN_LOOP := 3

var _character_select: OptionButton
var _mode_id_edit: LineEdit
var _source_edit: LineEdit
var _python_edit: LineEdit
var _animations_tree: Tree
var _output_label: Label
var _validate_button: Button
var _build_button: Button
var _log: RichTextLabel
var _source_dialog: FileDialog

var _character_ids: Array[StringName] = []
var _animation_items: Array[TreeItem] = []
var _validated := false

func _init() -> void:
    title = "Import art pack"
    size = Vector2i(760, 620)
    exclusive = true
    close_requested.connect(hide)
    _build_ui()

func open_for(character_ids: Array[StringName], selected: StringName) -> void:
    _character_ids = character_ids
    _character_select.clear()
    for index in range(character_ids.size()):
        _character_select.add_item(String(character_ids[index]), index)
        if character_ids[index] == selected:
            _character_select.select(index)
    _invalidate("Choose a source folder containing one subfolder per animation.")
    popup_centered()

# --- construction ------------------------------------------------------------

func _build_ui() -> void:
    var root := VBoxContainer.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 10)
    add_child(root)

    var margin := MarginContainer.new()
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 14)
    margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(margin)

    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 10)
    margin.add_child(body)

    var form := GridContainer.new()
    form.columns = 3
    body.add_child(form)

    form.add_child(_label("Character"))
    _character_select = OptionButton.new()
    _character_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _character_select.item_selected.connect(func(_index: int) -> void: _invalidate("Character changed."))
    form.add_child(_character_select)
    form.add_child(Control.new())

    form.add_child(_label("Mode id"))
    _mode_id_edit = LineEdit.new()
    _mode_id_edit.placeholder_text = "e.g. super_doge"
    _mode_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _mode_id_edit.text_changed.connect(func(_text: String) -> void: _invalidate("Mode id changed."))
    form.add_child(_mode_id_edit)
    form.add_child(Control.new())

    form.add_child(_label("Source folder"))
    _source_edit = LineEdit.new()
    _source_edit.editable = false
    _source_edit.placeholder_text = "res://assets/characters/<id>/source/<pack>"
    _source_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    form.add_child(_source_edit)
    var browse := Button.new()
    browse.text = "Browse"
    browse.pressed.connect(_on_browse)
    form.add_child(browse)

    form.add_child(_label("Python"))
    _python_edit = LineEdit.new()
    _python_edit.text = DEFAULT_PYTHON
    _python_edit.tooltip_text = "Command used to run the builders. Space-separated, so a wrapper such as 'uv run --with pillow python' works."
    _python_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _python_edit.text_changed.connect(func(_text: String) -> void: _invalidate("Python command changed."))
    form.add_child(_python_edit)
    var check := Button.new()
    check.text = "Check"
    check.pressed.connect(_on_preflight)
    form.add_child(check)

    var hint := Label.new()
    hint.text = "One subfolder per animation; images inside are ordered by filename. Only MODE_FIGHTER packs are supported here — base fighter, effect, and ultimate screen packs stay on scripts/build_art_manifest.py."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_child(hint)

    _animations_tree = Tree.new()
    _animations_tree.columns = 4
    _animations_tree.column_titles_visible = true
    _animations_tree.hide_root = true
    _animations_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _animations_tree.set_column_title(COLUMN_ANIMATION, "Animation")
    _animations_tree.set_column_title(COLUMN_FRAMES, "Frames")
    _animations_tree.set_column_title(COLUMN_FPS, "FPS")
    _animations_tree.set_column_title(COLUMN_LOOP, "Loop")
    _animations_tree.set_column_expand(COLUMN_ANIMATION, true)
    _animations_tree.item_edited.connect(func() -> void: _invalidate("Animation settings changed."))
    body.add_child(_animations_tree)

    _output_label = Label.new()
    body.add_child(_output_label)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 10)
    body.add_child(actions)

    _validate_button = Button.new()
    _validate_button.text = "Validate"
    _validate_button.pressed.connect(_on_validate)
    actions.add_child(_validate_button)

    _build_button = Button.new()
    _build_button.text = "Build"
    _build_button.disabled = true
    _build_button.pressed.connect(_on_build)
    actions.add_child(_build_button)

    var close := Button.new()
    close.text = "Close"
    close.pressed.connect(hide)
    actions.add_child(close)

    _log = RichTextLabel.new()
    _log.custom_minimum_size = Vector2(0, 170)
    _log.selection_enabled = true
    body.add_child(_log)

    _source_dialog = FileDialog.new()
    _source_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
    # Repository access only, so a path outside the project cannot be chosen.
    _source_dialog.access = FileDialog.ACCESS_RESOURCES
    _source_dialog.dir_selected.connect(_on_source_selected)
    add_child(_source_dialog)

func _label(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.custom_minimum_size = Vector2(110, 0)
    return label

# --- input -------------------------------------------------------------------

func _on_browse() -> void:
    _source_dialog.popup_centered_ratio(0.6)

func _on_source_selected(directory: String) -> void:
    _source_edit.text = directory
    _scan_source(directory)

# One animation per subfolder is the whole convention: it keeps the mapping
# obvious in a file browser and needs no naming scheme inside the folder.
func _scan_source(directory: String) -> void:
    _animation_items.clear()
    _animations_tree.clear()
    var root := _animations_tree.create_item()

    var subdirectories := DirAccess.get_directories_at(directory)
    if subdirectories.is_empty():
        _invalidate("No subfolders in %s. Each animation needs its own subfolder." % directory)
        return
    subdirectories.sort()

    var skipped: Array[String] = []
    for name: String in subdirectories:
        var frames := _image_files("%s/%s" % [directory, name])
        if frames.is_empty():
            skipped.append(name)
            continue
        var item := _animations_tree.create_item(root)
        item.set_text(COLUMN_ANIMATION, name)
        item.set_text(COLUMN_FRAMES, str(frames.size()))
        item.set_cell_mode(COLUMN_FPS, TreeItem.CELL_MODE_RANGE)
        item.set_range_config(COLUMN_FPS, 1.0, 60.0, 1.0)
        item.set_range(COLUMN_FPS, DEFAULT_FPS)
        item.set_editable(COLUMN_FPS, true)
        item.set_cell_mode(COLUMN_LOOP, TreeItem.CELL_MODE_CHECK)
        item.set_checked(COLUMN_LOOP, true)
        item.set_editable(COLUMN_LOOP, true)
        item.set_metadata(COLUMN_ANIMATION, frames)
        _animation_items.append(item)

    var message := "Found %d animation(s)." % _animation_items.size()
    if not skipped.is_empty():
        message += " Skipped %d subfolder(s) with no images: %s." % [skipped.size(), ", ".join(skipped)]
    if _animation_items.is_empty():
        message += " Nothing to import."
    _invalidate(message)

func _image_files(directory: String) -> PackedStringArray:
    var files := PackedStringArray()
    for name: String in DirAccess.get_files_at(directory):
        if IMAGE_EXTENSIONS.has(name.get_extension().to_lower()):
            files.append(name)
    files.sort()
    return files

# --- validation and build ----------------------------------------------------

# Checked before validating so an unusable interpreter is reported as such
# rather than as whatever the builders happen to fail with.
func _on_preflight() -> bool:
    var result := _run_python(["-c", PREFLIGHT_SOURCE])
    var report := ""
    for line: String in result["output"]:
        if line.contains("PYOK"):
            report = line.strip_edges()
    if result["exit_code"] != 0 or report.is_empty():
        _print_output(result)
        _print_line("[b]%s cannot run the builders.[/b] They need Python %d.%d+ and Pillow." % [
            _python_command_text(), PYTHON_MIN_MAJOR, PYTHON_MIN_MINOR])
        return false
    var fields := report.split(" ")
    var version := fields[1].split(".")
    var major := int(version[0])
    var minor := int(version[1])
    _print_line("%s: Python %d.%d, Pillow %s" % [_python_command_text(), major, minor, fields[2]])
    if major < PYTHON_MIN_MAJOR or (major == PYTHON_MIN_MAJOR and minor < PYTHON_MIN_MINOR):
        _print_line("[b]Python %d.%d is too old.[/b] The builders need %d.%d+; point this field at a newer interpreter." % [
            major, minor, PYTHON_MIN_MAJOR, PYTHON_MIN_MINOR])
        return false
    return true

func _on_validate() -> void:
    var error := _input_error()
    if not error.is_empty():
        _invalidate(error)
        return
    if not _on_preflight():
        _validated = false
        _build_button.disabled = true
        return
    var spec_path := _spec_path()
    var manifest_path := _manifest_path()
    var write_error := _write_spec_and_manifest(spec_path, manifest_path)
    if not write_error.is_empty():
        _invalidate(write_error)
        return

    _print_line("Wrote %s" % spec_path)
    _print_line("Wrote %s" % manifest_path)
    var result := _run_builder(manifest_path, true)
    _print_output(result)
    if result["exit_code"] != 0:
        _validated = false
        _build_button.disabled = true
        _print_line("[b]Validation failed. Nothing was built.[/b]")
        return
    _validated = true
    _build_button.disabled = false
    _output_label.text = "Output directory: %s" % _output_directory()
    _print_line("[b]Validation passed. Build is now available.[/b]")

func _on_build() -> void:
    if not _validated:
        return
    var output_directory := _output_directory()
    var before := _snapshot(output_directory)
    var result := _run_builder(_manifest_path(), false)
    _print_output(result)
    var after := _snapshot(output_directory)
    _report_changes(before, after)
    # Any edit after a build must be validated again before it can be rebuilt.
    _validated = false
    _build_button.disabled = true
    if result["exit_code"] == 0:
        build_completed.emit()

func _input_error() -> String:
    if _character_select.selected < 0:
        return "Select a character."
    if not _mode_id_valid():
        return "Mode id must be lowercase letters, digits, or underscores."
    if _source_edit.text.is_empty():
        return "Choose a source folder."
    if _animation_items.is_empty():
        return "No animations to import."
    return ""

func _mode_id_valid() -> bool:
    var mode_id := _mode_id_edit.text.strip_edges()
    if mode_id.is_empty():
        return false
    var expression := RegEx.new()
    expression.compile("^[a-z][a-z0-9_]*$")
    return expression.search(mode_id) != null

func _write_spec_and_manifest(spec_path: String, manifest_path: String) -> String:
    var animations: Array = []
    for item: TreeItem in _animation_items:
        var frames: PackedStringArray = item.get_metadata(COLUMN_ANIMATION)
        var name := item.get_text(COLUMN_ANIMATION)
        var relative: Array = []
        for frame: String in frames:
            relative.append("%s/%s" % [name, frame])
        animations.append({
            "key": name,
            "fps": item.get_range(COLUMN_FPS),
            "loop": item.is_checked(COLUMN_LOOP),
            "frames": relative,
        })

    var character_id := String(_character_ids[_character_select.selected])
    var spec := {
        "version": 1,
        "pack_type": "MODE_FIGHTER",
        "character_asset_key": character_id,
        "character_id": character_id,
        "mode_id": _mode_id_edit.text.strip_edges(),
        "animations": animations,
    }
    var manifest := {
        "schema_version": 1,
        "jobs": [{
            "id": _job_id(),
            "type": "mode_fighter",
            "spec": _repository_relative(spec_path),
            "source_root": _repository_relative(_source_edit.text),
        }],
    }
    if not DirAccess.dir_exists_absolute(SPEC_DIR):
        var made := DirAccess.make_dir_recursive_absolute(SPEC_DIR)
        if made != OK:
            return "Cannot create %s" % SPEC_DIR
    var spec_error := _write_json(spec_path, spec)
    if not spec_error.is_empty():
        return spec_error
    return _write_json(manifest_path, manifest)

func _write_json(path: String, value: Variant) -> String:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return "Cannot write %s" % path
    file.store_string(JSON.stringify(value, "  ") + "\n")
    file.close()
    return ""

# scripts/build_art_manifest.py takes an explicit --project-root, so it does not
# matter what working directory the editor happens to have.
func _run_builder(manifest_path: String, validate_only: bool) -> Dictionary:
    var project_root := ProjectSettings.globalize_path("res://").rstrip("/")
    var arguments: PackedStringArray = [
        "%s/%s" % [project_root, BUILDER],
        "--project-root", project_root,
        "--manifest", ProjectSettings.globalize_path(manifest_path),
    ]
    if validate_only:
        arguments.append("--validate-only")
    return _run_python(arguments)

# The command is split on spaces so a wrapper such as "uv run --with pillow
# python" works as well as a bare interpreter path.
func _run_python(arguments: PackedStringArray) -> Dictionary:
    var parts := _python_command_text().split(" ", false)
    if parts.is_empty():
        return {"exit_code": -1, "output": ["No Python command set."]}
    var full: PackedStringArray = []
    for index in range(1, parts.size()):
        full.append(parts[index])
    full.append_array(arguments)
    var output: Array = []
    var exit_code := OS.execute(parts[0], full, output, true)
    return {"exit_code": exit_code, "output": output}

func _python_command_text() -> String:
    var text := _python_edit.text.strip_edges()
    return text if not text.is_empty() else DEFAULT_PYTHON

func _report_changes(before: Dictionary, after: Dictionary) -> void:
    var added: Array[String] = []
    var changed: Array[String] = []
    var removed: Array[String] = []
    for path: String in after:
        if not before.has(path):
            added.append(path)
        elif before[path] != after[path]:
            changed.append(path)
    for path: String in before:
        if not after.has(path):
            removed.append(path)
    added.sort()
    changed.sort()
    removed.sort()
    _print_line("[b]Files added %d, changed %d, removed %d[/b]" % [added.size(), changed.size(), removed.size()])
    _print_paths("added", added)
    _print_paths("changed", changed)
    _print_paths("removed", removed)

# Size and modification time are enough to tell a contributor what a build
# touched, and avoid hashing every frame of a large pack.
func _snapshot(directory: String) -> Dictionary:
    var snapshot: Dictionary = {}
    _snapshot_into(directory, snapshot)
    return snapshot

func _snapshot_into(directory: String, snapshot: Dictionary) -> void:
    if not DirAccess.dir_exists_absolute(directory):
        return
    for name: String in DirAccess.get_files_at(directory):
        var path := "%s/%s" % [directory, name]
        snapshot[path] = "%d:%d" % [
            FileAccess.get_modified_time(path),
            _file_size(path),
        ]
    for name: String in DirAccess.get_directories_at(directory):
        _snapshot_into("%s/%s" % [directory, name], snapshot)

func _file_size(path: String) -> int:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return -1
    var length := file.get_length()
    file.close()
    return length

# --- helpers -----------------------------------------------------------------

func _job_id() -> String:
    return "%s_%s" % [String(_character_ids[_character_select.selected]), _mode_id_edit.text.strip_edges()]

func _spec_path() -> String:
    return "%s/%s.json" % [SPEC_DIR, _job_id()]

func _manifest_path() -> String:
    return "%s/%s.art_manifest.json" % [SPEC_DIR, _job_id()]

func _output_directory() -> String:
    return "res://assets/characters/%s" % String(_character_ids[_character_select.selected])

func _repository_relative(path: String) -> String:
    return path.trim_prefix("res://")

func _invalidate(message: String) -> void:
    _validated = false
    _build_button.disabled = true
    _output_label.text = ""
    _print_line(message)

func _print_line(message: String) -> void:
    _log.append_text(message + "\n")

func _print_paths(label: String, paths: Array[String]) -> void:
    for path: String in paths:
        _print_line("  %s: %s" % [label, path])

# The builder's own wording is the contract; passing it through unchanged means
# a failure here reads exactly like the same failure from the terminal.
func _print_output(result: Dictionary) -> void:
    for line: String in result["output"]:
        var text := line.strip_edges()
        if not text.is_empty():
            _print_line(text)
    _print_line("exit code: %d" % result["exit_code"])
