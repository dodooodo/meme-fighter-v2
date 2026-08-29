# Dorian / Meme Fighter v2 — Production Roadmap（Stage A → G）

> 文件用途：給 Coding Agent / Agentic Engineering / 協作者直接執行的 production implementation plan。
>
> 文件版本：2026-08-22
>
> 對應策略文件：`DORIAN_PLATFORM_STRATEGY_ZH-TW.md`
>
> 平台順序：**Web/PWA → Steam → Native Mobile（條件式）**
>
> 核心原則：**先證明遊戲好玩、再證明團隊能低摩擦製作內容、再擴平台、最後商業化與 Native Mobile。**

---

# 0. Executive Summary

本 Roadmap 以平台策略中的七個 Stage 作為唯一頂層進度模型：

```text
Stage A — Gameplay / Collaboration Foundation
    ↓
Stage B — Web Alpha
    ↓
Stage C — Public Web Beta
    ↓
Stage D — Steam Presence
    ↓
Stage E — Steam Client
    ↓
Stage F — Monetization
    ↓
Stage G — Mobile Decision
```

每個 Stage 都必須同時回答五件事：

1. **產品是否成立？**
2. **程式架構是否允許多人低摩擦協作？**
3. **資料是否足夠做下一個決策？**
4. **平台是否值得投入下一階段工程？**
5. **前一個 Stage 是否真的通過 Gate？**

本 Roadmap 不把「完成大量功能」視為成功，而把「通過可量測的 Gate」視為成功。

---

# 1. Non-Negotiable Architecture Rules

任何 Agent 在修改程式前都必須遵守以下規則。

## 1.1 Simulation Authority

唯一 gameplay authority：

```text
BattleSimulation
```

禁止：

```text
Animation finished → Apply Damage
Area2D overlap → Decide Hit
Tween finished → Change Fighter State
UI button callback → Directly mutate HP
Network packet → Directly set Fighter position
```

正確：

```text
InputSource
    ↓
InputFrame
    ↓
BattleSimulation
    ↓
authoritative state
    ↓
CombatEvent / ViewModel
    ↓
Presentation / UI / Audio / VFX
```

## 1.2 Gameplay Time

Gameplay 只使用 fixed 60Hz simulation frame。

禁止：

- wall clock 決定 combat
- render delta 決定 move frame
- animation playback position 決定 hit frame
- Timer node timeout 決定 round combat outcome

## 1.3 Future-Affecting State

任何會影響未來 simulation 的資料，都必須同時具備：

```text
snapshot
restore
hash
```

若新增 mechanic 沒有做到三者，不得 merge。

## 1.4 Character Rule

禁止 generic core 出現：

```gdscript
if character_id == "doge":
    ...
```

角色差異優先放在：

```text
CharacterData
MoveData
MoveSetData
CharacterMechanicsData
generic mechanic resources
```

若真的需要新規則，先證明它是一個可重用 generic mechanic，再進 core。

## 1.5 Presentation Rule

美術不可決定：

- hitbox
- hurtbox
- pushbox
- damage
- move timing
- invulnerability
- meter
- round outcome

Sprite frame 數量與 gameplay frame 完全解耦。

## 1.6 Telemetry Rule

Combat core 不得：

```text
直接 HTTP POST
直接寫 DB
等待 analytics response
因 telemetry failure stall simulation
```

Telemetry 必須是旁路：

```text
Gameplay event
    ↓
Telemetry adapter
    ↓
EventBuffer
    ↓ async
Sink / HTTP / Local File
```

## 1.7 Platform Rule

平台 SDK 不得滲入 combat core。

```text
Steam
Web
Apple
Google
```

只能透過 platform adapters / services 接入。

## 1.8 Repository Rule

現階段維持 **modular monorepo**。

不要拆：

```text
engine repo
art repo
balance repo
characters repo
frontend repo
```

第一個合理獨立 repo 是 backend，且只有當 deploy / secrets / ownership 已明顯獨立時才拆。

---

# 2. Current Baseline — Agent 不得重做

目前 `meme-fighter-v2` 已經不是早期 M5 greybox。

Agent 應視以下能力為既有 baseline，先 audit 再修改：

- fixed 60Hz BattleSimulation
- normalized InputFrame
- Fighter HFSM
- MoveRegistry / MoveRunner
- data-driven CharacterData / MoveData
- projectile system
- round / match lifecycle
- replay foundation
- snapshot / restore / hash
- CPU InputSource
- charge special runtime
- presentation foundation
- HUD / camera / VFX / audio hooks
- production presentation asset pipeline
- multiple roster resources
- character-specific presentation resources
- existing static validator / test runner

已知需要繼續處理的 architecture debt：

- Godot runtime CI truthfulness
- authoritative float collision / damping debt
- cross-platform determinism proof
- monolithic per-character move-set resources
- central roster preload / registry coupling
- production presentation coverage 不一致
- Web/PWA export productionization
- rollback coordinator 尚未 production-ready
- online backend 尚未完成
- production telemetry backend 尚未完成
- platform identity / entitlement 尚未完成

---

# 3. Target Modular Monorepo

目標結構：

```text
res://
├─ app/
│  ├─ navigation/
│  ├─ services/
│  └─ state/
│
├─ frontend/
│  ├─ home/
│  ├─ mode_select/
│  ├─ character_select/
│  ├─ matchmaking/
│  ├─ settings/
│  └─ store/
│
├─ battle/
│  ├─ simulation/
│  ├─ combat/
│  ├─ match/
│  ├─ replay/
│  └─ rollback/
│
├─ fighter/
│  ├─ input/
│  ├─ state/
│  ├─ movement/
│  ├─ moves/
│  ├─ mechanics/
│  └─ meter/
│
├─ content/
│  ├─ characters/
│  │  └─ <character_id>/
│  │     ├─ manifest.tres
│  │     ├─ gameplay/
│  │     │  ├─ character.tres
│  │     │  ├─ move_set.tres
│  │     │  ├─ moves/
│  │     │  └─ mechanics/
│  │     ├─ presentation/
│  │     │  ├─ presentation.tres
│  │     │  ├─ visuals/
│  │     │  ├─ vfx/
│  │     │  └─ audio/
│  │     └─ tests/
│  ├─ stages/
│  └─ shared/
│
├─ presentation/
│  ├─ runtime/
│  ├─ shared/
│  └─ tooling/
│
├─ platform/
│  ├─ web/
│  ├─ steam/
│  ├─ mobile/
│  └─ platform_service.gd
│
├─ telemetry/
│  ├─ events/
│  ├─ buffer/
│  ├─ sinks/
│  └─ telemetry_service.gd
│
├─ network/
│  ├─ protocol/
│  ├─ transport/
│  ├─ matchmaking/
│  └─ rollback/
│
├─ tests/
├─ scripts/
└─ docs/

server/                     # monorepo 初期可放這裡
├─ src/
│  ├─ api/
│  ├─ matchmaking/
│  ├─ signaling/
│  ├─ telemetry/
│  ├─ identity/
│  ├─ entitlement/
│  └─ commerce/
└─ migrations/
```

