有，而且我會把它做成一套「**Agent Development Operating System**」，而不是只放一個很長的 `AGENTS.md`。

我最推薦的原則是：

> **`AGENTS.md` = 永久規則與地圖**
> **`CLAUDE.md` = Claude 相容層，不重複內容**
> **Specs = 技術真相**
> **Stage Plan = 現在要做到哪裡**
> **Task Packet = 這次究竟要改什麼**
> **Skills = 重複工作的標準 SOP**
> **Scripts / Hooks / CI = 真正強制規則**

這個方向也符合目前 OpenAI 與 Anthropic 自己的建議。OpenAI 特別分享過，巨大的單一 `AGENTS.md` 會因 context、過期與維護問題失效，因此他們傾向讓短 `AGENTS.md` 當「地圖」，詳細知識放結構化 `docs/`。([OpenAI][1]) Claude 官方也建議 `CLAUDE.md` 保持精簡，目標約 200 行以下；多步驟程序應移到 Skill，局部規則則拆成 path-specific rules。([Claude Platform Docs][2])

---

# 我會這樣設計 Dorian

```text
meme-fighter-v2/
│
├─ AGENTS.md
├─ CLAUDE.md
│
├─ docs/
│  ├─ architecture/
│  │  ├─ COMBAT_ARCHITECTURE.md
│  │  ├─ CHARACTER_PACKAGE.md
│  │  ├─ TELEMETRY.md
│  │  ├─ PRESENTATION.md
│  │  ├─ NETWORK_PROTOCOL.md
│  │  ├─ ROLLBACK.md
│  │  └─ PLATFORM_SERVICE.md
│  │
│  ├─ roadmap/
│  │  ├─ PLATFORM_STRATEGY.md
│  │  └─ PRODUCTION_ROADMAP.md
│  │
│  ├─ stages/
│  │  ├─ active/
│  │  │  └─ STAGE_A_EXECUTION.md
│  │  └─ completed/
│  │
│  ├─ tasks/
│  │  ├─ active/
│  │  │  ├─ A-MOD-001.md
│  │  │  ├─ A-MOD-002.md
│  │  │  └─ ...
│  │  └─ completed/
│  │
│  ├─ contributors/
│  │  ├─ FRONTEND.md
│  │  ├─ BACKEND.md
│  │  ├─ ART.md
│  │  ├─ BALANCE.md
│  │  └─ GAMEPLAY.md
│  │
│  └─ adr/
│     ├─ 0001-modular-monorepo.md
│     ├─ 0002-character-package.md
│     └─ ...
│
├─ skills/
│  ├─ implement-task/
│  │  └─ SKILL.md
│  ├─ add-character/
│  │  └─ SKILL.md
│  ├─ modify-balance/
│  │  └─ SKILL.md
│  ├─ add-gameplay-mechanic/
│  │  └─ SKILL.md
│  ├─ verify-character/
│  │  └─ SKILL.md
│  └─ stage-gate-audit/
│     └─ SKILL.md
│
├─ scripts/
│  ├─ verify.sh
│  ├─ validate_task.py
│  ├─ validate_character.py
│  └─ ...
│
├─ battle/
│  └─ AGENTS.md
│
├─ content/
│  └─ characters/
│     └─ AGENTS.md
│
├─ frontend/
│  └─ AGENTS.md
│
└─ server/
   └─ AGENTS.md
```

這比只討論：

```text
AGENTS.md vs CLAUDE.md
```

重要很多。

---

# 1. `AGENTS.md`：我會把它當 Canonical Entry Point

如果你要同時支援：

* Codex
* Claude Code
* 其他 agent
* 未來的人類工程師

我會讓：

# `AGENTS.md` 成為主要 source of truth。

OpenAI Codex 原生支援 `AGENTS.md`，而且可以在不同 directory 放 nested `AGENTS.md`；較深層的檔案會對該 directory tree 提供更具體的規則。([OpenAI][3])

