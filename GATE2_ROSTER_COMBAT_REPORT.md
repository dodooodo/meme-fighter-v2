# GATE 2 ROSTER COMBAT REPORT

Gate 2 gameplay closeout report generated from the current active roster graph, Gate-2 character contract tests, completeness tooling, and the dedicated Snapshot/Restore/Hash scenario suite. Godot runtime availability is reported separately from static gameplay completeness.

| Character | Active Data | Normals | Throw | Lv1 | Lv2 | Lv3 | Ultimate | Unique Mechanic | Snapshot | Contract Tests | Completeness | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Alien Meow (`alien_meow`) | GREEN (Legacy Active) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| Doge (`doge`) | GREEN (Package) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| YA鼠 (`ya_mouse`) | GREEN (Legacy Active) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| Oh fuxking 天婦羅尬哩涼 (`tempura_penguin`) | GREEN (Legacy Active) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| 哥布林也想談戀愛 (`goblin_love`) | GREEN (Legacy Active) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| 沙拉貓貓 (`salad_cat`) | GREEN (Package) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| 魔法胖橘貓 (`magic_orange_cat`) | GREEN (Package) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| 我的刀盾 (`blade_shield`) | GREEN (Legacy Active) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| 粉紅星星 (`pink_star`) | GREEN (Legacy Active) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| 蘸醬胡渣狗 (`sauce_stubble_dog`) | GREEN (Legacy Active) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| 驚嚇小貓 (`scared_cat`) | GREEN (Legacy Active) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| OK喵老大 (`ok_meow_boss`) | GREEN (Legacy Active) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| 牛來 (`niu_lai`) | GREEN (Package) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |
| 豹拉 (`bao_la`) | GREEN (Legacy Active) | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | GREEN | **GREEN** |

## Snapshot coverage

1. **Alien Signal Mark** — `_test_alien_signal_mark_snapshot`
2. **Alien Position Lock recorded coordinate** — `_test_alien_position_lock_snapshot`
3. **Doge Super** — `_test_doge_super_mode_snapshot`
4. **Penguin summon auxiliary state** — `_test_penguin_summon_aux_snapshot`
5. **Mage Trap** — `_test_magic_trap_arming_snapshot`
6. **Blade Dual Mode** — `_test_blade_dual_mode_snapshot`
7. **Pink Face Actions** — `_test_pink_true_face_resource_snapshot`
8. **Pink Dash Cancel count** — `_test_pink_dash_cancel_snapshot`
9. **Sticky extended_once** — `_test_sauce_sticky_extended_once_snapshot`
10. **Panic Exit** — `_test_scared_panic_exit_snapshot`
11. **Husky runtime lock/cooldown** — `_test_husky_runtime_snapshot`
12. **Niu Courage Lv2** — `_test_niu_courage_snapshot`
13. **Bao Last Stand Resolve 2** — `_test_bao_last_stand_snapshot`

- Snapshot schema: **BattleStateSnapshot VERSION 10**.
- Replay schema: **1**.
- Replay combat-rules version: **5**.
- The scenario suite is `tests/snapshot/test_gate2_snapshot_scenarios.gd` and is registered as `GATE2_SNAPSHOT_SCENARIOS_SUITE` in `tests/run_tests.gd`.

## Completeness evidence

- Active roster entries resolved: **14/14**.
- Gameplay graph check: **14/14 GREEN**.
- Character contract test files present: **14/14**.
- Required Gate-2 snapshot scenarios present: **13/13**.
- Final production frame binding is intentionally deferred to Gate 3.

## Runtime Verification

`NOT EXECUTED — executable unavailable`
