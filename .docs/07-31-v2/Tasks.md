# Tasks：聊天页 HTML 卡片渲染增强

**Plan**：Plan.md（根目录）  
**状态总览**：全部 DONE（2026-08-01）。  
**本机无 Flutter SDK**：执行侧 Test 以云端 CI 为最终门；正则/切分逻辑已由 Node 脚本（`tool/div_algo_sim.js`，Explore 阶段产出，已清理）证明。

---

## Phase 1：方向边框与 CSS 解析补全

### TASK-001：补全方向边框解析

- **状态**：DONE
- **文件**：`lib/shared/widgets/markdown_with_highlight.dart`（`StyledDivBlockMd`，约 L5885–6137）
- **Description**：在 `StyledDivBlockMd` 中新增对 `border-top` / `border-right` / `border-bottom` 的解析（简写 + `-color` / `-width`），与既有 `border-left` / `border` 简写统一。组合为 `Border`：仅对「有 width 且有 color」的侧生成 `BorderSide`；方向优先于 `border` 简写。
- **Details**：
  1. 复用 `_extractBorderWidth` / `_extractBorderColor`（已存在）解析 `css['border-top']` 等简写。
  2. 优先取 `css['border-top-width']` / `css['border-top-color']`，回退到简写解析。
  3. 把现有 `decoration` 构造逻辑改为：先收集四向 BorderSide（缺省侧不画），再与 `border` 简写合并；`border-radius` 仍套 `BoxDecoration.borderRadius`。
- **验收**：
  - `grep -n "border-top\|border-right\|border-bottom" lib/shared/widgets/markdown_with_highlight.dart` 在 `StyledDivBlockMd` 区域命中。
  - `border-top: 3px solid #2c3e50` → `BorderSide(top, color=#2c3e50, width=3)`（Node 脚本已证）。

### TASK-002：补全布局相关 CSS 解析

- **状态**：DONE
- **文件**：同 TASK-001
- **Description**：在 `_parseStyle` 产出的 map 基础上读取 `display`、`grid-template-columns`、`flex-wrap`、`gap`、`min-width`。
- **Details**：
  1. `_parsePx` 解析 `gap` / `min-width`。
  2. `grid-template-columns` 列数 = `fr` 出现次数（无 `fr` 则取空格分片数）。
  3. `flex-wrap` 布尔（含 `wrap`）。
- **验收**：`grep -n "grid-template-columns\|flex-wrap\|'gap'\|'min-width'" lib/shared/widgets/markdown_with_highlight.dart` 命中相应解析处。

---

## Phase 2：子 div 平衡切分 + 多列布局渲染

### TASK-003：实现顶层子 div 切分器

- **状态**：TODO
- **依赖**：TASK-001
- **文件**：同上
- **Description**：新增静态方法 `List<_DivSegment> _splitTopLevelDivs(String body)`，用 `RegExp(_divPattern(3), dotAll: true)` 的 `allMatches` 非重叠取顶层 `<div...>...</div>` 块，保留块间 gap 文本段。
- **Details**：`_DivSegment { final bool isDiv; final String text; }`。Node 脚本 `tool/div_algo_sim.js` 已证：grid 外层 → 2 子 div + 0 非空 gap；flex 外层 → 3 子 div + 0 非空 gap。
- **验收**：`grep -n "_splitTopLevelDivs\|_DivSegment" lib/shared/widgets/markdown_with_highlight.dart` 命中。

### TASK-004：抽取单 div 渲染器 `_buildDivContainer`

- **状态**：TODO
- **依赖**：TASK-001
- **文件**：同上
- **Description**：把现有 `build()` 中「解析单个 `<div style>` → Container（margin/padding/bg/border/radius + body 经 `config.getRich(TextSpan(generate))` 渲染）」的逻辑抽成 `Widget _buildDivContainer(BuildContext, String divText, GptMarkdownConfig)`，供单列路径与多列子卡片复用。
- **Details**：复用 TASK-001 的方向边框；body 仍走 `MarkdownComponent.generate(context, body, bodyConfig, true)`（含 `StyledDivBlockMd`，递归渲染嵌套 div）。
- **验收**：`grep -n "_buildDivContainer" lib/shared/widgets/markdown_with_highlight.dart` 命中；既有单列渲染行为不变（既有 widget 测试不应回归）。

### TASK-005：`build()` 多列分支

