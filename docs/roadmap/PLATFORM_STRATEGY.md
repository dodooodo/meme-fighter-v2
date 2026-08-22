# Dorian 遊戲平台選擇與發布順序策略報告

> 文件用途：產品決策 / 技術 Roadmap / 商業模式規劃 / Coding Agent 與協作者共同參考  
> 文件日期：2026-08-22  
> 適用專案：Dorian / Meme Fighter v2（Godot 4.x）  
> 核心問題：Dorian 應優先選擇 Web/PWA、Steam，或 iOS / Android App Store？應以什麼順序投入？

---

# 0. Executive Summary

## 0.1 結論

Dorian 不應把 Web/PWA、Steam、App Store / Google Play 視為「三選一」。

建議把它們定義成三個不同階段與不同功能的發行通路：

```text
Phase 1 — Web / PWA
    = 拉新、社群傳播、零安裝試玩、快速驗證 PMF

Phase 2 — Steam
    = 核心玩家主場、Wishlist、長期留存、PC 付費與社群

Phase 3 — iOS / Android Native
    = PMF 驗證後，把成熟產品放大到手機市場
```

建議發布順序：

```text
3-character Vertical Slice
        ↓
Modular Architecture + Telemetry
        ↓
Web Alpha
        ↓
Web Public Beta
        │
        ├──────────────→ Steam Coming Soon / Wishlist
        │
        ↓
PMF / Retention / Device Data
        │
        ├──────────────→ Steam Native Release
        │
        ↓
Mobile Web Data
        ↓
Native Mobile Business Case成立？
        │
       YES
        ↓
iOS / Android Native
```

### 建議優先級

1. **現在：Web/PWA — 必做**
2. **Web Alpha / Beta 期間：提早建立 Steam Coming Soon — 高優先**
3. **Web 已驗證玩法與留存後：Steam Native — 高優先**
4. **有足夠 mobile traffic 且 mobile Web 明顯成為 bottleneck 後：iOS / Android Native — 條件式投入**

---

# 1. Dorian 的產品特性決定了平台策略

Dorian 不是一般單機遊戲。

目前產品方向具有以下特性：

- 1v1 橫向格鬥。
- 單場約 3 分鐘。
- 新玩家可能連打約 3–10 場。
- 迷因角色具高度社群分享能力。
- 低輸入門檻，但保留 spacing、block、throw、whiff punish、meter、matchup 等格鬥深度。
- 目標可支援 CPU、Training、Random Matchmaking、Rollback Online。
- 部分角色未來可能採 Premium Fighter 一次性解鎖。
- 希望 Web、Steam、Mobile 最終可共用帳號、角色 ownership、match history 與 telemetry。
- Combat core 採 deterministic fixed 60Hz simulation。
- Gameplay / Presentation 分離。
- 角色與招式走 data-driven architecture。

因此平台選擇最重要的不是單純「哪個平台人口最多」，而是以下五個問題：

1. 哪個平台最容易讓陌生人第一次進來？
2. 哪個平台最容易讓玩過的人回來？
3. 哪個平台最容易形成有意義的多人 matchmaking population？
4. 哪個平台最適合 Premium Fighter / Cosmetics 商業模式？
5. 哪個平台的工程成本最符合目前專案階段？

---

# 2. 三平台不是同一種 distribution channel

## 2.1 Web/PWA 的角色

> **Acquisition / Viral / Instant Trial**

Web 最大價值不是「瀏覽器很強」，而是：

```text
社群貼文
↓
點 URL
↓
幾秒內進遊戲
↓
直接玩
```

它解決的是：

> 「怎麼讓一個本來完全沒想下載遊戲的人願意試？」

---

## 2.2 Steam 的角色

> **Qualified Gamer Audience / Retention / Community / Commerce**

Steam 使用者開 Steam 的時候，本身就有高度遊戲意圖。

Steam 官方目前列出約：

- 132 million Monthly Active Users。
- 1 trillion daily impressions。
- 29+ languages。
- 35+ currencies。

Steam 對 Dorian 最大價值不是「下載平台」，而是：

```text
Wishlist
Discovery
Reviews
Friends Activity
Community Hub
Achievements
Steam Input
Events / Announcements
Discount visibility
Library persistence
```

它解決的是：

> 「第一次玩過的人，怎麼變成真正長期留下來的玩家？」

---

## 2.3 Native Mobile 的角色

> **Scale / Frequency / Habit / Better Mobile Runtime**

Native iOS / Android 最大價值：

```text
App icon 永遠在手機
↓
無聊時點一下
↓
打一場 3 分鐘
```

這很適合 Dorian 的短局設計。

但 Mobile Native 不應成為第一階段，因為它帶來：

- Store review。
- signing / provisioning。
- IAP。
- privacy declaration。
- device fragmentation。
- native crash QA。
- Store screenshots / metadata。
- 不同平台 billing / entitlement integration。

它解決的是：

> 「已經證明有人喜歡這個遊戲之後，怎麼把它變成更高頻、更大規模的產品？」

---

# 3. 總體比較

