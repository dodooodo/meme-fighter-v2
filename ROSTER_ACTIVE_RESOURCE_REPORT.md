# ROSTER ACTIVE RESOURCE REPORT

Generated from the current `data/roster_registry.gd` and the resource graph reachable from each ACTIVE `CharacterData`. Shadow/legacy duplicates that are not selected by `RosterRegistry` are not treated as runtime truth.

| CharacterID | DisplayName | Runtime Source | Active CharacterData | Active MoveSet | MechanicsData | Resource | Status | Mode | Projectile | Area | Summon | Hazard | Sequence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `alien_meow` | Alien Meow | Legacy Active Resource | `res://data/characters/alien_meow.tres` | `res://data/move_sets/roster/alien_meow_move_set.tres` | `res://data/characters/alien_meow.tres#SubResource("mech_1")` | — | signal_mark | — | — | — | — | — | alien_position_lock, alien_position_lock_marked |
| `doge` | Doge | Manifest Package | `res://content/characters/doge/gameplay/character.tres` | `res://content/characters/doge/gameplay/move_set.tres` | `res://content/characters/doge/gameplay/character.tres#SubResource("mechanics")` | — | — | super_doge | — | — | — | — | — |
| `ya_mouse` | YA鼠 | Legacy Active Resource | `res://data/characters/ya_mouse.tres` | `res://data/move_sets/roster/ya_mouse_move_set.tres` | `res://data/characters/ya_mouse.tres#SubResource("mech_1")` | — | awkward_slow | — | — | ya_social_zone_l2, ya_social_zone_l3 | — | — | — |
| `tempura_penguin` | Oh fuxking 天婦羅尬哩涼 | Legacy Active Resource | `res://data/characters/tempura_penguin.tres` | `res://data/move_sets/roster/tempura_penguin_move_set.tres` | `res://data/characters/tempura_penguin.tres#SubResource("mech_1")` | — | — | — | — | — | penguin_swarm | — | — |
| `goblin_love` | 哥布林也想談戀愛 | Legacy Active Resource | `res://data/characters/goblin_love.tres` | `res://data/move_sets/roster/goblin_love_move_set.tres` | `res://data/characters/goblin_love.tres#SubResource("mech_1")` | — | — | love_awakened | — | — | — | — | — |
| `salad_cat` | 沙拉貓貓 | Manifest Package | `res://content/characters/salad_cat/gameplay/character.tres` | `res://content/characters/salad_cat/gameplay/move_set.tres` | `res://content/characters/salad_cat/gameplay/character.tres#SubResource("mech_1")` | — | — | — | — | — | — | — | salad_high_low |
| `magic_orange_cat` | 魔法胖橘貓 | Manifest Package | `res://content/characters/magic_orange_cat/gameplay/character.tres` | `res://content/characters/magic_orange_cat/gameplay/move_set.tres` | `res://content/characters/magic_orange_cat/gameplay/character.tres#SubResource("mech_1")` | — | — | — | — | jpeg_circle | — | — | cthulhu_sequence |
| `blade_shield` | 我的刀盾 | Legacy Active Resource | `res://data/characters/blade_shield.tres` | `res://data/move_sets/roster/blade_shield_move_set.tres` | `res://data/characters/blade_shield.tres#SubResource("mech_1")` | — | — | dual_blade | — | — | — | — | — |
| `pink_star` | 粉紅星星 | Legacy Active Resource | `res://data/characters/pink_star.tres` | `res://data/move_sets/roster/pink_star_move_set.tres` | `res://data/characters/pink_star.tres#SubResource("mech_1")` | face_actions | — | true_face | — | — | — | — | — |
| `sauce_stubble_dog` | 蘸醬胡渣狗 | Legacy Active Resource | `res://data/characters/sauce_stubble_dog.tres` | `res://data/move_sets/roster/sauce_stubble_dog_move_set.tres` | `res://data/characters/sauce_stubble_dog.tres#SubResource("mech_1")` | — | sauce | — | sauce_blob_l1, sauce_blob_l2, sauce_blob_l3 | — | — | — | sauce_four_pass |
| `scared_cat` | 驚嚇小貓 | Legacy Active Resource | `res://data/characters/scared_cat.tres` | `res://data/move_sets/roster/scared_cat_move_set.tres` | `res://data/characters/scared_cat.tres#SubResource("mech_1")` | — | panic_exit | — | — | — | husky_guardian | — | — |
| `ok_meow_boss` | OK喵老大 | Legacy Active Resource | `res://data/characters/ok_meow_boss.tres` | `res://data/move_sets/roster/ok_meow_boss_move_set.tres` | `res://data/characters/ok_meow_boss.tres#SubResource("mech_1")` | — | authority_advantage | — | — | — | — | — | — |
| `niu_lai` | 牛來 | Manifest Package | `res://content/characters/niu_lai/gameplay/character.tres` | `res://content/characters/niu_lai/gameplay/move_set.tres` | `res://content/characters/niu_lai/gameplay/character.tres#SubResource("mechanics")` | courage | — | — | — | — | — | — | — |
| `bao_la` | 豹拉 | Legacy Active Resource | `res://data/characters/bao_la.tres` | `res://data/move_sets/roster/bao_la_move_set.tres` | `res://data/characters/bao_la.tres#SubResource("mech_1")` | resolve | — | last_stand | bao_counter_projectile | — | — | — | — |

## Runtime-source summary

- Manifest Package: `doge`, `salad_cat`, `magic_orange_cat`, `niu_lai`.
- Legacy Active Resource: the other ten roster entries resolve directly from the `data/characters` active-resource family via `RosterRegistry`.
- Gameplay graph completeness check performed during report generation: **14/14 GREEN** (required normals, throw, charge entry + three charge levels, Ultimate, unique move IDs, cancel targets, and resource-file existence).

> Gate 3 production frame binding is intentionally outside this report.