---

# 4. Collaboration Ownership Contract

## Frontend / UI

主要 ownership：

```text
frontend/**
app/navigation/**
app/state/**
```

不得：

- 直接修改 Fighter HP / meter
- 直接讀 MoveRunner private internals
- 用 animation/UI timing 控 gameplay

## Backend

主要 ownership：

```text
server/**
network/protocol/**
```

不得：

- 依賴 Godot Node / `.tscn`
- 把 gameplay state streaming 當 authority

## Art / Presentation

主要 ownership：

```text
content/characters/*/presentation/**
presentation/**
assets/runtime/**
```

不得：

- 修改 gameplay timing
- 以 PNG alpha 當 authoritative collision

## Balance / Game Data

主要 ownership：

```text
content/characters/*/gameplay/character.tres
content/characters/*/gameplay/moves/*.tres
```

理想狀態：調整 startup/damage/recovery/hitstun 等不需要寫 GDScript。

## Skill / Mechanic

優先改：

```text
MoveData
GameplayConditionData
GameplayEffectData
CharacterMechanicsData
```

只有 generic data model 無法表達時才擴 runtime。

## Core Gameplay

主要 ownership：

```text
battle/**
fighter/**
```

任何 core change 都需要：

- regression test
- snapshot/hash impact audit
- replay determinism audit
- 至少一個既有角色 regression

---

# 5. Stage Overview

| Stage | 產品狀態 | 平台 | 核心輸出 | 下一 Gate |
|---|---|---|---|---|
| A | 3 角色 offline MVP + collaboration foundation | Local/Web dev | 可玩、可製作、可量測 | Web-ready |
| B | 私人 Web Alpha | Web/PWA | 真實裝置與小群測試 | Public-ready |
| C | Public Web Beta | Web/PWA | 真實 DAU / retention / reliability | Steam client justified |
| D | Steam Presence | Steam Store | Coming Soon + wishlist | Store traction |
| E | Steam Native Client | Steam + Web | Windows native + cross-play | Production Steam |
| F | Monetization | Web + Steam | Premium fighters + entitlement | Sustainable business |
| G | Native Mobile Decision | iOS/Android conditional | GO / NO-GO | Mobile rollout or stay Web+Steam |

---

# 6. STAGE A — Gameplay / Collaboration Foundation

## 6.1 Stage A Goal

Stage A 的目標不是「功能最多」，而是建立一個可以被多人持續製作的遊戲基礎。

完成時應達到：

```text
2 個 production-quality vertical slice fighters
+
第 3 個 mechanic-diverse fighter
+
Character Package
+
低衝突資料結構
+
本地 telemetry
+
可靠 runtime CI
```

推薦 Golden Pair：

- `magic_orange_cat`
- `salad_cat`

第三隻 architecture stress fighter：

- `doge`

第三隻的價值是驗證 charge / mode / mechanic extension，而不是單純增加 roster 數字。

---

## 6.2 A0 — Runtime Truth

### `A-RUN-001` Pin Godot Version

- CI / local / docs 使用同一 stable version。
- 禁止 agent 自行升 dev/RC。

Acceptance：

```text
godot --version
```

與 CI 完全一致。

### `A-RUN-002` Fix verify.sh false-green

若 Godot executable 不存在：

```text
CI = FAIL
```

不得 `exit 0`。

### `A-RUN-003` Runtime Test Command

統一：

```bash
godot --headless --path . --editor --quit
godot --headless --path . -s res://tests/run_tests.gd
python3 scripts/static_validate.py
```

### `A-RUN-004` 10k Tick Stress Runtime

必須真的執行，不只 source-authored。

### `A-RUN-005` CI Required Check

PR 必須通過：

```text
static validation
runtime tests
character validation
replay regression
```

---

## 6.3 A1 — Golden Pair Vertical Slice

### `A-VS-001` Golden Pair Gameplay Audit

對兩隻角色逐項驗證：

- walk forward / back
- crouch
- jump
- dash / backstep
- guard high/low
- light
- heavy
- low
- air attack
- throw
- special
- ultimate
- hit reaction
- knockdown / getup
- KO

### `A-VS-002` Presentation Coverage Matrix

每個 gameplay state / move 都必須有：

```text
production visual
OR explicit fallback
```

不允許 silent missing animation。

### `A-VS-003` Art Source Defect Cleanup

修所有已知 source frame 缺漏。

### `A-VS-004` Game Feel Pass

統一調整：

- hitstop tiers
- hit VFX
- block VFX
- hit SFX
- guard SFX
- camera impulse
- white flash
- KO presentation
- ultimate screen

但不得改 gameplay truth。

### `A-VS-005` 3-Minute Match Soak

每組角色：

```text
CPU vs CPU
Local vs CPU
Local 2P
```

至少連續 10 場無 crash / state leak。

### `A-VS-006` Manual Feel Checklist

人工驗證：

- input 是否可靠
- movement 是否可控
- hit impact 是否清楚
- block feedback 是否可辨認
- special / ultimate 是否容易理解
- KO / retry flow 是否順

---

## 6.4 A2 — Character Package

### `A-MOD-001` CharacterManifest v1

最少欄位：

```text
id
display_name
version
gameplay_resource
presentation_resource
portrait
icon
content_pack_id
availability
```

### `A-MOD-002` CharacterCatalog

取代中央角色 hard-coded preload。

API 目標：