| 評估面向 | Web / PWA | Steam | iOS / Android Native |
|---|---:|---:|---:|
| 潛在可觸及人口 | ★★★★★ | ★★★★ | ★★★★★ |
| Gamer intent 密度 | ★★★ | ★★★★★ | ★★★★ |
| 社群 Viral | ★★★★★ | ★★★ | ★★★ |
| 點擊→第一次遊玩摩擦 | ★★★★★ | ★★★ | ★★★ |
| 平台內自然曝光 | ★ | ★★★★★ | ★★★★ |
| 回訪 / 留存 | ★★★ | ★★★★★ | ★★★★★ |
| Library / Icon persistence | ★★～★★★ | ★★★★★ | ★★★★★ |
| 玩家付費信任 | ★★★ | ★★★★★ | ★★★★★ |
| 自有支付彈性 | ★★★★★ | ★★ | ★★ |
| 平台商業抽成 | 最低 | 中～高 | 中 |
| Godot runtime 效能 | ★★★ | ★★★★★ | ★★★★★ |
| 初期工程成本 | ★★★★★ | ★★★★ | ★★ |
| QA 成本 | ★★★ | ★★★★ | ★★ |
| 更新速度 | ★★★★★ | ★★★★★ | ★★★ |
| Viral Spike 承載 | 需自管 backend | 下載由 Steam 管 | Store + backend |
| 最適合 Dorian 階段 | 現在 | 第二階段 | PMF 後 |

---

# 4. 使用者基數：不要只看「平台人口」

## 4.1 Web

Web 沒有一個可以直接和 Steam MAU 對比的單一「Web gamer MAU」。

優勢是幾乎所有 Desktop / Mobile browser 都可能成為入口。

真正重要的是：

```text
Addressable browser population 很大
≠
真正會玩 Dorian 的人口很大
```

Web 流量完全取決於：

- Threads / IG / TikTok / Discord。
- Influencer。
- Reddit。
- SEO。
- 社群分享。
- 自己的 marketing。

因此：

> Web 的「可觸及人口」最大，但「平台自己幫你找玩家」最弱。

---

## 4.2 Steam

Steam 官方 Steamworks 頁面目前列出 **132M MAU**。

這個數字雖然遠小於全球手機設備數，但 user intent 品質更高：

```text
Steam 使用者打開 Steam
≈ 現在就想找 / 買 / 玩遊戲
```

對 Dorian 這種 indie fighter，這種 audience quality 通常比 raw population 更重要。

Steam 還提供：

- Wishlists。
- Store traffic analytics。
- UTM analytics。
- Discovery surfaces。
- Steam Playtest。
- Community Hub。
- Friends activity。
- Reviews。

因此 Steam 是三者中最適合形成「核心玩家群」的平台。

---

## 4.3 iOS / Android

Apple 2026-01 官方宣布 installed base 已超過 **2.5 billion active Apple devices**。

Android 亦屬全球數十億裝置級平台。

但：

```text
Active mobile device
≠
Mobile gamer
≠
會玩 1v1 fighter 的 gamer
```

Native mobile 的最大價值，不是單純人口，而是：

> 使用者每天都拿著同一台 device，而且 App icon 可以永久存在。

因此 Mobile 的 retention potential 很高。

---

# 5. Acquisition：哪個平台最容易拉新？

## 5.1 Web：★★★★★

典型流程：

```text
Threads / Discord / IG
↓
dorian.game
↓
Play
```

沒有：

```text
Install
Store login
Download flow
Update confirmation
```

這對「迷因角色」非常有利。

Dorian 的角色本身如果能做到：

```text
看到角色
↓
覺得荒謬
↓
想知道它到底怎麼打
```

Web 會最大化這種 impulsive conversion。

---

## 5.2 Steam：★★★～★★★★

Steam 比 Web 多了安裝摩擦，但有平台內 discovery。

兩者形成互補：

```text
外部 Viral
↓
Web
↓
玩過
↓
Wishlist / Install Steam
```

這比單獨依賴 Steam store page 更強。

---

## 5.3 App Store / Google Play：★★★

社群分享後需要：

```text
Link
↓
Store Page
↓
Install
↓
Download
↓
Launch
```

因此第一次體驗 conversion 一般不會比 Web 好。

Mobile Store 的優勢比較偏：

- 搜尋。
- Featured。
- Games categories。
- Recommendations。
- Ranking。

即：

> Store-native discovery，而非 instant virality。

---

# 6. Retention：哪個平台最容易讓人回來？

## 6.1 Web / PWA

弱點：

```text
玩完
↓
關掉 tab
↓
忘記網址
```

改善方式：

- Add to Home Screen。
- PWA install prompt。
- Account。
- Discord / community。
- Email / notification（需要謹慎）。
- Steam CTA。

所以 Web 適合：

> 拉新。

但不應單獨承擔所有 retention。

---

## 6.2 Steam

Steam Library 本身就是 retention engine。

```text
Install once
↓
永久在 Library
↓
看到更新
↓
看到朋友玩
↓
Achievements / Event / New Fighter
↓
回來
```

因此 Steam 很適合 Dorian 未來：

```text
每 1–2 個月
New Fighter
↓
Update Event
↓
玩家回流
↓
Revenue Event
```

---

## 6.3 Native Mobile

Mobile 是最高頻回訪潛力的平台。

Dorian 單場 3 分鐘的 session 形式非常適合：

```text
等車
午休
睡前
通勤
↓
打一到數場
```

