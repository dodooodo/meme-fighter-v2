# Frontend/test registry for the formal 14-character roster.
# This file may know concrete character IDs; generic gameplay core must not.
class_name RosterRegistry
extends RefCounted

const SALAD_CAT_MANIFEST: CharacterManifest = preload("res://content/characters/salad_cat/character_manifest.tres")
const MAGIC_ORANGE_CAT_MANIFEST: CharacterManifest = preload("res://content/characters/magic_orange_cat/character_manifest.tres")

const ENTRIES: Array[Dictionary] = [
    {"id": &"alien_meow", "name": "Alien Meow", "character": preload("res://data/characters/alien_meow.tres"), "presentation": preload("res://presentation/characters/alien_meow_presentation.tres")},
    {"id": &"doge", "name": "Doge", "character": preload("res://data/characters/doge.tres"), "presentation": preload("res://presentation/characters/doge_presentation.tres")},
    {"id": &"ya_mouse", "name": "YA鼠", "character": preload("res://data/characters/ya_mouse.tres"), "presentation": preload("res://presentation/characters/ya_mouse_presentation.tres")},
    {"id": &"tempura_penguin", "name": "Oh fuxking 天婦羅尬哩涼", "character": preload("res://data/characters/tempura_penguin.tres"), "presentation": preload("res://presentation/characters/tempura_penguin_presentation.tres")},
    {"id": &"goblin_love", "name": "哥布林也想談戀愛", "character": preload("res://data/characters/goblin_love.tres"), "presentation": preload("res://presentation/characters/goblin_love_presentation.tres")},
    {"id": SALAD_CAT_MANIFEST.id, "name": SALAD_CAT_MANIFEST.display_name, "character": SALAD_CAT_MANIFEST.gameplay_resource, "presentation": SALAD_CAT_MANIFEST.presentation_resource},
    {"id": MAGIC_ORANGE_CAT_MANIFEST.id, "name": MAGIC_ORANGE_CAT_MANIFEST.display_name, "character": MAGIC_ORANGE_CAT_MANIFEST.gameplay_resource, "presentation": MAGIC_ORANGE_CAT_MANIFEST.presentation_resource},
    {"id": &"blade_shield", "name": "我的刀盾", "character": preload("res://data/characters/blade_shield.tres"), "presentation": preload("res://presentation/characters/blade_shield_presentation.tres")},
    {"id": &"pink_star", "name": "粉紅星星", "character": preload("res://data/characters/pink_star.tres"), "presentation": preload("res://presentation/characters/pink_star_presentation.tres")},
    {"id": &"sauce_stubble_dog", "name": "蘸醬胡渣狗", "character": preload("res://data/characters/sauce_stubble_dog.tres"), "presentation": preload("res://presentation/characters/sauce_stubble_dog_presentation.tres")},
    {"id": &"scared_cat", "name": "驚嚇小貓", "character": preload("res://data/characters/scared_cat.tres"), "presentation": preload("res://presentation/characters/scared_cat_presentation.tres")},
    {"id": &"ok_meow_boss", "name": "OK喵老大", "character": preload("res://data/characters/ok_meow_boss.tres"), "presentation": preload("res://presentation/characters/ok_meow_boss_presentation.tres")},
    {"id": &"niu_lai", "name": "牛來", "character": preload("res://data/characters/niu_lai.tres"), "presentation": preload("res://presentation/characters/niu_lai_presentation.tres")},
    {"id": &"bao_la", "name": "豹拉", "character": preload("res://data/characters/bao_la.tres"), "presentation": preload("res://presentation/characters/bao_la_presentation.tres")},
]

static func count() -> int:
    return ENTRIES.size()

static func entry(index: int) -> Dictionary:
    if index < 0 or index >= ENTRIES.size():
        return {}
    return ENTRIES[index]

static func character_by_id(id: StringName) -> CharacterData:
    for item: Dictionary in ENTRIES:
        if item["id"] == id:
            return item["character"] as CharacterData
    return null

static func presentation_by_id(id: StringName) -> CharacterPresentationData:
    for item: Dictionary in ENTRIES:
        if item["id"] == id:
            return item["presentation"] as CharacterPresentationData
    return null