```gdscript
CharacterCatalog.list_manifests()
CharacterCatalog.get_manifest(id)
CharacterCatalog.load_gameplay(id)
CharacterCatalog.load_presentation(id)
CharacterCatalog.register_pack(pack)
```

### `A-MOD-003` Golden Pair Package Migration

只先搬 Golden Pair。

不要一次搬 14 隻。

### `A-MOD-004` Split MoveData

將單一巨大 move-set resource 拆成：

```text
moves/
├ stand_light.tres
├ stand_heavy.tres
├ crouch_low.tres
├ air_attack.tres
├ ground_throw.tres
├ special_neutral.tres
├ ultimate.tres
└ mechanic-specific moves...
```

`move_set.tres` 只引用 MoveData。

### `A-MOD-005` Package Template

建立：

```text
content/characters/_template/
```

新增角色流程不得要求修改 combat core。

### `A-MOD-006` Character Validator

驗證：

- manifest id unique
- character id match
- presentation id match
- move ids unique
- required moves present
- missing resource refs
- missing art binding
- invalid frame data
- impossible cancel target
- duplicate projectile id

### `A-MOD-007` Per-Character Test Command

例如：

```bash
./scripts/test_character.sh doge
```

---

## 6.5 A3 — Contributor Tooling

### `A-COL-001` CODEOWNERS

至少區分：

```text
battle/fighter core
frontend
presentation/art
character content
server
```

### `A-COL-002` Role-Based PR Templates

建立：

- Balance PR
- Art PR
- Skill PR
- Frontend PR
- Backend PR

### `A-COL-003` Balance Table Export

能輸出 CSV/Markdown：

```text
character
move
startup
active
recovery
damage
hitstun
blockstun
meter
range approximation
```

### `A-COL-004` Balance Import Strategy

若支援 spreadsheet round-trip，必須：

- stable IDs
- schema validation
- diff preview
- 不允許 raw overwrite without validation

### `A-COL-005` One-Command Art Build

輸入 art manifest → 輸出 normalized runtime assets。

### `A-COL-006` Mechanic Authoring Guide

包含：

- 能用資料就不用 code
- 何時新增 GameplayEffectData
- 何時新增 CharacterMechanicsData
- 何時真的需要 runtime component
- snapshot/hash checklist

### `A-COL-007` Merge Conflict Simulation

以 4 個平行 branch 模擬：

- art
- balance
- frontend
- skill

驗證是否能在同一角色工作但不碰相同中央檔案。

### `A-COL-008` Character Content Index

一份 read-only join，串起 move data、presentation binding、與 build 出來的
SpriteFrames，同時餵給三個消費者：

```text
CharacterValidator          → CI 硬錯誤
scripts/content_report.gd   → 協作者可讀的 markdown 報告
editor dock（A-COL-009）    → 人看的檢視介面
```

必須擋下的靜默失敗：

- binding 指向 SpriteFrames 裡不存在的 animation
- move 完全沒有 presentation binding
- 條件式 variant 沒有覆蓋整個 resource 範圍且無 unconditional fallback

必須可見但不擋 CI：

- 已 build 但沒有任何 binding 引用的 animation
- 只覆蓋部分 base animation 的 mode pack

已知未綁定的 move 寫在 `content/validation/unbound_moves_allowlist.json`，
每筆需要 reason 與 blocked_on，並在補上 binding 的同一個 PR 移除。

注意：`MoveData.animation_id` 不是綁定路徑，runtime 不讀它。

### `A-COL-009` Character Content Dock

把 `A-COL-008` 的 index 搬進 Godot 編輯器（`addons/character_content_inspector`），
唯讀。回答協作者最常問的兩個問題：

```text
這隻角色有哪些技能、各自綁哪支動畫？
我改完之後，那支動畫實際會長什麼樣？
```

分頁：Moves / States / Animations / Issues，加上用角色真實 SpriteFrames
播放的預覽（fps 與 loop 取自 build manifest）。

嚴禁：任何寫入路徑。dock 與 CI 讀同一份 index，兩者不可能給出不同答案。

`Import art pack` 按鈕保留位置但停用，實作屬於 `A-COL-010`。

---

## 6.6 A4 — Telemetry Foundation

Implementation status: complete on 2026-08-23. Stage A now writes bounded local
Event Envelope v1 JSONL and replay-correlated match evidence; remote ingestion
remains B4 scope.

### `A-DATA-001` Identity Vocabulary

本地先建立：

```text
installation_id
session_id
match_id
round_id
event_id
```

登入後才增加：

```text
user_id
```

### `A-DATA-002` Event Envelope v1

```json
{
  "event_name": "move.summary",
  "event_version": 1,
  "event_id": "...",
  "occurred_at": "...",
  "installation_id": "...",
  "session_id": "...",
  "match_id": "...",
  "round_id": "...",
  "build_id": "...",
  "content_version": "...",
  "platform": "...",
  "payload": {}
}
```

### `A-DATA-003` Match Summary

每場至少：

- fighter ids
- winner
- round count
- match duration
- CPU / local / online mode
- build/content versions
- disconnect reason
- replay id

### `A-DATA-004` Move Telemetry

至少：

- use count
- hit
- block
- whiff
- punish
- counter hit
- damage
- distance bucket
- corner state

### `A-DATA-005` Mastery Events

- anti-air success
- whiff punish success
- throw success
- combo completion
- guard success
- ultimate finish

### `A-DATA-006` Performance Events

- FPS buckets
- long frame
- memory snapshot
- load duration
- asset pack load duration
- crash/error

### `A-DATA-007` Local Telemetry Sink

先寫：

```text
user://telemetry/*.jsonl
```

### `A-DATA-008` Replay Correlation

每個 match summary 必須可追到 replay blob / file。

### `A-DATA-009` No Per-Frame Analytics Rows

normalized InputFrame 走 replay stream，不走 analytics event row。

---

## 6.7 A5 — Third Character

Implementation status: the seven A5 outcomes are present and automated checks
are green. Final acceptance remains pending the human play checklist in
`docs/stages/active/A5_MANUAL_VERIFICATION.md`.

### `A-MVP-001` Migrate Doge Package

### `A-MVP-002` Split Doge Moves

### `A-MVP-003` Production Presentation

