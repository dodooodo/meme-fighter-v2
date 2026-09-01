# GATE 3 — CPU Profile Report

CPU remains a deterministic **InputSource**. It produces canonical InputFrames only; it does not mutate Fighter HP/position/meter, start moves directly, spawn entities directly, or read current physical player buttons.

## Difficulty profiles

| Difficulty | Reaction Delay | Decision Error | Decision Interval |
|---|---:|---:|---:|
| Beginner | 24–36F | 30% | 9F |
| Normal | 15–24F | 18% | 6F |
| Hard | 9–15F | 8% | 4F |
| Expert | 6–10F | 4% | 3F |

## Character utility profiles

| Character | Archetype | Preferred Range | Main Action Bias | Defense Bias | Meter / Resource / Unique Behavior |
|---|---|---:|---|---|---|
| `alien_meow` | Range / Scan Control | 13000–36000 sim units | S Lv3 58, Heavy 58, Ultimate 45, S Lv2 45 | retreat 38, guard 42, backstep 25, jump 22 | resource 48, mode 35; Mid-long poke/scan control; avoids unnecessary close commitment. |
| `bao_la` | Counter / Retaliation | 10000–28000 sim units | counter 94, S Lv3 70, Heavy 62, S Lv2 55 | retreat 68, guard 56, backstep 42, jump 18 | resource 52, mode 38; Bait/backwalk/counter/punish; Last Stand only under sensible conditions. |
| `blade_shield` | Defensive Bruiser / Install | 9000–25000 sim units | S Lv3 60, Heavy 56, S Lv2 52, Ultimate 45 | retreat 32, guard 72, backstep 30, jump 12 | resource 34, mode 64; Base defends midrange; Dual mode increases offensive pressure and does not Guard. |
| `doge` | Power Bruiser | 7000–22000 sim units | Heavy 72, approach 65, S Lv3 55, S Lv2 48 | retreat 18, guard 28, backstep 14, jump 12 | resource 35, mode 45; Slow approach, Heavy/throw punish and favorable Muscle Rush. |
| `goblin_love` | Grappler / Psychological Pressure | 0–13000 sim units | throw 88, approach 82, S Lv3 72, S Lv2 64 | retreat 18, guard 28, backstep 18, jump 15 | resource 48, mode 60; Close strike/command-grab mix; grab utility rises only in range. |
| `magic_orange_cat` | Trap Mage / Setplay Zoner | 17000–36000 sim units | trap 88, S Lv3 72, S Lv2 60, Ultimate 52 | retreat 62, guard 48, backstep 32, jump 20 | resource 35, mode 38; Sets/protects trap, then pushes opponent toward trap/hazard. |
| `niu_lai` | Growth / Level-Up All-Rounder | 9000–26000 sim units | S Lv3 76, S Lv2 62, Ultimate 58, Heavy 55 | retreat 28, guard 42, backstep 22, jump 18 | resource 72, mode 42; Build Courage, preserve high level when valuable, cash out at meaningful reward. |
| `ok_meow_boss` | Authority / Capture | 7000–24000 sim units | anti-air 86, Ultimate 66, Heavy 66, S Lv3 60 | retreat 28, guard 54, backstep 18, jump 16 | resource 44, mode 58; Authority pressure, anti-air Heavy and grounded close capture threat. |
| `pink_star` | Mode Change Rushdown | 8000–30000 sim units | S Lv3 62, S Lv2 55, Ultimate 54, Light 52 | retreat 34, guard 38, backstep 20, jump 20 | resource 68, mode 78; Base sonic midrange; True Face resource-aware close rushdown. |
| `salad_cat` | Keep-away / Pushback | 16000–32000 sim units | S Lv3 66, Heavy 62, S Lv2 58, Low 48 | retreat 68, guard 46, backstep 34, jump 18 | resource 25, mode 30; Maintains Heavy range and resets neutral with pushback. |
| `sauce_stubble_dog` | Debuff Attrition / Projectile | 12000–30000 sim units | S Lv3 72, S Lv2 64, Ultimate 62, approach 56 | retreat 34, guard 36, backstep 22, jump 18 | resource 64, mode 42; Apply Sticky, pressure slowed target, cash out Ultimate intelligently. |
| `scared_cat` | Hit-and-Run / Panic | 9000–26000 sim units | summon 66, S Lv3 62, approach 56, S Lv2 54 | retreat 62, guard 38, backstep 70, jump 20 | resource 40, mode 44; Hit, consume Panic Exit to reposition, use Husky distraction. |
| `tempura_penguin` | Summon Rushdown / Swarm | 6000–22000 sim units | summon 82, approach 72, Ultimate 60, S Lv3 58 | retreat 16, guard 30, backstep 16, jump 24 | resource 30, mode 40; Advance/carry and summon; pressures while swarm is active. |
| `ya_mouse` | Evasion / Debuff Trickster | 18000–38000 sim units | trap 66, S Lv3 64, S Lv2 60, S Lv1 48 | retreat 78, guard 36, backstep 55, jump 42 | resource 20, mode 12; Retreat/debuff spacing; strongly avoids corner/close commitment. |

## Determinism / legality

- Reaction uses delayed observable-state history, not current physical-input reading.
- Random variation uses deterministic integer mixing from seed + decision counter + fighter identity; no system time/RNG.
- Selected actions are converted to ordinary InputFrames and remain subject to normal startup, recovery, charge, meter, resource, mode and cancel legality.
- Replay truth remains normalized InputFrames; CPU internal decisions are not replay truth.
