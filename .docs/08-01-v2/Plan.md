# Plan：为 WebView 装入离线 Markdown 解析器（方案 B）

**状态**：DONE（2026-08-01 执行完成，已归档至 .docs/08-01-v2/）  
**日期**：2026-08-01  
**版本**：v2.0（方案 B）  
**回归测试结论**：2026-08-01 完成。按 SCOPE.md 不在本机跑 Flutter/Gradle 构建；本机执行静态检查（Tasks 各验收点的 rg 命中全部通过）+ Node 实跑 markdown-it 管线（剥离外层 div → md.render → 回包：`####`/`**`/`-` 渲染为 HTML、内联样式与中文保留、`html_block` 限制行为符合预期）；云端 GitHub Actions（flutter analyze / flutter test）为最终门禁；Android 真机复测见 TASK-008（未执行，列为后续跟进）。

---

## 1. 背景与目标

用户在方案 A（仅隔离 Dart 预处理，保留原始 HTML 让浏览器渲染）与方案 B（给 WebView 装 Markdown 解析器）之间选定 **方案 B**。

目标：让 fragment WebView 不仅能渲染 HTML/CSS，还能用 markdown-it 解析片段内可能出现的 Markdown 语法，统一「HTML + Markdown 混排」渲染，并修复截图中 `####`、`**`、`-` 裸露的问题。

## 2. 关键技术约束（执行前必须知晓）

1. **方案 B 仍需先隔离 Dart 预处理（Phase 1，与方案 A 共用核心）**  
   当前 `_convertInlineHtmlFormatting` 在 WebView 之前把 `<h4>→####`、`<strong>→**`、`<ul>/<li>→-`，并丢失 `<h4 style="color:#2c3e50">` 等内联样式。若不隔离，WebView 收到「div 包裹的 Markdown 文本」。markdown-it 对以 `<div` 开头的块按 html_block 规则整块透传，**不会**解析其内部 Markdown，导致 `####/**` 仍裸露且彩色标题丢失。因此必须先让 WebView 路径保留原始 HTML 片段。

2. **markdown-it html_block 限制（接受边界）**  
   markdown-it（`html:true`）对块级 HTML 标签整块透传，不解析标签内的 Markdown。本方案通过「剥离外层 div → `md.render(inner)` → 用外层 style 回包」处理「div 内纯 Markdown」场景；但「Markdown 嵌套在内部 HTML 标签里」（如 `<p>**bold**</p>`）仍不会被解析——markdown-it 已知限制。当前观测内容为纯 HTML 卡片，不受影响。

3. **离线优先**  
   不引入 CDN/网络运行时；`markdown-it.min.js` 作为 Flutter asset 打包，通过模板占位符注入，兼容现有 `loadHtmlString`（不依赖相对 asset URL 解析）。

4. **Windows 平台既有缺口（非本次引入）**  
   `HtmlFragmentView` 使用 `webview_flutter` 的 `WebViewWidget`，而项目在 Windows 上使用独立的 `webview_windows`（见 mermaid / html_preview_dialog）。`shouldUseWebViewForHtml` 对 Windows 返回 true，但 `WebViewWidget` 在 Windows 无平台实现——这是 v4 引入时的既有缺口。本次 B 不扩张到修复 Windows（单独议题），范围聚焦 Android/iOS/macOS（截图为 Android）。

## 3. 方案 A / B 对比

| 维度 | 方案 A | 方案 B（本次） |
|------|--------|----------------|
| Phase 1 Dart 预处理隔离 | 必须 | 必须（同） |
| WebView 解析能力 | 仅浏览器解析 HTML | 浏览器 + markdown-it 解析 Markdown |
| 离线 JS parser | 无 | 打包 markdown-it.min.js |
| 内联样式（彩色标题） | 保留 | 保留 |
| div 内纯 Markdown | 不解析（显示为文本） | 解析 ✓ |
| Markdown 嵌套在 HTML 标签内 | 不解析 | 不解析（已知限制） |
| 包体/性能 | 无开销 | 每卡片 WebView 多解析 ~100KB JS |

## 4. 阶段划分