但這個優勢只有在：

> Mobile controls + performance + UX 已經夠好

時才成立。

若操作不好，Native App 也救不了 retention。

---

# 7. 商業模式比較

Dorian 建議長期核心商業模式：

```text
Free-to-play base game
+
Premium Fighters
+
Fighter Packs
+
Cosmetics / Supporter content
```

不建議初期：

- Pay-to-win stats。
- 角色升級增加競技數值。
- Energy system。
- 廣告驅動 gameplay。
- 強 Daily login 壓力。

---

# 8. Web 商業模式

## 優點

Web 可以使用自己的支付流程。

例如：

```text
Web Checkout
↓
Payment Provider / MoR
↓
Dorian Backend
↓
Entitlement
```

因此 Web 通常有最好的 revenue control。

也可以自由：

- Bundle。
- Coupon。
- Creator code。
- Pricing experiment。
- A/B test。
- Regional promotion。

## 缺點

玩家對陌生網站直接付款的信任通常低於 Steam / App Store。

因此 Web 可能：

```text
低 platform fee
但
checkout conversion 較低
```

---

# 9. Steam 商業模式

建議：

```text
Dorian = Free to Play
```

原因：

> Fighting game 的核心 asset 是 matchmaking population。

若 base game 收費：

```text
Interested Users
↓
Paywall
↓
Smaller Player Pool
↓
Longer Matchmaking
↓
Worse Experience
```

F2P 更適合：

```text
Free fighters
+
Premium fighters
+
Bundles
+
Cosmetics
```

Steam 提供自己的 commerce / microtransaction capability。

注意：Steam 的實際 revenue share 應以簽署的 Steam Distribution Agreement 為準；不要在正式財務模型中只引用網路傳言或未確認比例。

對內 planning 可以保留一個 conservative platform-fee scenario，但必須標記成「規劃假設」，不是官方公開費率。

---

# 10. Apple App Store 商業模式

Apple Developer Program 官方目前為：

```text
US$99 / year
```

若符合 App Store Small Business Program：

```text
Paid Apps / IAP commission = 15%
```

資格主要包含前一年度 proceeds 不超過 US$1M 等條件。

因此對小型 indie developer，Apple 15% 的 economics 其實相當有競爭力。

但代價是：

- StoreKit integration。
- Receipt / transaction verification。
- Restore purchases。
- App review。
- Privacy declarations。
- Cross-platform entitlement reconciliation。

---

# 11. Google Play 商業模式

Google Play 的費率在 2026 年正處於分區 rollout 過渡期。

截至本文件日期：

- EEA / UK / US 已於 2026-06-30 進入新版 fee framework。
- AU / JP 預計 2026-09-30。
- KR 預計 2026-12-31。
- Rest of World 預計 2027-09-30。

對目前尚未切換新版 framework 的市場，加入既有 15% service fee tier 後，前 US$1M 年收益可適用 15% 費率。

因此：

> Google Play 的跨國 commerce model 在 2026 年比過去複雜，正式 global pricing / P&L 必須依市場分開計算。

Google Android developer full-distribution account官方註冊費目前為：

```text
US$25 one-time
```

---

# 12. Premium Fighter 的跨平台正確架構

不要讓：

```text
Steam owns Doge
Apple owns Doge
Web owns Doge
```

變成三套互不相干的 ownership system。

應該是：

```text
                 Dorian Account
                       │
              Entitlement Service
                       │
        ┌──────────────┼──────────────┐
        │              │              │
       Web           Steam          Mobile
        │              │              │
 Payment Provider   Steam Tx     Apple / Google
        │              │              │
        └──────────────┴──────────────┘
                       │
                 purchase proof
                       │
                       ▼
                    Backend
                       │
                       ▼
                 owns fighter X
```

Canonical truth：

```text
user_id
fighter_id
entitlement_source
transaction_id
status
created_at
revoked_at
```

Store / payment provider 只負責證明 transaction。

Dorian backend 才是 gameplay entitlement authority。

---

# 13. Platform Identity Architecture

建議 canonical Dorian User：

```text
users
└ user_id

identities
├ provider = guest
├ provider = email/google
├ provider = steam
├ provider = apple
└ provider = google_play / google
```

例如：

```text
Dorian user_123
├ anonymous installation A
├ SteamID 7656...
├ Apple account link
└ Web login
```

這樣 Steam / Web / Mobile 才能共用：

- Premium Fighters。
- Match history。
- MMR / Rank（未來）。
- Character mastery。
- Achievements mapping。
- Settings 部分同步。
- Telemetry / retention cohort。

---

# 14. Telemetry 對平台決策的重要性

Dorian 已決定完整紀錄 product / gameplay telemetry。

這件事應該直接用來判斷下一個平台，而不是憑感覺。

至少記：

```text
platform
os
device_class
browser / native
session_duration
match_count
match_minutes
FPS
crash
network quality
input type
character select
match completion
D1 / D7 / D30 retention
purchase conversion
PWA install
Steam CTA click
```

---

# 15. Native Mobile 不應靠直覺決定，要靠 Gate

Web 上線後可以看到：

```text
Desktop      45%
Android Web  35%
iOS Web      20%
```

接著比較：

```text
Desktop D7     18%
Android D7     10%
iOS Web D7      5%
```