### `A-MVP-004` Charge Regression

### `A-MVP-005` Character Select v1

只需要：

- 3 fighters
- name
- available state
- local/CPU start
- preserve the established P1/P2 selector layout; portrait remains package
  metadata for later art/UI work

### `A-MVP-006` Training Minimum

- reset
- dummy guard
- frame/hitbox debug toggle
- input display

### `A-MVP-007` Tutorial Minimum

只教：

- movement
- guard
- light/heavy
- throw
- special
- ultimate

---

## 6.8 Stage A Gate

全部成立才進 Stage B：

- [ ] 3 fighters 可完整打完 match
- [ ] Golden Pair production visuals 完整
- [x] Doge mechanic 不需 character-id branch
- [x] Character Package 已實際使用
- [x] MoveData 已拆檔
- [x] 新增角色不需修改中央 registry
- [ ] CI 真跑 Godot runtime
- [x] replay determinism regression 綠
- [x] local telemetry 可產生 match/move/performance data
- [x] 角色 package 可被單獨驗證
- [x] 4 類協作者 ownership boundary 已文件化

---

# 7. STAGE B — Web Alpha

## 7.1 Stage B Goal

把 Stage A 的遊戲放到真實瀏覽器，讓小群朋友 / 社群測試。

這一階段目標不是流量，而是驗證：

```text
Godot Web export
+
PWA
+
手機/桌機瀏覽器穩定
+
遠端 telemetry
```

---

## 7.2 B1 — Web Export

### `B-WEB-001` Web Export Preset

要求：

- Compatibility renderer
- single-threaded first
- deterministic core unchanged
- release build reproducible

### `B-WEB-002` Core Payload Budget

定義 core shell budget。

首次載入不得塞全部 14 角色 assets。

### `B-WEB-003` Content Manifest

```json
{
  "content_version": "...",
  "packs": [...]
}
```

### `B-WEB-004` Character PCK Build

每角色可獨立輸出 content pack。

### `B-WEB-005` AssetPackManager

職責：

- fetch
- cache
- hash verify
- mount
- version check
- retry
- failure UI

### `B-WEB-006` Dynamic Catalog Register

pack mount 後 CharacterCatalog 能動態看到角色。

---

## 7.3 B2 — PWA

### `B-PWA-001` Manifest

### `B-PWA-002` Service Worker / Cache Policy

區分：

```text
immutable hashed assets
versioned catalog
HTML shell
replay/telemetry API
```

### `B-PWA-003` Update Strategy

舊 client 不得載入不相容 content silently。

### `B-PWA-004` Install UX

不強迫使用者安裝 PWA。

---

## 7.4 B3 — Web Device QA

至少：

- Desktop Chrome
- Desktop Edge
- Desktop Firefox
- Desktop Safari
- Android Chrome
- iPhone Safari
- installed PWA where available

### Acceptance

- 可進主選單
- 可下載角色 pack
- 可完成 10 場 CPU/local match
- 無持續 memory growth
- audio 不失效
- reload 後 cache 正常
- orientation / resize 不破 UI

---

## 7.5 B4 — Remote Telemetry v1

### `B-DATA-001` Telemetry Batch API

```http
POST /v1/telemetry/batch
```

### `B-DATA-002` Client EventBuffer

- batch
- retry
- max buffer
- drop policy
- app close flush best-effort

### `B-DATA-003` Initial Storage

小規模可先：

```text
Postgres
+
Object Storage for replay/raw archive
```

不要一開始 Kafka / ClickHouse。

### `B-DATA-004` Data Quality

監控：

- missing session id
- duplicate event id
- unknown event version
- impossible timestamps
- missing match end

---

## 7.6 B5 — Alpha Test Operations

### `B-OPS-001` Invite-Only URL

### `B-OPS-002` Build ID Visible

### `B-OPS-003` Feedback Form Linked to Match ID

### `B-OPS-004` Crash/Error Collection

### `B-OPS-005` Manual Replay Upload / Download

---

## 7.7 Stage B Gate

- [ ] Web release build reproducible
- [ ] Desktop browsers stable
- [ ] Android browser playable
- [ ] iPhone Safari 能完成 30-minute soak
- [ ] PWA install/update 不破 cache
- [ ] remote telemetry ingestion 正常
- [ ] replay 可與 match telemetry 關聯
- [ ] 有至少一批非開發者完成測試
- [ ] 主要 gameplay bug 可由 telemetry/replay 定位

---

# 8. STAGE C — Public Web Beta

## 8.1 Stage C Goal

第一次面對不可預測的真實流量。

這一階段要取得：

```text
real DAU
real retention
real device mix
real session length
real match volume
real crash rate
real content popularity
```

並驗證 viral spike 不會拖垮系統。

---

## 8.2 C1 — Public UX

### `C-UX-001` Home Flow

```text
Open
→ Play
→ Character Select
→ CPU / Local / Online（若 online 已開）
```

### `C-UX-002` First-Time User Flow

首次遊玩不要要求帳號。

### `C-UX-003` Fast Retry

KO → rematch/retry 不應重新載入全部 core。

### `C-UX-004` Settings

- volume
- controls
- quality
- vibration where supported
- telemetry/privacy disclosure

---

## 8.3 C2 — Reliability & Viral Safety

### `C-SEC-001` Connection Caps

```text
MAX_ACTIVE_CONNECTIONS
MAX_QUEUE_SIZE
MAX_HUMAN_MATCHES
MAX_WS_RELAY_MATCHES
```

### `C-SEC-002` Rate Limits

- telemetry
- signaling
- queue
- content credential endpoints

### `C-SEC-003` Kill Switches

至少：

```text
HUMAN_MATCHMAKING_ENABLED
WS_RELAY_ENABLED
PREMIUM_PURCHASE_ENABLED
```

### `C-SEC-004` Parser Hardening

所有 public packet / URL / JSON boundaries 必須 malformed-safe。

### `C-SEC-005` Origin / CORS Policy

---

## 8.4 C3 — Product Analytics

建立 dashboard：

### Acquisition

- landing visits
- game loaded
- tutorial started/completed
- first match started/completed

### Engagement

- matches/player/day
- session duration
- rematch rate
- fighter selection

### Retention

- D1
- D7
- D30 later

### Combat

