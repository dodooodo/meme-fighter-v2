# Presentation-only attachment helper. Attachments never participate in gameplay collision.
class_name AttachmentPresenter
extends Node

var _nodes: Dictionary = {}

func attach_to_visual(visual: FighterVisual, binding: AttachmentPresentationBinding) -> Node2D:
    if visual == null or binding == null or not binding.is_valid():
        return null
    detach(binding.attachment_id)
    var node: Node = binding.visual_scene.instantiate() if binding.visual_scene != null else load("res://presentation/visuals/production/production_attachment_visual.tscn").instantiate()
    var item := node as Node2D
    if item == null:
        if node != null:
            node.queue_free()
        return null
    visual.add_child(item)
    item.position = visual.to_local(visual.socket_world_position(binding.socket_id, binding.offset_pixels))
    item.rotation_degrees = binding.rotation_degrees
    item.z_index = binding.z_index_offset
    var mirror := -1.0 if binding.mirror_with_facing and visual.current_facing < 0 else 1.0
    item.scale = Vector2(binding.visual_scale * mirror, binding.visual_scale)
    _nodes[binding.attachment_id] = item
    return item

func detach(attachment_id: StringName) -> void:
    var node: Node = _nodes.get(attachment_id, null)
    if node != null and is_instance_valid(node):
        node.queue_free()
    _nodes.erase(attachment_id)

func clear_all() -> void:
    for key: Variant in _nodes.keys():
        detach(StringName(String(key)))