若 mobile traffic 很大，但 retention 顯著低於 desktop，並且原因來自：

- Safari crash。
- WebGL issue。
- Loading time。
- Touch latency。
- Browser audio limitation。
- PWA persistence。

那 Native Mobile 有明確 business case。

反之：

```text
Mobile traffic only 8%
```

就不應花 1–2 個月做 App，只因為「App Store 人很多」。

---

# 16. Godot 技術成本比較

## 16.1 Web / PWA

Godot 官方 Web export：

- WebAssembly。
- WebGL 2.0。
- Compatibility renderer。
- PWA export。
- single-thread Web export 為目前偏好的預設路徑。

Web 優勢：

- 無 Store review。
- URL 即 release。
- CI/CD 最直接。
- 更新最快。

Web 技術風險：

- WASM payload。
- WebGL 2.0。
- Safari compatibility。
- mobile Web 效能明顯弱於 native。
- browser audio limitation。
- persistent storage 受 browser policy 影響。
- WebRTC relay-only 需要 browser-specific implementation / bridge。

Dorian 已採 Web-first，因此此成本視為 baseline。

---

# 17. Steam 技術成本

Steam 最簡版本不需要重新做遊戲。

Godot：

```text
Current:
Godot → Web Export

Add:
Godot → Windows Export
```

## Steam Minimum Release

大致工作：

```text
Windows export preset
Steam AppID
SteamPipe
build upload
private branch
controller validation
store page
release QA
```

Dorian-specific estimate：

```text
5–10 engineering days
```

## Steam Production Integration

加入：

```text
Steam Identity
Achievements
Cloud Save
Rich Presence
Steam Input
Overlay awareness
backend account linking
```

估計：

```text
約 14–30 engineering days

實際 calendar planning：
約 2–4 週工程工作
```

## Steam + Cross-platform Commerce

再加入：

```text
Steam transaction
backend verification
premium entitlement
refund / revoke
cross-platform linking
```

整體通常進入：

```text
約 4–8 週 production engineering work
```

注意：這個 4–8 週包含的已經不只是「Steam 上架」，而是跨平台產品能力。

---

# 18. Steam 上架固定成本與時間

Steam Direct 官方要求：

```text
US$100 / product
```

特性：

- non-refundable。
- product 達至少 US$1,000 Adjusted Gross Revenue 後可 recoup。

官方 release timing：

```text
支付 Steam Direct fee
↓
至少等待 30 天

並且：

Coming Soon page
↓
至少公開 2 週
```

Store page / build review 官方通常：

```text
1–5 days
```

因此：

> 工程可以 1–2 週完成，第一次產品正式 release 仍受 30 天 waiting period 限制。

---

# 19. Steam Store 本身也是 marketing asset

不要等遊戲 100% 完成才開 Steam。

建議：

```text
2–3 production-quality fighters
↓
足以做 trailer / screenshots
↓
Steam Direct
↓
Coming Soon
↓
Wishlist accumulation
```

之後一邊：

```text
Web Beta
```

一邊：

```text
Steam Wishlist
```

Steam 官方本身建議「有東西可以展示後盡早上 Coming Soon」。

---

# 20. Steam 對 Dorian 的特殊價值

## 20.1 Controller ecosystem

Dorian 是 fighter。

Steam 玩家可能使用：

- Xbox Controller。
- DualSense。
- DualShock。
- 8BitDo。
- Fight Stick。
- Leverless / Hitbox-style controller。

Steam Input 提供統一 mapping 層。

Dorian 現有 InputSource → InputFrame abstraction 很適合：

```text
Keyboard
Gamepad
Steam Input
Touch
Remote
CPU
Replay
    ↓
InputFrame
```

不需要讓 Steam Input 滲入 BattleSimulation。

---

# 21. Steam Networking：不要綁死 Steam

Dorian 長期目標：

```text
Web ↔ Steam ↔ Mobile
```

因此不建議把核心 online architecture 完全改成 Steam-only matchmaking / networking。

建議：

```text
Own Matchmaking Backend
+
Own Rollback protocol
+
platform transport adapters
```

Steam 主要負責：

```text
distribution
identity
commerce
community
achievements
input
```

而不是成為 gameplay networking 的唯一 authority。

如此 Web ↔ Steam cross-play 比較自然。

---

# 22. Native Android 工程成本

新增能力：

```text
Android export
SDK / JDK toolchain
signing
Play Console
app bundle
Play Billing
purchase verification
safe area
performance tiers
device QA
store metadata
privacy/data safety
```

Dorian-specific initial estimate：

```text
Basic Android native:
7–15 engineering days

Production commerce + QA:
通常 > 2–4 weeks
```

若再考慮長期 device fragmentation，maintenance cost 持續存在。

---

# 23. Native iOS 工程成本

Godot iOS export 需要 macOS / Xcode 環境。

新增：

```text
iOS export
Xcode
certificates
profiles
signing
TestFlight
App Store Connect
StoreKit
purchase verification
safe area
notch / Dynamic Island
iPhone / iPad QA
privacy labels
review
```

Dorian-specific estimate：

```text
Basic iOS native:
10–20 engineering days

Production commerce + QA:
通常 > 2–4 weeks
```

---

# 24. 同時做 iOS + Android 的真實成本