- character win rate
- matchup win rate
- move usage/hit/block/whiff/punish
- average round duration

### Device

- desktop/mobile share
- browser share
- crash by device
- load time by device

---

## 8.5 C4 — Online Foundation（若 Web Beta 要含真人 Online）

### `C-NET-001` Protocol Version

### `C-NET-002` WebSocket Control Channel

### `C-NET-003` FIFO Random Queue

### `C-NET-004` 30s CPU Fallback

### `C-NET-005` Readiness Barrier

### `C-NET-006` TURN Credential Issuance

### `C-NET-007` Browser WebRTC DataChannel

Anonymous random match：

```text
iceTransportPolicy = relay
```

### `C-NET-008` ICE Path Verification

selected candidate 必須 relay。

### `C-NET-009` WS Relay Fallback

必須 hard cap。

---

## 8.6 C5 — Rollback Productionization

### `C-RB-001` Integer Collision Hardening

### `C-RB-002` Cross-Platform Golden Trace

### `C-RB-003` Snapshot Ring

### `C-RB-004` Remote Input Prediction

hold-last first。

### `C-RB-005` Earliest Mismatch Rollback

### `C-RB-006` Resimulation Presentation Suppression

### `C-RB-007` Confirmed Frame Results

### `C-RB-008` Network Simulation Tests

測：

- 30ms
- 80ms
- 150ms
- packet loss
- burst loss
- reordering

---

## 8.7 Stage C Gate

Stage C 不要求巨大 DAU，但必須取得真實產品訊號。

- [ ] public URL 穩定
- [ ] 有真實非內部玩家
- [ ] 玩家不只打一場就全部離開
- [ ] 可量測 D1 / D7
- [ ] 可量測 desktop/mobile device mix
- [ ] crash/error 有 dashboard
- [ ] load time 有 dashboard
- [ ] balance metrics 可查
- [ ] viral spike 有安全 caps
- [ ] 若 online 開放：matchmaking / TURN / rollback 可觀測
- [ ] Steam store assets 已開始製作

---

# 9. STAGE D — Steam Presence

## 9.1 Stage D Goal

**先取得 Steam storefront 與 wishlist，不等待 Steam client 完成。**

Stage D 不應阻塞 Stage C Web Beta。

---

## 9.2 D1 — Steamworks Onboarding

### `D-STEAM-001` Steam Direct

- 建立 partner account
- 支付 product fee
- 完成 tax/bank verification
- 取得 AppID

### `D-STEAM-002` Release Calendar

記錄：

- mandatory waiting period
- Coming Soon minimum duration
- review lead time

不要把平台等待期誤認成 engineering time。

---

## 9.3 D2 — Store Asset Package

### `D-STORE-001` Key Art

### `D-STORE-002` Capsule Set

### `D-STORE-003` Screenshots

必須是 gameplay truth，不使用假 UI。

### `D-STORE-004` Trailer v1

30–60 秒，優先：

```text
梗角色
→ 真實 combat
→ 三角色差異
→ Ultimate
→ 3-minute quick match proposition
```

### `D-STORE-005` Copy

- short description
- long description
- features
- supported platforms
- online status truthfully stated

### `D-STORE-006` Tags

---

## 9.4 D3 — Wishlist Funnel

Web 增加：

```text
Wishlist on Steam
```

Telemetry：

- Steam CTA impression
- Steam CTA click
- UTM source

不要假裝知道真正 wishlist conversion，Steam 數據作為最終 truth。

---

## 9.5 D4 — Steam Playtest Preparation

建立 private branch / Playtest 設定，但 client 可尚未 ready。

---

## 9.6 Stage D Gate

- [ ] Steam AppID ready
- [ ] Coming Soon page approved/live
- [ ] wishlist 可以累積
- [ ] Web → Steam CTA 可追蹤
- [ ] store assets production quality
- [ ] release waiting rules 已滿足/排程中
- [ ] Steam client engineering 未阻塞 Web iteration

---

# 10. STAGE E — Steam Client

## 10.1 Stage E Goal

將已驗證的 Web product 變成正式 Windows native Steam client，並保持與 Web 共用 gameplay / backend / telemetry。

---

## 10.2 E1 — Platform Adapter Layer

### `E-PLAT-001` PlatformService Interface

```gdscript
get_platform_name()
get_platform_user_token()
is_feature_available(feature)
open_store_page(...)
set_rich_presence(...)
unlock_achievement(...)
```

Web / Steam 分別實作。

Combat core 不可 import Steam SDK。

---

## 10.3 E2 — Windows Native Build

### `E-WIN-001` Windows Export Preset

### `E-WIN-002` Save Paths

### `E-WIN-003` Fullscreen / Windowed / Resolution

### `E-WIN-004` Audio Lifecycle

### `E-WIN-005` Native Crash Logging

### `E-WIN-006` Controller Device Matrix

至少：

- Xbox
- DualSense
- 8BitDo-class
- fight stick / leverless where accessible

---

## 10.4 E3 — SteamPipe / CI

### `E-PIPE-001` Steam Content Builder

```text
scripts/steam/
├ app_build.vdf
├ depot_windows.vdf
└ upload script
```

### `E-PIPE-002` Private Beta Branch

### `E-PIPE-003` CI Artifact → Steam Upload

### `E-PIPE-004` Release Rollback Procedure

---

## 10.5 E4 — Steam Identity

### `E-ID-001` Platform Identity Table

```text
user_id
provider
provider_user_id
created_at
```

### `E-ID-002` Steam Auth Client

### `E-ID-003` Backend Verify

### `E-ID-004` Link Dorian Account

Steam identity 不等於 canonical user id。

---

## 10.6 E5 — Steam Features

### `E-FEAT-001` Achievements

優先從既有 telemetry/mastery event 對應。

### `E-FEAT-002` Rich Presence

### `E-FEAT-003` Steam Cloud（optional but recommended）

只同步 local settings / non-authoritative local data。

Premium entitlement 不放 Steam Cloud。

### `E-FEAT-004` Steam Input / Remap

Platform device input 最後仍 normalize 成 InputFrame。

---

## 10.7 E6 — Cross-Play

原則：

```text
Web + Steam
→ same matchmaking backend
→ same protocol
→ same rollback model
```