但不要把 2,700 行 Roadmap 塞進去。

Root `AGENTS.md` 我甚至只想控制在：

# 100～150 行。

---

## 我會讓 Root `AGENTS.md` 長這樣

例如：

```md
# Dorian Agent Instructions

## Project

Dorian is a deterministic 2D fighting game built with Godot.

Current production stage:
Stage A — Gameplay / Collaboration Foundation.

See:
- docs/roadmap/PRODUCTION_ROADMAP.md
- docs/stages/active/STAGE_A_EXECUTION.md

## Non-Negotiable Architecture

1. BattleSimulation is the only gameplay authority.
2. Gameplay runs fixed 60 Hz.
3. Presentation must never determine gameplay results.
4. Future-affecting state requires snapshot + restore + hash.
5. Generic core must not branch on character_id.
6. Platform SDKs must not enter combat core.
7. Telemetry must never block simulation.

See:
docs/architecture/COMBAT_ARCHITECTURE.md

## Repository Model

This is a modular monorepo.

Do not create separate repositories for:
- character content
- frontend
- balance
- presentation

Backend may become independent only when explicitly approved.

## Before Editing

1. Read the relevant nested AGENTS.md.
2. Read the task packet.
3. Read linked architecture specs.
4. Inspect existing implementation.
5. Do not expand task scope.

## Required Workflow

Every implementation task:

1. Understand
2. Plan
3. Implement
4. Test
5. Run verification
6. Review diff
7. Update docs if contract changed

## Verification

Run:

./scripts/verify.sh

Character-specific changes:

./scripts/test_character.sh <character_id>

## Task Scope

Never modify files outside the task packet's allowed paths
unless the task explicitly requires it.

## Definition of Done

A task is not complete until:
- required tests pass
- runtime verification passes
- no unrelated files changed
- acceptance criteria are satisfied
- git diff has been reviewed

## Documentation Map

Architecture:
docs/architecture/

Active stage:
docs/stages/active/

Active tasks:
docs/tasks/active/

Contributor guides:
docs/contributors/

Architectural decisions:
docs/adr/
```

這才是好的 `AGENTS.md`。

它不是 encyclopedia。

它是：

> **Agent 的導航首頁。**

這跟 OpenAI 現在公開分享的 agent-first repository 做法非常接近：短 `AGENTS.md` 作為目錄，真正 repository knowledge 放在結構化 docs。([OpenAI][1])

---

# 2. 那 `CLAUDE.md` 怎麼辦？

這裡我反而建議：

# 不要維護第二份規則。

Claude Code 官方現在明確說：

> Claude Code 本身讀的是 `CLAUDE.md`，不是 `AGENTS.md`；如果 repo 已經使用 AGENTS.md，可以在 CLAUDE.md 中 import AGENTS.md。([Claude Platform Docs][2])

所以：

```md
@AGENTS.md

# Claude Code Specific

- Prefer Plan Mode for architecture-changing tasks.
- Use project skills for repeatable workflows.
- Run /verify before declaring implementation complete.
```

就這樣。

---

# 不要這樣

```text
AGENTS.md
300 lines

CLAUDE.md
另外複製 300 lines
```

六個月後一定：

```text
AGENTS:
Godot 4.7.1

CLAUDE:
Godot 4.6.3
```

然後 Claude 和 Codex 做出不同的事。

非常糟。

---

# 我甚至可以讓：

```text
CLAUDE.md
```

只有：

```md
@AGENTS.md
```

Anthropic 官方也直接提供這種做法，而且說 symlink 也可以。([Claude Platform Docs][2])

我的偏好還是 import。

因為：

* Windows 也方便
* 明確
* 可以再加 Claude-specific rule

---

# 3. Nested `AGENTS.md` 非常適合你

這對 modular monorepo 特別重要。

例如：

```text
battle/
└ AGENTS.md
```