不要直接：

```text
Android 10 天
+
iOS 10 天
=
20 天
```

因為還會多出 shared mobile work：

- Touch UX。
- low-end quality settings。
- entitlement abstraction。
- native analytics。
- app lifecycle。
- suspend / resume。
- connectivity change。
- background / foreground。
- crash reporting。
- release automation。
- privacy compliance。

因此 Dorian 若從已成熟 Web/Steam core 進 Native Mobile：

```text
約 20–40+ engineering days
```

較合理。

若 combat / controls / mobile UX 尚未穩定，可能更高。

---

# 25. QA Matrix 的增長

## Web only

至少：

```text
Chrome desktop
Firefox desktop
Safari desktop
Android Chrome
iPhone Safari
PWA
```

## + Steam

增加：

```text
Windows native
keyboard
Xbox controller
PlayStation controller
fight stick / generic gamepad
Steam Overlay
Steam Input
```

## + Native Mobile

再增加：

```text
multiple Android OS versions
low / mid / high Android
multiple aspect ratios
multiple GPU vendors
iPhone generations
iOS versions
iPad
notch / Dynamic Island
60 / 90 / 120Hz
```

所以平台數增加真正昂貴的地方通常是：

> **Regression QA，而不是 export 按鈕。**

---

# 26. 更新速度比較

## Web

```text
merge main
↓
CI
↓
deploy
↓
所有人下一次開網址就是新版本
```

最快。

---

## Steam

Valve 官方允許 developer 在上線後自行更新，而且 SteamPipe 很適合 automated build。

因此 release friction 其實也低。

Steam 非常適合頻繁 balance patch。

---

## App Stores

Native store 更新仍需要：

- build。
- upload。
- metadata（視更新而定）。
- review / processing。
- staged rollout。

因此 fighting game 的頻繁 balance hotfix 在 Web / Steam 更舒服。

---

# 27. Analytics / User Data 成本

Dorian 希望完整記錄產品與 gameplay data。

平台共用：

```text
installation_id
user_id
session_id
match_id
round_id
move events
network events
performance events
replay reference
purchase events
```

但平台會增加 compliance 差異。

## Web

需要：

- Privacy Policy。
- 必要 consent strategy。
- 自己負責 data rights / deletion。

## Apple

App Store Connect 要揭露 App 收集的 data types、用途，以及是否 linked / tracking。

## Google Play

必須填 Data Safety form，說明 collect / share / security practices。

所以 Native Mobile 的 data / privacy work 明顯比 Web / Steam 更高。

---

# 28. 建議的資料蒐集原則

「記錄所有數據」不應解讀為：

```text
能拿到什麼 PII 就拿什麼
```

應該解讀為：

> 對 gameplay、產品、network、performance、retention、commerce、debug 有價值的事件要完整。

例如：

```text
YES:
move use
hit / block / whiff
match result
rollback frames
RTT
FPS
crash
session length
purchase
retention

NO BY DEFAULT:
contacts
photos
precise location
unnecessary device identifiers
real name
```

這會大幅降低 App Store / privacy compliance 成本。

---

# 29. 商業收益：平台費率不是唯一指標

假設 Premium Fighter 售價相同。

Web 可能：

```text
fee 低
conversion trust 較低
```

Steam / App Store 可能：

```text
platform fee 高
但 payment trust / saved payment method 高
```

因此應該真正比較：

```text
Revenue per Active User
Paid Conversion
Average Revenue per Payer
Refund Rate
Net Revenue after platform
```

不是只比：

```text
平台抽成 %
```

---

# 30. Matchmaking Population 對平台策略的影響

Dorian 是 1v1 Online Fighter。

多人遊戲最危險的問題：

```text
玩家太分散
↓
找不到人
↓
排隊長
↓
玩家離開
↓
更找不到人
```

因此長期應盡量：

```text
Web
Steam
Mobile
        ↓
Shared Matchmaking Pool
```

而不是：

```text
Web Queue
Steam Queue
Android Queue
iOS Queue
```

如果技術與公平性允許，Cross-play 對 Dorian 的價值非常高。

---

# 31. Controls 可能需要分平台 matchmaking 嗎？

未來應紀錄：

```text
input_method
keyboard
controller
touch
```

再看真實數據。

如果發現：

```text
Touch vs Controller
winrate 差異巨大
```

再決定：

- input-based matchmaking。
- control-specific balance。
- aim/command leniency。

不要第一版就把 population 切碎。

---

# 32. 發布策略：Phase 1 — Web Alpha

## 必須具備

- 2–3 production-quality characters。
- CPU。
- Local / Training。
- 基本 online（若 ready）。
- Telemetry。
- Performance tracking。
- Crash/error logging。
- Replay correlation。

## 目的

不是賺錢。

而是回答：

```text
人願不願意點進來？

第一場有沒有打完？

會不會主動打第二場？

會不會連打 3–10 場？

哪個角色最多人玩？

手機 Web 是否真的能用？
```

---

# 33. Phase 2 — Web Public Beta

目標：

```text
social viral
↓
real traffic
↓
real retention
↓
real performance
↓
real matchmaking behavior
```

此階段應開始觀察：

```text
DAU
D1
D7
matches/user/day
human match minutes
queue wait
CPU fallback rate
mobile share
PWA install rate
```