不要把 gameplay networking 綁死 Steam-only transport。

### `E-XPLAY-001` Build Compatibility Handshake

至少交換：

- protocol version
- combat rules version
- content version
- character package hashes

### `E-XPLAY-002` Web vs Steam Match Test

### `E-XPLAY-003` Replay Cross-Platform Hash Test

### `E-XPLAY-004` Controller vs Touch Analytics

---

## 10.8 E7 — Steam Playtest

先 Playtest，再正式 release。

Telemetry 比較：

```text
Web desktop
vs
Steam Windows
```

看：

- retention
- session duration
- rematch
- controller usage
- crash
- matchmaking wait

---

## 10.9 Stage E Gate

- [ ] Steam Windows native build 穩定
- [ ] SteamPipe CI 可重複
- [ ] Steam identity 可驗證
- [ ] Web/Steam 共用 backend
- [ ] cross-play 可完成多場 match
- [ ] cross-platform replay/hash 相容
- [ ] controller mapping production-ready
- [ ] Steam Playtest 有真實玩家
- [ ] release rollback procedure 演練過

---

# 11. STAGE F — Monetization

## 11.1 Stage F Goal

只有 gameplay / retention 已取得足夠訊號後，才開始把 Premium Fighters 做成正式商業系統。

核心原則：

```text
Free core game
+
Premium Fighters
+
Bundles
+
Cosmetics / Supporter content
```

禁止 P2W stats growth。

---

## 11.2 F1 — Canonical Account

### `F-ACC-001` User Table

### `F-ACC-002` Platform Identity Linking

未登入仍可玩免費內容。

購買前才要求 account linking。

---

## 11.3 F2 — Entitlement Service

Canonical truth：

```text
user_id
owns
content_id
source_platform
purchase_reference
status
```

### `F-ENT-001` Entitlement Table

### `F-ENT-002` Server Query API

### `F-ENT-003` Cache Policy

### `F-ENT-004` Revocation / Refund

### `F-ENT-005` Online Character Selection Validation

Client 不可信。

---

## 11.4 F3 — Web Commerce

### `F-WEBPAY-001` Provider Adapter

### `F-WEBPAY-002` Checkout

### `F-WEBPAY-003` Idempotent Webhook

### `F-WEBPAY-004` Purchase Receipt UI

### `F-WEBPAY-005` Restore Entitlement via Account

---

## 11.5 F4 — Steam Commerce

### `F-STPAY-001` Steam Purchase Adapter

### `F-STPAY-002` Server Verification

### `F-STPAY-003` Entitlement Grant

### `F-STPAY-004` Refund/Revoke

### `F-STPAY-005` Duplicate Purchase Safety

---

## 11.6 F5 — Premium Fighter UX

角色選擇：

```text
FREE
OWNED
LOCKED
TRY IN TRAINING
```

### `F-UX-001` Training Trial

付費角色可 training 試玩。

### `F-UX-002` Bundle UI

### `F-UX-003` Store Failure States

### `F-UX-004` No Mid-Match Commerce

---

## 11.7 F6 — Commerce Telemetry

至少：

- store_opened
- product_viewed
- trial_started
- checkout_started
- checkout_completed
- checkout_failed
- entitlement_granted
- entitlement_revoked

Dashboard：

- payer conversion
- ARPPU
- revenue by product
- refund rate
- store funnel
- premium fighter usage

---

## 11.8 F7 — Content Production Economics

每隻 Premium Fighter release 前必須有：

- development effort estimate
- art effort estimate
- expected conversion scenario
- break-even estimate
- balance test
- online compatibility
- telemetry definition

不要只因角色「很有梗」就直接 production。

---

## 11.9 Stage F Gate

- [ ] Web/Steam canonical entitlement 共用
- [ ] client spoof 無法進官方 paid-fighter online match
- [ ] refund/revocation 可測
- [ ] purchase webhook idempotent
- [ ] commerce funnel 可量測
- [ ] premium fighter training trial 可用
- [ ] 免費玩家仍有完整可玩的核心遊戲
- [ ] premium fighter 不具競技數值付費優勢

---

# 12. STAGE G — Native Mobile Decision

## 12.1 Stage G Goal

Stage G 首先是 **投資決策**，不是自動開始做 iOS / Android。

分析：

```text
mobile traffic
+
mobile web retention
+
performance/crash gap
+
monetization potential
+
engineering/QA burden
```

最後輸出：

```text
GO
NO-GO
DEFER
```

---

## 12.2 G0 — Mobile Decision Dataset

必須至少能回答：

### Traffic

- mobile share
- iOS vs Android share
- new users by device

### Experience

- load time
- crash rate
- FPS
- memory failure
- touch input issues

### Retention

- mobile D1 / D7
- desktop D1 / D7
- PWA installed vs browser-only retention

### Engagement

- matches/session
- session length
- rematch rate

### Commerce

- mobile web checkout conversion
- payer conversion by device

---

## 12.3 G1 — GO Criteria

Native Mobile 值得做的典型訊號：

- mobile traffic 已經顯著
- mobile Web retention 明顯落後 desktop
- 落後原因很可能由 native 解決
- touch control 本身已證明有人願意玩
- mobile performance / Safari/Web limitations 是主要瓶頸
- 有能力維護額外 store pipelines
- incremental revenue 足以合理支持新增 QA/engineering

不使用單一 KPI 作判斷。

---

## 12.4 G2 — NO-GO / DEFER Criteria

若：

- mobile traffic 很低
- mobile 玩家本身 engagement 低，不是技術問題
- Web/PWA 已經足夠穩定
- Steam traction 明顯高於 mobile
- 團隊仍無力維護 iOS/Android QA

則：

```text
NO-GO / DEFER
```

繼續 Web + Steam。

---

## 12.5 G3 — If GO: Mobile Platform Adapter

同樣禁止 mobile SDK 進 combat core。

```text
PlatformService
├ WebPlatformService
├ SteamPlatformService
├ IOSPlatformService
└ AndroidPlatformService
```

---

## 12.6 G4 — Android Native

### `G-AND-001` Android Export Pipeline

### `G-AND-002` Signing / CI

### `G-AND-003` Native Safe Area

### `G-AND-004` Touch / Haptics

### `G-AND-005` Performance Matrix