寫：

```md
# Gameplay Core

## Rules

Changes here require:

- deterministic regression
- snapshot audit
- restore audit
- hash audit
- replay audit

Never:
- access platform APIs
- perform HTTP
- access presentation Nodes
- branch on character_id
```

---

`content/characters/AGENTS.md`：

```md
# Character Content

Default rule:

Character changes must remain inside:

content/characters/<character_id>/**

Use data before code.

Do not modify battle/ or fighter/ unless the existing
generic mechanic system cannot represent the feature.

Every character must pass:

./scripts/test_character.sh <id>
```

---

`frontend/AGENTS.md`：

```md
# Frontend

Frontend may consume ViewModels and services.

Frontend must not:
- mutate BattleSimulation directly
- access Fighter private internals
- determine combat timing
```

---

`server/AGENTS.md`：

```md
# Backend

Server must not depend on:
- Godot Nodes
- .tscn
- presentation assets

Server owns:
- identity
- matchmaking
- signaling
- telemetry ingestion
- entitlement
```

這樣 Agent working context 會非常乾淨。

---

# 4. Skill 才是你真正可以「標準化流程」的東西

我認為這是最值得你做的。

現在 OpenAI Skills 和 Claude Code Skills 都走 **Agent Skills 開放標準**；核心就是一個 `SKILL.md`，可以帶：

* instructions
* examples
* templates
* scripts
* supporting resources

([OpenAI Help Center][4])

所以：

> **規則用 AGENTS。**
>
> **工作方式用 Skills。**

---

# 例如第一個 Skill

## `implement-task`

```text
skills/
└ implement-task/
   ├ SKILL.md
   ├ task-template.md
   └ scripts/
      └ validate_scope.py
```

SKILL：

```md
---
name: implement-task
description: Execute a Dorian task packet according to the project's standard implementation workflow.
---

# Dorian Task Implementation

Input:

docs/tasks/active/<TASK_ID>.md

## Workflow

1. Read root AGENTS.md.
2. Read the task packet.
3. Read every spec referenced by the task.
4. Inspect existing code.
5. Confirm dependencies are satisfied.
6. Produce implementation plan.
7. Check allowed/forbidden paths.
8. Implement the smallest valid change.
9. Add/update tests.
10. Run task-required checks.
11. Run global verification.
12. Inspect git diff.
13. Verify no forbidden path changed.
14. Verify acceptance criteria one by one.
15. Report:
   - files changed
   - tests run
   - acceptance results
   - risks
   - deferred work

Do not implement work outside the task packet.
```

未來你只需要：

```text
/implement-task A-MOD-002
```

Claude 就跑。

Codex 也可以使用相同 Skill workflow。

---

# 5. 我會替 Dorian 建這幾個 Skills

不是一口氣做 50 個。

第一批我會做大概 **8 個**。

### `implement-task`

任何 Task Packet 的標準施工流程。

### `add-character`

建立 Character Package：

```text
manifest
character data
moves
presentation
tests
validation
```

---

### `modify-balance`

專門讓數值企劃使用。

Input：

```text
character
move
field
old/new
reason
```

只能碰：

```text
content/characters/*/gameplay/**
```

自動：

```text
validate
export diff
run character tests
```

---

### `add-gameplay-mechanic`

這個很重要。

流程強制：

```text
Can existing data express it?
        │
       yes
        ↓
use data
        │
       no
        ↓
Can generic GameplayEffect express it?
        │
       no
        ↓
extend generic mechanic
        │
        ↓
snapshot
restore
hash
tests
```

這會防止：

```gdscript
if character_id == "pink_star":
```

滿天飛。

---

### `add-telemetry-event`

輸入：

```text
event name
purpose
trigger
payload
```

自動：

```text
check naming
schema version
privacy
producer
consumer
tests
dashboard requirement
```

---

### `verify-character`

跑：