---

# 34. Phase 3 — Steam Coming Soon

不要等 Steam client 做完。

Gate：

```text
至少 2–3 個角色視覺已達公開品質
+
遊戲畫面足以做 trailer
+
核心產品方向不會大改
```

然後：

```text
Pay Steam Direct $100
↓
Create Store Page
↓
Trailer
↓
Screenshots
↓
Coming Soon
↓
Wishlist
```

這時 Web 繼續跑。

---

# 35. Phase 4 — Steam Native Beta

建議先做到：

```text
Windows native
SteamPipe
private beta
controller
backend connection
telemetry
crash reporting
```

不用等：

- Steam achievements。
- Cloud。
- Premium commerce。

才能測試。

---

# 36. Phase 5 — Steam Production Release

正式 release 前建議：

```text
Steam Identity
Dorian account linking
Achievements
Rich Presence
Steam Input
Store events
Cross-play
```

Premium commerce 可以同 release 或後續加入。

---

# 37. Phase 6 — Native Mobile Decision Gate

至少滿足其中數項才投入：

### Product Gate

- Web/Steam 已證明 combat retention。
- 新玩家平均會連打多場。
- D7 retention 有 meaningful signal。

### Market Gate

- Mobile 占 Web traffic 比例高。
- Mobile players 有明確需求。

### Technical Gate

- Mobile Web 成為 performance / UX bottleneck。
- Touch controls 已經驗證。
- Backend / account / entitlement 已 platform-neutral。

### Business Gate

- 現有 revenue 或 traction 足以合理化額外 20–40+ engineering days。

---

# 38. 「什麼情況不要做 App」

不要因為：

```text
App Store 有幾十億使用者
```

就做。

以下情況建議延後：

- DAU 還很低。
- Combat retention 未驗證。
- Web mobile traffic 很少。
- iOS / Android players 沒有明確需求。
- 還在大量改核心 control scheme。
- 每週都在改 gameplay architecture。

此時 App 只會放大 QA 成本。

---

# 39. 「什麼情況應該提早做 Steam」

以下條件出現時，Steam 應提早：

- 2–3 隻角色已經看起來很好。
- Gameplay trailer 有吸引力。
- Web 分享開始有流量。
- 玩家開始問「有 Steam 嗎？」
- 有 PC 玩家用 keyboard / controller 長時間玩。
- 希望累積 Wishlist。

Steam Store presence 可以比 Steam client release 早很多。

---

# 40. 「什麼情況 Web 可以一直存在」

答案：幾乎永遠。

Steam 上線後不建議關 Web。

最好的 funnel：

```text
Social Post
    ↓
Web instant play
    ↓
first 3–10 matches
    ↓
┌────────────────────┐
│                    │
▼                    ▼
PWA               Steam
casual            core
```

Web 是試玩入口。

Steam 是長期 home。

兩者不是競爭關係。

---

# 41. 建議 Platform Positioning

## Web/PWA

定位：

> Play instantly.

產品重點：

- 快。
- 不登入即可玩。
- 分享 URL。
- CPU fallback。
- 社群 viral。

---

## Steam

定位：

> The full PC home of Dorian.

產品重點：

- Controller。
- Achievements。
- Longer-term progression。
- Community。
- Premium content。
- Reliable native performance。

---

## Mobile Native

定位：

> Dorian in your pocket.

產品重點：

- Fast launch。
- 3-minute matches。
- Touch-native UX。
- Notifications（必要時）。
- High-frequency return sessions。

---

# 42. 建議的平台功能矩陣

| Feature | Web/PWA | Steam | Native Mobile |
|---|---:|---:|---:|
| Guest play | 必須 | 可 | 可 |
| Dorian Account | 可選 | 建議 | 建議 |
| CPU | 必須 | 必須 | 必須 |
| Training | 必須 | 必須 | 必須 |
| Online | 必須 | 必須 | 必須 |
| Cross-play | 目標 | 目標 | 目標 |
| Telemetry | 必須 | 必須 | 必須 |
| Replay | 必須 foundation | 必須 | 必須 |
| Premium Fighter | Beta 後 | 建議 | 建議 |
| Achievements | 自有 | Steam | Game Center / Play Games 可選 |
| Controller | Keyboard/Gamepad | 核心 | 次要 |
| Touch | Mobile Web | 非核心 | 核心 |
| PWA | 是 | 否 | 否 |
| Offline CPU | 可 | 是 | 是 |

---

# 43. Repository / Architecture Impact

平台策略不應讓 repo 變成：

```text
web_game/
steam_game/
ios_game/
android_game/
```

應保持 shared Godot client：

```text
meme-fighter-v2/
│
├ core gameplay
├ content
├ presentation
├ frontend
├ platform/
│  ├ web/
│  ├ steam/
│  ├ android/
│  └ ios/
└ services/
   ├ identity
   ├ telemetry
   └ entitlement client
```

平台差異只放 adapter。

---

# 44. Platform Adapter 原則

```text
                Core Game
                   │
             PlatformServices
                   │
     ┌─────────────┼─────────────┐
     │             │             │
 WebPlatform   SteamPlatform  MobilePlatform
```

統一 interface：

```text
get_platform_user()
login()
purchase()
restore_purchase()
show_achievement()
cloud_save()
open_store()
```

