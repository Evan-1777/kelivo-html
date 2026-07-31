# Plan：聊天页 HTML 卡片渲染增强（多列布局 + 方向边框）

**状态**：DONE  
**日期**：2026-07-31  
**版本**：v3.0  
**完成日期**：2026-08-01  
**回归测试结论**：待云端 CI 验证（本机无 Flutter SDK）  

---

## 1. 背景与目标

聊天页默认用 `gpt_markdown`（本地 fork）渲染助手消息，其中 HTML 内联块由自研 `StyledDivBlockMd` 组件处理（07-10-v1 引入，07-30-v2 修过嵌套 div + 属性标签 + 标题/列表转换）。但用户实测对照 Markdown 预览页（WebView + markdown-it，`html:true`，完整 CSS）仍有差距：

- **网格两列布局丢失**：`<div style="display:grid; grid-template-columns:1fr 1fr">` 的两个子卡片，预览并排两列，聊天仅单列全宽堆叠。
- **`border-top` 彩色顶边未解析**：`StyledDivBlockMd` 只解析 `border-left` 与 `border` 简写，不解析 `border-top/right/bottom`，导致卡片顶边强调色丢失。
- flex 容器多卡片（`flex-wrap` + `min-width`）：窄屏下预览与聊天均堆叠（一致），但宽屏下预览并排、聊天仍堆叠。

> 注：截图里两个 div 块之间"消失"的标题/段落经 Node 模拟块级分割验证，属「交错思考块（深度思考折叠块）」分隔所致，非渲染丢内容——本次不处理。

**目标**：在不引入 WebView 的前提下，让 `StyledDivBlockMd` 支持多列布局与方向边框，使 grid/flex 容器在宽屏并排、窄屏自适应堆叠，卡片顶边彩色正确呈现，逼近预览水平。

## 2. 阶段划分

### Phase 1：方向边框与 CSS 解析补全

| 项目 | 内容 |
|------|------|
| **输入** | 现有 `StyledDivBlockMd._parseStyle` + `_extractBorderColor/_extractBorderWidth` |
| **输出** | 解析 `border-top/right/bottom/left` 及其 `-color/-width`、`display`、`grid-template-columns`、`flex-wrap`、`gap`、`min-width` |
| **验收** | grep 命中新解析键；方向边框组合为 `Border`（仅指定侧出现 BorderSide） |

### Phase 2：子 div 平衡切分 + 多列布局渲染

| 项目 | 内容 |
|------|------|
| **输入** | Phase 1 的 CSS 解析 + 既有 `_divPattern(3)` 平衡模式 |
| **输出** | `_splitTopLevelDivs(body)` 切分器；`build()` 多列分支：grid→`Row<Expanded>` 分行，flex→`LayoutBuilder` 按 min-width 算列数；子 div 由抽取出的 `_buildDivContainer` 递归渲染 |
| **验收** | Node 模拟已证：grid→2列、flex→3子div；CI widget 测试断言两列并排、顶边 BorderSide 存在 |

### Phase 3：测试 + 文档 + 归档 + 提交

| 项目 | 内容 |
|------|------|
| **输入** | Phase 1/2 代码 |
| **输出** | widget 测试（镜像既有 `_markdownHarness` 模式）覆盖 grid 两列、flex 卡片、全量内容不丢；Project.md 同步；归档；git commit |
| **验收** | 测试用例存在且镜像既有模式；本机无 Flutter SDK，验证以云端 CI（build-stable 等）编译/测试为最终门 |

## 3. 架构决策

| 决策项 | 选择 | 理由 | 替代方案（为何不选） |
|--------|------|------|----------------------|
| 渲染路径 | 增强原生 `StyledDivBlockMd` | 用户选定；纯 Flutter，流式可用，选择/引用全保留，风险低 | HTML 消息内嵌 WebView（像素级一致但流式/高度/手势/性能开销大，过度工程） |
| 多列实现 | `LayoutBuilder` + `Row<Expanded>` 分行 / `Wrap` | 纯 Flutter 布局原语，无新依赖 | 自研 CSS Grid 引擎（YAGNI） |
| flex 列数 | `max(1, floor((W+gap)/(minW+gap)))` 钳到子数 | 逼近 flex-wrap + min-width 行为 | 固定列数（无法响应宽度） |
| 子 div 递归 | 复用 `_divPattern(3)` 全局匹配切顶层 div | 已存在且 Node 证明正确；天然非重叠取最外层 | 手写栈式解析（重复造轮） |
| 验证门 | 云端 CI | 本机无 Flutter SDK，用户指定云端构建 | 本机 `flutter test`（不可用） |

## 4. 风险清单

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| `LayoutBuilder` 在无界宽度上下文失效 | 🟡 中 | 多列分支仅在 `display=grid/flex && 子div≥2` 触发；外层 Container 仍 `width:double.infinity`，父级聊天气泡提供有界宽度；无界时回退单列 |
| 子 div 间夹非 div 文本（罕见） | 🟢 低 | `_splitTopLevelDivs` 保留 gap 段，多列分支把 gap 文本作为独立块插入 Column，不丢 |
| widget 测试本机无法运行 | 🟡 中 | 镜像 `markdown_with_highlight_test.dart` 既有 `_markdownHarness` + finder 模式降 CI 失败风险；正则逻辑已 Node 证明 |
| 既有单列路径回归 | 🟢 低 | 多列为新增分支，单 div / 非布局 div 走原路径；既有用例应不变 |
| 流式中（≥4096 增量切块）跨块 div | 🟢 低 | 不动增量切块器；流式中暂不匹配跨块 div，结束后正常（既有已知限制） |

## 5. Phase 依赖关系

```
Phase 1 ──→ Phase 2 ──→ Phase 3
```

严格串行。

## 6. 关键决策

- 不引入 WebView、不动 gpt_markdown 包、不动增量切块器、不动 `_preprocessFences` 转换链。
- 仅改 `StyledDivBlockMd`（build + 新增静态 helpers）与测试文件。
- `ponytail` 标注上限：flex `flex:N` 增长比与 grid `span` 跨列不实现（注释注明升级路径）。