```text
resource validation
move validation
presentation coverage
CPU smoke
mirror
golden pair
snapshot/replay
```

---

### `build-character-assets`

美術工作流：

```text
source
→ normalize
→ validate
→ runtime asset
→ bind presentation
```

---

### `prepare-pr`

自動：

```text
git diff
scope audit
tests
docs
risk
PR summary
```

---

### `stage-gate-audit`

例如：

```text
/stage-gate-audit A
```

逐項核對：

```text
Stage A Gate
[pass]
[fail]
[evidence]
```

---

# 6. 但 Skill 不應該保存 architecture truth

非常重要。

不要：

```text
SKILL.md:
CharacterManifest 有 id/name/version...
```

同時：

```text
CHARACTER_PACKAGE.md:
又寫一份
```

這樣又 duplication。

Skill 應該寫：

```text
Follow:
docs/architecture/CHARACTER_PACKAGE.md
```

Skill 是：

> **how**

Spec 是：

> **what**

---

# 7. Task Packet 我會改成 Machine-readable

這是我最建議你下一步採用的改動之一。

不要只有 Markdown prose。

例如：

```md
---
id: A-MOD-002
stage: A
type: architecture
status: ready

dependencies:
  - A-MOD-001

allowed_paths:
  - content/catalog/**
  - content/characters/**
  - tests/roster/**

forbidden_paths:
  - battle/**
  - fighter/**

required_specs:
  - docs/architecture/CHARACTER_PACKAGE.md

required_checks:
  - ./scripts/validate_character_catalog.sh
  - ./scripts/verify.sh
---

# A-MOD-002 CharacterCatalog

## Goal

Replace hard-coded roster registration...

## Acceptance Criteria

- [ ] ...
```

然後：

```text
scripts/validate_task.py
```

可以真的檢查：

```text
git diff
      ↓
allowed_paths
      ↓
PASS / FAIL
```

這就不是「希望 Agent 不要亂改」。

是：

# Agent 亂改，CI 直接擋。

---

# 8. 這帶出另一個重要原則

## Prompt / Markdown 不等於 Enforcement。

Anthropic 官方自己也特別說明，`CLAUDE.md` 是 context，不是強制配置；如果真的需要阻擋某個行為，要用 hook。([Claude Platform Docs][2])

所以我的標準化層級會是：

```text
Soft
│
├ AGENTS.md
├ CLAUDE.md
├ Skills
├ Specs
│
▼
Hard
├ scripts
├ hooks
├ pre-commit
└ CI
```

例如：

### Rule

```text
Character task must not modify battle/**
```

不要只寫 AGENTS。

還要：

```text
validate_task.py
```

真的檢查。

---

# 9. 我甚至會建立統一 Agent Lifecycle

所有 agent task 都跑：

```text
                 TASK PACKET
                      │
                      ▼
                UNDERSTAND
                      │
              read specs/rules
                      │
                      ▼
                    PLAN
                      │
              dependency check
                      │
                      ▼
                 IMPLEMENT
                      │
               smallest diff
                      │
                      ▼
                   TEST
                      │
               targeted tests
                      │
                      ▼
                  VERIFY
                      │
               global verify
                      │
                      ▼
                 SCOPE AUDIT
                      │
            allowed paths check
                      │
                      ▼
                 SELF REVIEW
                      │
                    diff
                      │
                      ▼
                ACCEPTANCE
                      │
            criteria one-by-one
                      │
                      ▼
                     PR
```

這一整個流程就是：

```text
implement-task Skill
```

---

# 10. 再加 GitHub Issue / PR template

Task Packet 甚至可以跟 issue 一一對應。

```text
Issue
#123

Task:
A-MOD-002

Spec:
docs/tasks/active/A-MOD-002.md
```

PR：

```text
Implements: A-MOD-002

## Scope

## Changed files

## Tests

## Acceptance Criteria

## Architecture Impact

## Snapshot/Replay Impact

## Telemetry Impact

## Remaining Risks
```