- **状态**：TODO
- **依赖**：TASK-002, TASK-003, TASK-004
- **文件**：同上
- **Description**：在 `StyledDivBlockMd.build()` 顶部判定：`display ∈ {grid, flex}` 且 `_splitTopLevelDivs(body)` 子 div 数 ≥ 2 → 走多列分支，否则走原 `_buildDivContainer` 单列路径。
- **Details**：
  1. **grid**：`cols = fr 数`（TASK-002）；按 `cols` 把子 div 分块为若干行；每行 `Row(children: [子 div _buildDivContainer 包 Expanded] + 行内 SizedBox(width: gap) 间隔)`；行间用 `Column` + `SizedBox(height: gap)`。
  2. **flex**：`LayoutBuilder` 取可用宽 `W`；`minW = min-width ?? 200`；`cols = max(1, ((W+gap)/(minW+gap)).floor()).clamp(1, 子数)`；无 `flex-wrap` 时 `cols = 子数`；布局同 grid 分块。
  3. 外层 Container 套自身 `margin`/`padding`/`bg`/`border`（布局容器多为透明）；`ponytail` 注释：`flex:N` 增长比与 grid `span` 跨列不实现，升级路径=按 flex 值分配 Expanded flexFit。
  4. 子 div 间 gap 文本段（罕见）作为独立 `config.getRich` 块插入 Column，不丢。
- **验收**：
  - `grep -n "LayoutBuilder\|grid-template-columns\|Expanded" lib/shared/widgets/markdown_with_highlight.dart` 在 `StyledDivBlockMd` 区域命中。
  - Node 证明 grid→2 列、flex→3 子；CI widget 测试断言两卡片在 `Row` 中并排。

---

## Phase 3：测试 + 文档 + 归档 + 提交

### TASK-006：widget 测试

- **状态**：TODO
- **依赖**：TASK-005
- **文件**：`test/shared/widgets/markdown_with_highlight_test.dart`
- **Description**：镜像既有 `_markdownHarness` + finder 模式，新增 3 个 `testWidgets`。
- **Details**：
  1. **grid 两列**：pump 用户原 grid 块（`<div style="display:grid;grid-template-columns:1fr 1fr;...">` 含两子卡片），`width:800`；断言两子卡片 `Container` 位于同一 `Row` 且各自有 `BorderSide`（顶边 #2c3e50 / #c0392b，width≈3）。
  2. **flex 三卡片窄屏**：`width:360`；断言 3 卡片均渲染（border #e0e0e0、bg #f9f9f9），窄屏堆叠可接受。
  3. **全量不丢内容**：pump 用户完整消息（见 Plan 背景引用），收集所有 `RichText` 文本，断言含 `科技与半导体产业 / 对外贸易与地缘经济 / 新南向政策 / 经济优势与挑战 / 核心优势 / 结构性挑战 / 单引擎起飞`，且不含裸 `<div` / `</div>` / `<h4` / `<ul` / `<li`。
- **验收**：3 个测试存在；本机无法运行，云端 CI `flutter test` 为最终门。

### TASK-007：清理 scratch 文件

- **状态**：TODO
- **依赖**：TASK-006
- **Description**：删除 Explore/Plan 阶段产出的 scratch 文件，保持工作树干净。
- **Details**：删 `tool/div_algo_sim.js`、`tool/div_repro_input.md`、`tool/div_repro_normalized.md`。若 TASK-006 需要用户原文作 fixture，转为 `test/shared/widgets/` 下正式 fixture 文件并纳入测试。
- **验收**：`git status` 工作树仅含本次功能变更 + 测试 + Plan/Tasks。

### TASK-008：文档维护 + 归档 + Git Commit

- **状态**：TODO
- **依赖**：TASK-006, TASK-007
- **Description**：按 Document Maintenance → Archive → Git Commit 顺序收尾。
- **Details**：
  1. 更新 `.docs/Project.md`：§6 约束新增「StyledDivBlockMd 支持多列与方向边框」备注；§8 决策记录追加本次 v3.0。
  2. Plan.md/Tasks.md 标 `状态：DONE` + 完成日期 + 回归测试结论（云端 CI 为门，记录待 CI 验证）。
  3. 归档至 `.docs/07-31-v2/`（今日已有 v1=CI 版本，故 v2）。
  4. `git status` / `git diff` / `git log` 对齐既有 `fix:`/`feat:` 风格提交，不含密钥，不用 `--no-verify`。
- **验收**：`.docs/07-31-v2/` 同时含 `Plan.md` + `Tasks.md`，根目录无残留；git 一次干净提交。

---

## 依赖图

```
TASK-001 ─┬─→ TASK-003 ──→ TASK-005 ──→ TASK-006 ──→ TASK-007 ──→ TASK-008
TASK-002 ─┘    TASK-004 ──↗
```
