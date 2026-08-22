# M9P multi-pack Presentation preview. Never instantiates BattleSimulation or gameplay input.
class_name ProductionCharacterPreview
extends Node2D

const PRESENTATION_PATHS: PackedStringArray = [
    "res://presentation/characters/generic_fighter_presentation.tres",
    "res://presentation/characters/zone_fighter_presentation.tres",
    "res://presentation/characters/rush_grappler_presentation.tres",
]
const PACK_TYPES: PackedStringArray = [
    "BASE_FIGHTER", "MODE_FIGHTER", "PROJECTILE", "WORLD_EFFECT",
    "HAZARD", "ULTIMATE_SCREEN", "ATTACHMENT"
]
const BASE_ANIMATION_KEYS: PackedStringArray = [
    "idle", "walk_forward", "walk_back", "crouch", "jump", "landing",
    "guard_stand", "guard_crouch", "hitstun", "blockstun", "thrown",
    "knockdown", "getup", "ko", "dash_forward", "backstep", "stand_light",
    "stand_heavy", "crouch_low", "air_attack", "ground_throw",
    "special_neutral", "ultimate"
]
const SPEED_VALUES: Array[float] = [0.25, 0.5, 1.0]

@onready var visual_anchor: Node2D = $VisualAnchor
@onready var screen_anchor: Control = $ScreenAnchor
@onready var character_picker: OptionButton = $UILayer/UI/CharacterPicker
@onready var pack_type_picker: OptionButton = $UILayer/UI/PackTypePicker
@onready var asset_picker: OptionButton = $UILayer/UI/AssetPicker
@onready var animation_picker: OptionButton = $UILayer/UI/AnimationPicker
@onready var speed_picker: OptionButton = $UILayer/UI/SpeedPicker
@onready var info_label: Label = $UILayer/UI/Info

var presentations: Array[CharacterPresentationData] = []
var active_node: Node
var active_fighter_visual: FighterVisual
var active_pack_label: String = ""

func _ready() -> void:
    for path: String in PRESENTATION_PATHS:
        var data := load(path) as CharacterPresentationData
        if data != null:
            data.rebuild_cache()
            presentations.append(data)
            character_picker.add_item(data.display_name)
    for pack: String in PACK_TYPES:
        pack_type_picker.add_item(pack)
    speed_picker.add_item("0.25x")
    speed_picker.add_item("0.5x")
    speed_picker.add_item("1.0x")
    speed_picker.select(2)
    character_picker.item_selected.connect(_on_selection_changed)
    pack_type_picker.item_selected.connect(_on_pack_changed)
    asset_picker.item_selected.connect(_on_asset_changed)
    animation_picker.item_selected.connect(_on_animation_changed)
    speed_picker.item_selected.connect(_on_speed_changed)
    _rebuild_asset_picker()
    _show_selected()

func _process(_delta: float) -> void:
    _update_info()

func _current_data() -> CharacterPresentationData:
    if presentations.is_empty():
        return null
    return presentations[clampi(character_picker.selected, 0, presentations.size() - 1)]

func _current_pack() -> String:
    return PACK_TYPES[clampi(pack_type_picker.selected, 0, PACK_TYPES.size() - 1)]

func _rebuild_asset_picker() -> void:
    asset_picker.clear()
    animation_picker.clear()
    var data := _current_data()
    if data == null:
        return
    match _current_pack():
        "BASE_FIGHTER":
            asset_picker.add_item("base")
            for key: String in BASE_ANIMATION_KEYS:
                animation_picker.add_item(key)
        "MODE_FIGHTER":
            for binding: ModePresentationBinding in data.mode_bindings:
                asset_picker.add_item(String(binding.mode_id))
            _populate_mode_animations(data)
        "PROJECTILE":
            for binding: ProjectilePresentationBinding in data.projectile_bindings:
                asset_picker.add_item(String(binding.projectile_id))
            animation_picker.add_item("effect")
        "WORLD_EFFECT", "HAZARD":
            var wanted := PresentationAssetPackType.PackType.WORLD_EFFECT if _current_pack() == "WORLD_EFFECT" else PresentationAssetPackType.PackType.HAZARD
            for binding: EffectPresentationBinding in data.effect_bindings:
                if binding.pack_type == wanted:
                    asset_picker.add_item(String(binding.effect_id))
            animation_picker.add_item("effect")
        "ULTIMATE_SCREEN":
            for binding: UltimatePresentationBinding in data.ultimate_bindings:
                asset_picker.add_item(String(binding.ultimate_id))
            animation_picker.add_item("screen")
        "ATTACHMENT":
            for binding: AttachmentPresentationBinding in data.attachment_bindings:
                asset_picker.add_item(String(binding.attachment_id))
            animation_picker.add_item("attachment")
    if asset_picker.item_count == 0:
        asset_picker.add_item("<no pack bound>")
    if animation_picker.item_count == 0:
        animation_picker.add_item("<none>")

func _populate_mode_animations(data: CharacterPresentationData) -> void:
    if data.mode_bindings.is_empty():
        animation_picker.add_item("<none>")
        return
    var index := clampi(asset_picker.selected, 0, data.mode_bindings.size() - 1)
    var binding: ModePresentationBinding = data.mode_bindings[index]
    var keys := _animation_keys_from_manifest(binding.pack_manifest_path)
    if keys.is_empty():
        for required_key: StringName in binding.required_animations:
            keys.append(String(required_key))
    for key: String in keys:
        animation_picker.add_item(key)
    if animation_picker.item_count == 0:
        animation_picker.add_item("idle")