OpenAI 自己也建議給 coding agent 的 prompt 可以寫得像 GitHub Issue：包含具體 component、paths、預期行為等。([OpenAI][5])

---

# 11. 最後才是 CLAUDE-specific `.claude/rules`

這個我會用，但只拿來做：

> Claude Code optimization。

例如：

```text
.claude/rules/
├ gameplay.md
├ frontend.md
└ server.md
```

Claude 支援 `paths:` frontmatter，只在讀符合路徑時載入該規則，能節省 context。([Claude Platform Docs][2])

例如：

```md
---
paths:
  - "battle/**/*.gd"
  - "fighter/**/*.gd"
---

When modifying deterministic gameplay:

- audit snapshot
- audit restore
- audit hash
- run replay regression
```

但這不是跨-agent source of truth。

Canonical rule 還是：

```text
AGENTS.md
+
docs/
```

---

# 所以整體 responsibility 我會定成這樣

| 東西                     | 負責什麼                                   |
| ---------------------- | -------------------------------------- |
| **AGENTS.md**          | 永久、跨 agent、全局規則                        |
| nested `AGENTS.md`     | 模組局部規則                                 |
| **CLAUDE.md**          | AGENTS compatibility + Claude-specific |
| `.claude/rules`        | Claude path-aware optimization         |
| **Architecture Specs** | 技術 source of truth                     |
| **Stage Execution**    | 當前階段工作                                 |
| **Task Packet**        | 單次施工規格                                 |
| **Skills**             | 重複 SOP                                 |
| Scripts                | 自動驗證                                   |
| Hooks                  | 即時阻擋                                   |
| CI                     | 最終 enforcement                         |
| ADR                    | 為什麼做這個架構決策                             |

---

# 我會把這套東西稱為

例如：

```text
Dorian Engineering System
```

而不是：

```text
Claude setup
```

這很重要。

因為今天：

```text
Claude Code
```

明天：

```text
Codex
```

後天：

```text
另一個 agent
```

核心開發流程都不用重寫。

---

## 如果由我幫你現在真正落地，我會照這個順序

**第一層先建立：**

```text
AGENTS.md
CLAUDE.md
docs/architecture/
docs/stages/
docs/tasks/
```

然後把我們目前已有的 roadmap/spec 重整進去。

**第二層建立三個核心 Skill：**

```text
implement-task
verify-change
prepare-pr
```

這三個先讓所有 Agent 都走相同 lifecycle。

**第三層才做 domain skills：**

```text
add-character
modify-balance
add-mechanic
add-telemetry-event
build-art
```

**第四層做 enforcement：**

```text
validate_task.py
validate_architecture.py
verify.sh
CI required checks
```

做到這裡之後，你其實已經不是單純「用 Claude Code 寫遊戲」。

你是在建立一個：

> **任何 Agent / 工程師 / 美術 / Balance designer 都有明確 input、可修改範圍、流程與 Definition of Done 的 production system。**

這會比再多寫五千行 roadmap 對後續多人協作更有價值。

[1]: https://openai.com/index/harness-engineering/?utm_source=chatgpt.com "Harness engineering: leveraging Codex in an agent-first world | OpenAI"
[2]: https://docs.anthropic.com/en/docs/claude-code/memory "How Claude remembers your project - Claude Code Docs"
[3]: https://openai.com/zh-Hans-CN/index/introducing-codex/?utm_source=chatgpt.com "Codex 简介 | OpenAI"
[4]: https://help.openai.com/en/articles/20001066-skills-in-chatgpt?utm_source=chatgpt.com "Skills in ChatGPT | OpenAI Help Center"
[5]: https://openai.com/business/guides-and-resources/how-openai-uses-codex/?utm_source=chatgpt.com "How OpenAI uses Codex | OpenAI"
