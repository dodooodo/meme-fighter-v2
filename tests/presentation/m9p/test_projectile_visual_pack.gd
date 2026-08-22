class_name M9PProjectileVisualPackTests
extends RefCounted
const ASSERT_HELPER := preload("res://tests/test_assert.gd")
var t = ASSERT_HELPER.new()

func run_all() -> int:
    var scene := load("res://presentation/visuals/production/production_projectile_visual.tscn") as PackedScene
    var visual := scene.instantiate() as ProductionProjectileVisual
    visual.configure(&"sonic_l3", Color.WHITE, 1.5)
    visual.set_facing(-1)
    t.near(absf(visual.scale.x), 1.5, 0.001, "Projectile visual scale is Presentation-only")
    t.that(visual.scale.x < 0.0, "Detached projectile visual can mirror facing without duplicated art")
    visual.free()
    print("\nM9P ProjectileVisualPack: %d passed, %d failed" % [t.passed, t.failed])
    return t.failed
