# Adapter for legacy centered Doge pose art. Presentation-only.
class_name DogeProductionFighterVisual
extends ProductionFighterVisual

func _ready() -> void:
    super._ready()
    sprite.centered = true