至少：

- low-end
- mid-range
- flagship
- 60Hz
- 120Hz

### `G-AND-006` Play Billing Adapter

### `G-AND-007` Entitlement Reconciliation

### `G-AND-008` Data Safety Disclosure Inputs

---

## 12.7 G5 — iOS Native

### `G-IOS-001` Xcode Export Pipeline

### `G-IOS-002` Signing / Provisioning

### `G-IOS-003` Device Safe Area

### `G-IOS-004` Audio / background / lifecycle

### `G-IOS-005` StoreKit Adapter

### `G-IOS-006` Entitlement Reconciliation

### `G-IOS-007` App Privacy Disclosure Inputs

### `G-IOS-008` Device QA

至少：

- older supported iPhone
- recent standard iPhone
- Pro/high refresh where relevant

---

## 12.8 G6 — Cross-Platform Account & Purchase

Canonical account 不變。

```text
Dorian User
├ Web identity
├ Steam identity
├ Apple identity
└ Google identity
```

Entitlement source 可不同，但 ownership truth 統一由 backend 整理。

---

## 12.9 G7 — Mobile Soft Launch

若 GO，不直接 global launch。

先：

```text
internal
→ closed test
→ limited soft launch
→ compare with Web mobile cohort
```

---

## 12.10 Stage G Gate

### Decision Gate

- [ ] mobile dataset 足夠
- [ ] GO/NO-GO 有書面 rationale
- [ ] incremental revenue / retention hypothesis 明確

### If GO

- [ ] Android/iOS release pipeline reproducible
- [ ] store billing → canonical entitlement 正常
- [ ] native retention 能與 mobile Web cohort 比較
- [ ] platform privacy/data disclosures 與實際 telemetry 相符
- [ ] native 不破 cross-play protocol

---

# 13. Shared Backend Roadmap Across Stages

Backend 不再另成一條與產品脫節的 phase，而是隨 Stage 演進。

## Stage A

```text
none / local only
```

## Stage B

```text
telemetry ingest
replay upload
basic build config
```

## Stage C

```text
matchmaking
signaling
TURN credential
rate limits
live telemetry
```

## Stage D

```text
Steam UTM / store support only
```

## Stage E

```text
Steam identity verification
cross-play compatibility
```

## Stage F

```text
canonical users
platform identities
payments
entitlements
refund/revoke
```

## Stage G

```text
Apple/Google identity
StoreKit/Play Billing validation
cross-platform entitlement
```

---

# 14. Data Architecture Across Stages

## Event Envelope

任何 stage 都不允許各 feature 自創完全不同格式。

核心欄位：

```text
event_name
event_version
event_id
occurred_at
installation_id
user_id?
session_id
match_id?
build_id
content_version
platform
payload
```

## Storage Layers

### Queryable relational

```text
users
platform_identities
sessions
matches
match_participants
rounds
entitlements
purchases
```

### Event / archive

```text
telemetry raw archive
replay blobs
crash artifacts
```

### Aggregates

```text
character_stats_daily
matchup_stats_daily
move_stats_daily
retention_cohorts
network_stats_daily
platform_stats_daily
commerce_stats_daily
```

## Privacy

不要蒐集沒有產品用途的敏感資料。

預設 pseudonymous analytics。

必須 future-proof：

```text
user deletion
identity unlink
data retention policy
```

---

# 15. CI/CD by Stage

## Stage A CI

```text
static validate
Godot runtime tests
replay/hash tests
per-character validator
```

## Stage B CI

新增：

```text
Web export
asset pack build
manifest validation
browser smoke
```

## Stage C CI

新增：

```text
backend tests
protocol codec tests
load tests scheduled
network simulation
```

## Stage D CI

不需要為 store presence 增加 gameplay CI。

## Stage E CI

新增：

```text
Windows export
Steam branch artifact
platform adapter tests
cross-platform replay tests
```

## Stage F CI

新增：

```text
commerce webhook tests
entitlement tests
refund/revoke tests
purchase state machine tests
```

## Stage G CI

若 GO：

```text
Android build
Android signing
mobile integration tests
iOS export/signing pipeline
store sandbox purchase tests
```

---

# 16. Test Matrix

## Gameplay Determinism

每次 core change：

- fresh simulation hash
- snapshot restore hash
- replay final hash
- same input repeated N times

## Character Content

每角色：

- required move ids
- move timeline legality
- resource refs
- presentation binding
- CPU smoke
- mirror match
- vs Golden Pair smoke

## Web

- cache miss
- cache hit
- content update
- interrupted PCK download
- offline shell
- browser resize
- mobile orientation

## Online

- high latency
- packet loss
- reordering
- disconnect
- reconnect policy
- TURN unavailable
- WS relay cap
- protocol mismatch

## Steam

- no Steam client
- Steam client offline
- identity unavailable
- cloud conflict
- controller hot-plug
- overlay
- update / rollback branch

## Commerce

- success
- cancel
- timeout
- duplicate webhook
- refund
- revoked entitlement
- user has item already

## Mobile

- cold launch
- background/resume
- incoming interruption
- safe area
- thermal / long session
- purchase restore

---

# 17. Observability Requirements

至少 dashboard：

## Product

- DAU / WAU / MAU
- D1 / D7
- matches/player/day
- session length
- rematch rate

## Combat

- pick rate
- win rate
- matchup
- move usage
- hit/block/whiff/punish
- round duration

## Platform

- Web vs Steam vs Mobile
- crash rate
- load time
- FPS
- controller/touch split

## Online

- queue wait
- match success
- TURN success
- WS fallback
- disconnect
- rollback frames
- desync

## Commerce

- product views
- checkout start
- payment success
- payer conversion
- refund
- ARPPU

---

# 18. Security Requirements by Stage

## Before Public Web Beta

- parser length caps
- WebSocket message caps
- rate limit
- Origin allowlist
- queue caps
- connection caps
- TURN credential TTL
- no provider secret in client

## Before Steam Release

- platform token server verification
- no client-authoritative user identity
- build/version handshake

## Before Monetization

- server entitlement authority
- webhook signature validation
- idempotency
- refund/revoke
- admin audit log

## Before Native Mobile

- App Store / Play purchase server validation
- privacy disclosure inventory
- data deletion path