func _animation_keys_from_manifest(path: String) -> PackedStringArray:
    var out := PackedStringArray()
    if path.is_empty() or not FileAccess.file_exists(path):
        return out
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Dictionary):
        return out
    for item: Variant in parsed.get("animations", []):
        if item is Dictionary:
            var key := String(item.get("key", ""))
            if not key.is_empty():
                out.append(key)
    return out

func _show_selected() -> void:
    _clear_active()
    var data := _current_data()
    if data == null:
        return
    var pack := _current_pack()
    active_pack_label = pack
    match pack:
        "BASE_FIGHTER":
            _show_fighter_scene(data.fighter_visual_scene, 1.0)
        "MODE_FIGHTER":
            if not data.mode_bindings.is_empty():
                var binding: ModePresentationBinding = data.mode_bindings[clampi(asset_picker.selected, 0, data.mode_bindings.size() - 1)]
                _show_fighter_scene(binding.fighter_visual_scene, binding.visual_scale)
        "PROJECTILE":
            if not data.projectile_bindings.is_empty():
                _show_world_scene(data.projectile_bindings[clampi(asset_picker.selected, 0, data.projectile_bindings.size() - 1)].visual_scene)
        "WORLD_EFFECT", "HAZARD":
            var bindings: Array[EffectPresentationBinding] = []
            var wanted := PresentationAssetPackType.PackType.WORLD_EFFECT if pack == "WORLD_EFFECT" else PresentationAssetPackType.PackType.HAZARD
            for binding: EffectPresentationBinding in data.effect_bindings:
                if binding.pack_type == wanted:
                    bindings.append(binding)
            if not bindings.is_empty():
                _show_world_scene(bindings[clampi(asset_picker.selected, 0, bindings.size() - 1)].visual_scene)
        "ULTIMATE_SCREEN":
            if not data.ultimate_bindings.is_empty():
                var binding: UltimatePresentationBinding = data.ultimate_bindings[clampi(asset_picker.selected, 0, data.ultimate_bindings.size() - 1)]
                _show_screen_scene(binding.background_scene)
        "ATTACHMENT":
            if not data.attachment_bindings.is_empty():
                var binding: AttachmentPresentationBinding = data.attachment_bindings[clampi(asset_picker.selected, 0, data.attachment_bindings.size() - 1)]
                if binding.visual_scene != null:
                    _show_world_scene(binding.visual_scene)
                elif binding.texture != null:
                    var sprite := Sprite2D.new()
                    sprite.texture = binding.texture
                    visual_anchor.add_child(sprite)
                    active_node = sprite
    _play_selected_animation()

func _show_fighter_scene(scene: PackedScene, scale_multiplier: float) -> void:
    if scene == null:
        return
    active_fighter_visual = scene.instantiate() as FighterVisual
    if active_fighter_visual == null:
        return
    visual_anchor.add_child(active_fighter_visual)
    active_node = active_fighter_visual
    active_fighter_visual.set_screen_position(Vector2.ZERO)
    active_fighter_visual.set_facing(1)
    active_fighter_visual.set_visual_scale_multiplier(scale_multiplier)
    active_fighter_visual.set_preview_mode(true, SPEED_VALUES[speed_picker.selected])

func _show_world_scene(scene: PackedScene) -> void:
    if scene == null:
        return
    active_node = scene.instantiate()
    visual_anchor.add_child(active_node)
    if active_node is Node2D:
        (active_node as Node2D).position = Vector2(0, -180)

func _show_screen_scene(scene: PackedScene) -> void:
    if scene == null:
        return
    active_node = scene.instantiate()
    screen_anchor.add_child(active_node)

func _play_selected_animation() -> void:
    if active_fighter_visual != null and animation_picker.item_count > 0:
        active_fighter_visual.play_animation(StringName(animation_picker.get_item_text(animation_picker.selected)))

func _clear_active() -> void:
    if active_node != null and is_instance_valid(active_node):
        active_node.queue_free()
    active_node = null
    active_fighter_visual = null

func _on_selection_changed(_index: int) -> void:
    _rebuild_asset_picker()
    _show_selected()

func _on_pack_changed(_index: int) -> void:
    _rebuild_asset_picker()
    _show_selected()

func _on_asset_changed(_index: int) -> void:
    if _current_pack() == "MODE_FIGHTER":
        animation_picker.clear()
        _populate_mode_animations(_current_data())
    _show_selected()

func _on_animation_changed(_index: int) -> void:
    _play_selected_animation()

func _on_speed_changed(index: int) -> void:
    if active_fighter_visual != null:
        active_fighter_visual.set_preview_mode(true, SPEED_VALUES[index])

func _update_info() -> void:
    var data := _current_data()
    if data == null:
        return
    var asset_text := asset_picker.get_item_text(asset_picker.selected) if asset_picker.item_count > 0 else "none"
    var animation_text := animation_picker.get_item_text(animation_picker.selected) if animation_picker.item_count > 0 else "none"
    var extra := ""
    if active_fighter_visual != null:
        extra = " | Frame %02d | Phase %s" % [active_fighter_visual.debug_frame_number(), String(active_fighter_visual.debug_presentation_phase())]
    info_label.text = "%s | %s | %s | %s | %.2fx%s | Presentation Preview only" % [
        data.display_name, _current_pack(), asset_text, animation_text,
        SPEED_VALUES[speed_picker.selected], extra
    ]
