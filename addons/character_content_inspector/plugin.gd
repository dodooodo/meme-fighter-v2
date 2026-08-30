@tool
extends EditorPlugin

# Contributes the Character Content Inspector dock. Editor-only and read-only:
# it renders ContentIndex, the same join CharacterValidator and
# scripts/content_report.gd read, so the dock and CI can never disagree.

const DOCK_SCRIPT := preload("res://addons/character_content_inspector/content_inspector_dock.gd")

var _dock: Control = null

func _enter_tree() -> void:
    _dock = DOCK_SCRIPT.new()
    _dock.name = "Characters"
    add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock)

func _exit_tree() -> void:
    if _dock == null:
        return
    remove_control_from_docks(_dock)
    _dock.queue_free()
    _dock = null