BattleSimulation 完全不應知道自己跑在：

```text
Chrome
Steam
iPhone
Android
```

---

# 45. Hosting / Backend 策略

Web：

```text
Cloudflare Pages / R2
+
Backend
+
TURN
```

Steam：

```text
Steam distribution
+
Same Backend
+
Same TURN / cross-platform transport
```

Mobile：

```text
App Store / Google Play distribution
+
Same Backend
+
Same gameplay service
```

因此 Server 應 platform-neutral。

---

# 46. 成本分層

## Web/PWA

### Fixed platform cost

接近 0，視 hosting / domain 而定。

### Variable

- TURN。
- backend compute。
- object storage。
- payment processing。

### Engineering

Baseline。

---

## Steam

### Fixed

```text
US$100 / product Steam Direct
```

### Engineering

```text
Minimum:
5–10 days

Good Steam integration:
2–4 weeks

Cross-platform F2P commerce:
4–8 weeks total platform-product work
```

---

## iOS

### Fixed

```text
US$99 / year Apple Developer Program
```

### Engineering

```text
10–20 days basic
20–40+ days combined native-mobile production effort
```

---

## Android

### Fixed

```text
US$25 one-time developer account fee
```

### Engineering

```text
7–15 days basic
20–40+ days combined native-mobile production effort
```

---

# 47. 平台選擇的 Expected Value

可以用：

```text
Platform EV
=
Reach
× First-play conversion
× Retention
× Monetization
− Engineering Cost
− QA Cost
− Operational Complexity
```

對現在的 Dorian：

```text
Web EV = 高
```

因為 acquisition 與 learning value 極高、成本最低。

```text
Steam EV = 高
```

但應稍晚，等 presentation 足以承受 public store page。

```text
Native Mobile EV = 未知
```

因為現在缺乏 mobile retention 與 traffic data。

---

# 48. 建議的真實 Rollout Timeline（非硬性日期）

## Stage A — Gameplay / Collaboration Foundation

```text
2-character vertical slice
↓
3rd character
↓
Character Package
↓
Telemetry
```

平台：Local / Web dev build。

---

## Stage B — Web Alpha

```text
Web deploy
↓
Friends / community test
↓
Collect telemetry
```

---

## Stage C — Public Web Beta

```text
social launch
↓
real DAU
↓
real D1/D7
```

同時準備 Steam store assets。

---

## Stage D — Steam Presence

```text
Steam Direct
↓
Coming Soon
↓
Wishlists
```

---

## Stage E — Steam Client

```text
Windows Native
↓
Steam Playtest
↓
Cross-play
↓
Release
```

---

## Stage F — Monetization

```text
Premium Fighters
↓
Web + Steam entitlement
```

---

## Stage G — Mobile Decision

```text
Analyze mobile traffic
↓
Analyze retention gap
↓
Native ROI
↓
GO / NO-GO
```

---

# 49. Platform KPI Gates

以下不是業界標準，而是 Dorian 建議的內部決策 Gate。

## Web → Steam Native Gate

至少觀察：

- 有穩定的非內部玩家。
- 平均新玩家不是只打一場就走。
- 有足夠玩家使用 Desktop。
- Controller demand 存在。
- Combat feedback 顯示核心玩法成立。

Steam Coming Soon 不必等這些全滿足。

---

## Steam → Native Mobile Gate

至少回答：

1. Mobile traffic 占多少？
2. Mobile Web retention 是否比 desktop 差很多？
3. 差的原因是否 Native 可以改善？
4. Touch control retention 是否成立？
5. 是否有能力維護兩個額外 store release pipeline？
6. Mobile incremental revenue 是否有機會大於新增工程 / QA 成本？

---

# 50. 建議的商業化順序

不要：

```text
Payment
↓
Store
↓
20 characters
↓
才測 combat
```

建議：

```text
Combat fun
↓
Retention
↓
Population
↓
Premium Fighter
↓
Cosmetics
↓
More content
```

---

# 51. Premium Fighter 建議跨平台定價原則

不要要求各平台 nominal price 完全相同。

原因：

- VAT / tax。
- regional pricing。
- store price tiers。
- platform fee。
- FX。

應定義：

```text
Target Consumer Price Band
```

例如：

```text
Single Premium Fighter
≈ equivalent of NT$119–149 band
```

然後各平台映射最接近 price tier。

---

# 52. 不建議一開始做 Subscription / Battle Pass

Dorian 初期 retention 應來自：

```text
skill improvement
matchup mastery
character mastery
new fighter
social competition
```

不是：

```text
fear of missing daily reward
```

因此第一階段商業化：

```text
Premium Fighter
Cosmetic
Supporter Pack
```

比 Battle Pass 更適合。

---

# 53. Web / Steam / App 的產品角色分工

```text
                  DORIAN
                     │
          ┌──────────┼──────────┐
          │          │          │
        WEB        STEAM      MOBILE
          │          │          │
        Acquire     Retain      Scale
          │          │          │
     Viral Trial   Community   Habit
          │          │          │
     Low friction   Commerce   Frequency
```

這是整份報告最重要的模型。

---

# 54. 主要風險比較

## Web 最大風險

