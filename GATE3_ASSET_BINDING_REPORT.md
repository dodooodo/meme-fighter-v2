# GATE 3 — Production Asset Binding Report

Generated from the current Gate 3 workspace production binding export/resources. Gameplay timing remains MoveData/MoveRunner authoritative; image count does not define simulation frames.

## Summary

- Production WebP files imported: **1717**
- Roster character catalogs: **14/14**
- Binding catalog entries: **980**
- Binding status: **GREEN 978 / YELLOW 2 / RED 0**
- AssetBindingValidator gameplay blockers: **0 RED blockers**
- Pink alias: **`pink_star` → `粉藍星星`**
- Fighter-body anchor: **FEET_CENTER**

### Domain counts

- BASE_FIGHTER: **724**
- MODE_FIGHTER: **105**
- PROJECTILE: **9**
- SUMMON: **51**
- HAZARD: **5**
- WORLD_EFFECT: **81**
- ATTACHMENT: **4**
- ULTIMATE_SCREEN: **1**

## 14-character coverage

| Character | Asset Folder | Bindings | Domains | GREEN | YELLOW | RED | Status |
|---|---|---:|---|---:|---:|---:|---|
| `alien_meow` / Alien Meow | Alien Meow | 89 | BASE_FIGHTER, HAZARD, PROJECTILE, WORLD_EFFECT | 89 | 0 | 0 | GREEN |
| `doge` / Doge | Doge | 40 | BASE_FIGHTER, MODE_FIGHTER, WORLD_EFFECT | 39 | 1 | 0 | GREEN (approved YELLOW fallback present) |
| `ok_meow_boss` / OK喵老大 | OK喵老大 | 74 | ATTACHMENT, BASE_FIGHTER, PROJECTILE, WORLD_EFFECT | 74 | 0 | 0 | GREEN |
| `tempura_penguin` / Oh fuxking 天婦羅尬哩涼 | Oh fuxking 天婦羅尬哩涼 | 77 | BASE_FIGHTER, SUMMON, WORLD_EFFECT | 77 | 0 | 0 | GREEN |
| `ya_mouse` / YA鼠 | YA鼠 | 80 | BASE_FIGHTER, WORLD_EFFECT | 80 | 0 | 0 | GREEN |
| `goblin_love` / 哥布林也想談戀愛 | 哥布林也想談戀愛 | 87 | BASE_FIGHTER, MODE_FIGHTER, WORLD_EFFECT | 87 | 0 | 0 | GREEN |
| `blade_shield` / 我的刀盾 | 我的刀盾 | 38 | BASE_FIGHTER, MODE_FIGHTER, WORLD_EFFECT | 37 | 1 | 0 | GREEN (approved YELLOW fallback present) |
| `salad_cat` / 沙拉貓貓 | 沙拉貓貓 | 75 | BASE_FIGHTER, PROJECTILE, WORLD_EFFECT | 75 | 0 | 0 | GREEN |
| `niu_lai` / 牛來 | 牛來 | 84 | BASE_FIGHTER, WORLD_EFFECT | 84 | 0 | 0 | GREEN |
| `pink_star` / 粉紅星星 | 粉藍星星 | 60 | BASE_FIGHTER, MODE_FIGHTER, PROJECTILE, WORLD_EFFECT | 60 | 0 | 0 | GREEN |
| `sauce_stubble_dog` / 蘸醬胡渣狗 | 蘸醬胡渣狗 | 77 | ATTACHMENT, BASE_FIGHTER, PROJECTILE, WORLD_EFFECT | 77 | 0 | 0 | GREEN |
| `bao_la` / 豹拉 | 豹拉 | 53 | BASE_FIGHTER, MODE_FIGHTER, PROJECTILE, WORLD_EFFECT | 53 | 0 | 0 | GREEN |
| `scared_cat` / 驚嚇小貓 | 驚嚇小貓 | 81 | BASE_FIGHTER, PROJECTILE, SUMMON, WORLD_EFFECT | 81 | 0 | 0 | GREEN |
| `magic_orange_cat` / 魔法胖橘貓 | 魔法胖橘貓 | 65 | BASE_FIGHTER, HAZARD, ULTIMATE_SCREEN, WORLD_EFFECT | 65 | 0 | 0 | GREEN |

## Approved YELLOW fallbacks

- **doge / charge** — `ROUND_2/03_Special_Muscle_Rush`: Approved fallback: hold Muscle Rush anticipation key pose during charge; gameplay charge timing remains MoveData-driven.
- **blade_shield / special_neutral** — `ROUND_2/17_雙刀重攻`: Approved fallback: Dual Heavy key poses + detached 鈍刀蓄斬 VFX; no gameplay impact.

The Blade Dual Special fallback is explicitly presentation-only: Dual Heavy key poses are reused together with the detached Special VFX. It does not change gameplay frame data, hitboxes, damage, charge timing, or cancel legality.