---

# 19. Platform Cost Gates

Roadmap 不用固定把所有服務升級。

## Stage A

接近 $0 infra。

## Stage B

以免費/低成本 static hosting + telemetry storage 為主。

## Stage C

開始有：

- Render/backend
- TURN
- DB
- object storage

以實際 match minutes / traffic 決定升級。

## Stage D

增加 Steam Direct fixed product fee 與 store asset production effort。

## Stage E

主要新增的是 engineering / QA，不是高額 platform hosting。

## Stage F

增加 payment fees / store revenue share / tax operations。

## Stage G

增加 store account、native QA、release maintenance，真正昂貴的是維護矩陣而不是單次上架費。

---

# 20. Agent Work Protocol

## 20.1 每張 Task 必須有

```text
Task ID
Goal
Allowed files
Forbidden files
Dependencies
Implementation notes
Tests
Acceptance criteria
Rollback notes
```

## 20.2 一個 PR 一個責任

不要：

```text
新增角色
+
重構 battle core
+
改 UI
+
升 Godot
```

同一 PR。

## 20.3 Agent 修改 Character Package

預設只允許：

```text
content/characters/<id>/**
```

若要碰：

```text
battle/**
fighter/**
```

必須在 PR 描述證明「現有 generic mechanic 無法表達」。

## 20.4 Generated Files

若 asset pipeline 產生可再生檔案，必須標記 source-of-truth 與 generated boundary。

## 20.5 No Silent Version Bump

任何：

- snapshot schema
- replay schema
- combat rules version
- network protocol
- content manifest

變更都要顯式 bump + compatibility/failure test。

---

# 21. Stage Critical Path

真正 critical path：

```text
Stage A
3 playable fighters
→ Character Package
→ Runtime truth
→ Local telemetry

Stage B
Web export
→ PCK
→ Device QA
→ Remote telemetry

Stage C
Public reliability
→ Real retention data
→ Rollback/Online if enabled

Stage D
Steam Coming Soon
→ Wishlist accumulation

Stage E
Windows native
→ Steam identity
→ Cross-play
→ Steam Playtest

Stage F
Accounts
→ Entitlement
→ Web/Steam commerce

Stage G
Mobile data
→ ROI decision
→ Native only if justified
```

---

# 22. Parallel Workstreams

可平行：

## Stage A

```text
Golden Pair art
Balance tooling
Character Package
CI runtime
Telemetry schema
```

但 Character Package schema 需先 freeze 才大量搬角色。

## Stage B

```text
Web export
PWA shell
PCK tooling
Telemetry backend
Device QA
```

## Stage C

```text
Public UX
Security
Dashboards
Rollback
Online backend
```

## Stage D

幾乎可完全與 Stage C 後半平行：

```text
Steam store art
Trailer
Copy
Coming Soon
```

## Stage E

```text
Windows build
Steam platform adapter
SteamPipe
Steam identity
Controller
```

Cross-play 依賴 native client + backend compatibility。

## Stage F

```text
Web checkout
Steam purchase
Entitlement backend
Store UI
Commerce analytics
```

Entitlement schema 必須先 freeze。

---

# 23. What Is Explicitly Deferred

除非 Gate 需要，不要提前做：

- Kubernetes
- Redis cluster
- Kafka
- ClickHouse
- dedicated authoritative gameplay server
- ranked ladder
- seasons
- battle pass
- guilds
- chat
- spectator mode
- replay video export
- 20+ fighters before core proven
- native iOS/Android before Stage G GO
- Linux/macOS Steam native before Windows traction
- Steam-only networking architecture

---

# 24. Production Definition of Done

Dorian 可稱為 production product，不代表 Stage G 一定完成。

最小 Production Definition of Done（Web + Steam）：

## Gameplay

- deterministic 60Hz combat
- 3+ production-ready fighters
- stable round/match lifecycle
- CPU / training
- rollback-safe state

## Collaboration

- modular monorepo
- Character Package
- per-move resources
- ownership boundaries
- CI validators

## Web

- PWA
- lazy content packs
- CDN
- mobile browser support

## Online

- random matchmaking
- CPU fallback
- relay-only anonymous path
- rollback
- observability

## Steam

- native Windows build
- SteamPipe
- Steam identity
- controller support
- cross-play
- store presence

## Data

- session/match/move telemetry
- replay linkage
- retention dashboards
- crash/performance metrics

## Security

- rate limits
- caps
- secrets server-only
- protocol validation

## Operations

- CI/CD
- staging
- release rollback
- kill switches

## Monetization（若 Stage F 已啟用）

- server-side entitlement
- purchase/refund correctness
- non-P2W paid content

Native Mobile 不屬於 Web+Steam production 的必要條件。

---

# 25. Final Decision Logic

Agent / 團隊不得用「下一個功能很酷」決定 roadmap。

使用：

```text
Stage A Gate passed?
    no → 留在 A
    yes
      ↓
Stage B real-device Web works?
    no → 留在 B
    yes
      ↓
Stage C real players retain?
    no → 改 gameplay/product，不急著加平台
    yes
      ↓
Stage D Steam wishlist presence
      ↓
Stage E Steam native justified?
    no → Web 繼續
    yes → ship Steam
      ↓
Stage F monetization justified?
    no → grow/retain first
    yes → paid fighters
      ↓
Stage G mobile native ROI positive?
    no → Web + Steam
    yes → iOS/Android
```

最終產品原則：

> **Web 是 acquisition engine。Steam 是核心玩家與長期 retention / revenue home。Native Mobile 是資料證明值得後才投入的 expansion platform。**

---

# 26. Immediate Next Tasks

若從今天開始執行，本週優先順序：

```text
1. A-RUN-001 ~ A-RUN-005
2. A-VS-001 ~ A-VS-006
3. A-MOD-001 ~ A-MOD-004
4. A-DATA-001 ~ A-DATA-004
5. Golden Pair 完整 playtest
6. 再開始 Doge package migration
```

不要先做：

```text
Steam SDK
Payment
App Store
20-character roster
```

因為目前最高 leverage 仍然是：

```text
讓 2–3 個角色真的好玩
+
讓其他協作者能安全快速地一起製作
+
讓每一輪 playtest 都留下可分析的資料
```