1. Safari / Mobile Web stability。
2. Startup payload。
3. Browser persistence。
4. 沒有平台 discovery。
5. 回訪入口弱。

## Steam 最大風險

1. Store page 沒有吸引力。
2. Wishlist 太少。
3. PC players 對 controller / quality expectations 更高。
4. Steam user reviews 會快速暴露品質問題。
5. 若 population 太小，online fighter 體驗差。

## Mobile 最大風險

1. Touch control 不好玩。
2. Device fragmentation。
3. Store / billing / privacy complexity。
4. Native release 維護成本高。
5. F2P mobile 市場競爭極高。

---

# 55. 最終建議

## 現階段

**Web/PWA first。**

原因：

- 最符合迷因社群分享。
- 最低第一次遊玩 friction。
- 最快取得 gameplay telemetry。
- 最低 platform commitment。
- 最適合現在快速修改 combat / characters。

---

## 同時開始準備

**Steam presence early。**

但不是現在就投入完整 Steamworks。

一旦：

```text
2–3 個角色有 production-quality presentation
```

就可以：

```text
Steam Direct
Coming Soon
Wishlist
```

---

## 第二個真正 production client

**Steam Windows Native。**

理由：

- 使用者是真正 gamer。
- Steam 是成熟 indie discovery platform。
- Library retention 強。
- Controller ecosystem 適合 fighter。
- Godot Windows export 比 Web 相容性更自然。
- 適合 F2P + Premium Fighter。

---

## Native Mobile

**不要現在承諾。**

等 Web telemetry 回答：

```text
Mobile demand?
Mobile Web bottleneck?
Mobile retention potential?
```

再投入。

---

# 56. 最終 Roadmap 建議

```text
NOW
│
├─ Golden Pair / 3rd Fighter
├─ Modular Monorepo
├─ Character Packages
├─ Telemetry
└─ Replay / Debug
        ↓
WEB ALPHA
        ↓
WEB PUBLIC BETA
        │
        ├── Steam Direct
        └── Steam Coming Soon
        ↓
REAL USER DATA
        │
        ├── Combat retention
        ├── Device distribution
        ├── Mobile retention
        ├── Match frequency
        └── Monetization intent
        ↓
STEAM NATIVE
        │
        ├── Windows
        ├── Steam Identity
        ├── Steam Input
        ├── Achievements
        ├── Cross-play
        └── Premium Entitlement
        ↓
PRODUCT-MARKET SIGNAL
        ↓
NATIVE MOBILE GO/NO-GO
        │
        ├── Android
        └── iOS
```

---

# 57. 一句話決策

> **Web 讓人第一次玩 Dorian；Steam 讓玩家把 Dorian 當成一款真正長期玩的遊戲；Native Mobile 則在產品已證明值得擴張後，把 Dorian 變成高頻隨身遊戲。**

因此目前最佳順序：

```text
Web/PWA
→ Steam
→ Native Mobile
```

不是因為 Steam 或 App Store 不重要，而是這個順序能以最低成本逐步降低最大的不確定性。

---

# 58. 官方資料與參考來源

## Steam

- Steamworks / audience / feature overview  
  https://partner.steamgames.com/

- Steam Direct — $100 fee、30-day waiting period、Coming Soon 2 weeks、review 1–5 days  
  https://partner.steamgames.com/steamdirect

- Steamworks SDK  
  https://partner.steamgames.com/doc/sdk

- Coming Soon  
  https://partner.steamgames.com/doc/store/coming_soon

## Godot

- Web export / PWA / WebAssembly / WebGL2 / mobile Web limitations  
  https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html

- Windows export  
  https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html

- Android export  
  https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

- iOS export  
  https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html

## Apple

- Apple Developer Program — US$99/year  
  https://developer.apple.com/programs/whats-included/

- App Store Small Business Program — eligible commission 15%  
  https://developer.apple.com/app-store/small-business-program/

- App privacy  
  https://developer.apple.com/app-store/user-privacy-and-data-use/

- Apple 2026 Q1 — installed base >2.5B active devices  
  https://www.apple.com/newsroom/2026/01/apple-reports-first-quarter-results/

## Google

- Google Play service fees  
  https://support.google.com/googleplay/android-developer/answer/112622

- 2026 fee rollout details  
  https://support.google.com/googleplay/android-developer/answer/16954621

- Developer account registration  
  https://support.google.com/android-developer-console/answer/16604405

- Google Play Data Safety  
  https://support.google.com/googleplay/android-developer/answer/10787469

---

# 59. 數字使用注意事項

本文件中的數字分成兩種：

## 官方資料

例如：

- Steam Direct US$100。
- Steam 30-day waiting period。
- Steam Coming Soon 至少 2 weeks。
- Apple Developer Program US$99/year。
- Apple Small Business 15%。
- Google developer registration US$25 one-time。

這些以 2026-08-22 官方公開文件為基準。

## Dorian Planning Estimate

例如：

- Steam minimum integration 5–10 engineering days。
- 完整 Steam integration 約 2–4 weeks。
- Native mobile combined 20–40+ engineering days。

這些是依目前 Dorian Godot architecture、現有 abstraction 與預計功能範圍做的工程估算，**不是平台官方承諾，也不是外包報價**。

正式開工前應再依當時 repo baseline、角色數量、online readiness 與 commerce scope 重新估時。