### Phase 1：Dart 预处理隔离（WebView 路径保留原始 styled div）

| 项目 | 内容 |
|------|------|
| **输入** | 统一 Markdown 预处理、平台分流、完整 styled div 匹配 |
| **输出** | WebView 平台临时保护完整 `<div style>...</div>` 片段，不参与 HTML→Markdown 转换；原生 fallback 保持现有预处理 |
| **验收标准** | 纯函数/单测可证明：WebView 模式输出保留 `<h4 style>`、`<strong>/<b`、`<ul>/<li>`；原生模式保留既有 `####`/`**`/`-` 转换 |

### Phase 2：打包离线 markdown-it

| 项目 | 内容 |
|------|------|
| **输入** | 无（新 asset） |
| **输出** | `assets/js/markdown-it.min.js`（minified，MIT）+ `pubspec.yaml` 声明 |
| **验收标准** | 文件存在；pubspec assets 命中；离线（无外链） |

### Phase 3：fragment 模板用 markdown-it 渲染

| 项目 | 内容 |
|------|------|
| **输入** | Phase 1 的原始 HTML 片段 + Phase 2 的 markdown-it |
| **输出** | `fragment.html` 通过 `{{MARKDOWN_IT_JS}}` 占位符注入 markdown-it；JS 剥离外层 div style → `md.render(inner, {html:true})` → 用外层 style 回包 → `innerHTML`；保留高度/链接桥 |
| **验收标准** | 模板含占位符且无外链；JS 命中 `md.render`；既有桥接（ResizeObserver / FragmentBridge / chrome.webview）保留 |

### Phase 4：测试、文档、归档、提交

| 项目 | 内容 |
|------|------|
| **输入** | 前三阶段代码 |
| **输出** | 预处理保留原始 HTML 的回归测试；fragment 渲染 `####→<h4>` 的回归测试；Project.md 同步；云端构建；Android 真机复测；归档；commit |
| **验收标准** | `flutter analyze` / 相关 `flutter test` 通过；Android 真机卡片标题/粗体/列表不再裸露 Markdown 标记，且彩色标题、grid/flex、高度桥保留；Linux fallback 既有测试通过 |

## 5. 架构决策

| 决策项 | 选择 | 理由 |
|--------|------|------|
| WebView 片段输入 | 原始 HTML（Phase 1 隔离后） | 保留内联样式；给 markdown-it 真实 HTML+Markdown 混排 |
| Markdown parser | markdown-it（离线打包） | 成熟、支持 `html:true` 透传 HTML；MIT；与 mark.html 同源思路 |
| parser 装入方式 | 占位符 `{{MARKDOWN_IT_JS}}` 注入 | 兼容 `loadHtmlString`；不依赖相对 asset URL；保持模板可读 |
| 外层 div 处理 | 剥 style → md.render(inner) → 回包 | 保留卡片 CSS；让 div 内纯 Markdown 可被解析 |
| 原生 fallback | 保留现有路径 | Linux/Web 无 webview_flutter 实现 |
| Windows | 不在本次范围 | WebViewWidget 在 Windows 无平台实现（既有缺口） |

## 6. 风险与边界

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| markdown-it 不解析嵌套在 HTML 标签内的 Markdown | 🟡 中 | 接受为已知限制；当前内容不受影响；Project.md 记录 |
| 离线 markdown-it 资产无法获取（无网络） | 🟡 中 | 执行侧优先尝试拉取 minified 文件；失败走 advisor |
| 每卡片 WebView 重复解析 ~100KB JS | 🟡 中 | 接受为已知性能边界；后续可考虑共享/缓存 |
| 内联样式丢失 | 🔴 高 | Phase 1 保留原始 HTML 片段规避 |
| 规范化缓存复用 WebView/原生两套结果 | 🟡 中 | 缓存键纳入 WebView 策略；增加平台 override 回归 |
| Windows WebView 既有缺口 | 🟡 中 | 本次不修；记录为单独议题 |

## 7. 依赖关系

```text
Phase 1 ──→ Phase 2 ──→ Phase 3 ──→ Phase 4
```

严格串行。当前在用户确认节点，未进入 Execute。
