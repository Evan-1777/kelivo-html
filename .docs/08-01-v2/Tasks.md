# Tasks：为 WebView 装入离线 Markdown 解析器（方案 B）

**关联 Plan**：`Plan.md` —— 方案 B v2.0  
**状态总览**：全部完成（2026-08-01）。
**验证约束**：按 `.docs/SCOPE.md` 不在本机运行 Flutter/Gradle 构建；云端 GitHub Actions 负责 `flutter analyze` / `flutter test` / 构建门禁。纯函数、静态检查已在本机执行，结论见各 Task。

---

## Phase 1：Dart 预处理隔离（WebView 路径保留原始 styled div）

### TASK-001：提取可测试的 styled div 保护策略

- **状态**：DONE（2026-08-01）
- **优先级**：P0 / **依赖**：无 / **文件**：`lib/shared/widgets/markdown_with_highlight.dart`
- **Description**：在统一 Markdown 预处理中增加可测试的保护逻辑，对 WebView 平台临时掩码完整 `<div style="...">...</div>` 片段，使其不参与 `_convertInlineHtmlFormatting` 的 HTML→Markdown 转换，转换完成后还原。
- **完成注记**：
- **Details**：
  - 复用 `StyledDivBlockMd` 既有平衡匹配（深度 3），不新增第二套 HTML 解析器。
  - 仅在 `shouldUseWebViewForHtml(defaultTargetPlatform)` 为真时启用保护。
  - 掩码必须在 `_convertInlineHtmlFormatting`、`_convertHtmlTablesToMarkdown`、数学/链接规范化之前生效，在它们之后、代码块解掩码之前还原。
  - 原生 Linux/Web 路径不启用保护，保持现有转换结果。
- **Acceptance Criteria**：
  - 执行 `rg -n "shouldUseWebViewForHtml|_convertInlineHtmlFormatting|StyledDivBlockMd" lib/shared/widgets/markdown_with_highlight.dart` 能定位保护逻辑与调用点。
  - 纯函数测试（若抽取为顶层/静态可测函数）或最小入口测试：WebView 模式输出包含 `<h4 style`、`<strong` 或 `<b`、`<ul`、`<li`；同一输入在 Linux override 下输出包含 `####`、`**`、`-`（既有行为）。

### TASK-002：将 WebView 策略纳入规范化缓存与流式路径

- **状态**：DONE（2026-08-01）
- **优先级**：P0 / **依赖**：TASK-001 / **文件**：`lib/shared/widgets/markdown_with_highlight.dart`
- **Description**：把 WebView 片段策略纳入 `_normalizedBlockCache` 缓存键，并在增量块路径与完整消息路径使用同一策略参数，防止 WebView 原始 HTML 与原生 Markdown 版本互相复用。
- **完成注记**：缓存键含 `shouldUseWebViewForHtml(defaultTargetPlatform)` 策略标志；流式增量路径共用 `normalize`；rg 验收点命中。
- **Details**：
  - 缓存键追加 WebView 策略标志（如 `shouldUseWebViewForHtml(defaultTargetPlatform).toString()`）。
  - 流式增量切块路径（`useIncrementalBlocks`）同样适用保护策略。
  - 不改变代码围栏、LaTeX、表格、普通 Markdown 的处理顺序。
- **Acceptance Criteria**：
  - 执行 `rg -n "cacheKey|_normalizedBlockCache|shouldUseWebViewForHtml|streaming|useIncrementalBlocks" lib/shared/widgets/markdown_with_highlight.dart`，两条路径均使用含策略的键。
  - 现有 `markdown_with_highlight` 相关测试通过（普通 Markdown、代码围栏、Linux fallback 不回归）。

## Phase 2：打包离线 markdown-it

### TASK-003：新增 `assets/js/markdown-it.min.js` 并声明资源

- **状态**：DONE（2026-08-01）
- **优先级**：P0 / **依赖**：无（可与 Phase 1 并行） / **文件**：`assets/js/markdown-it.min.js`（新）、`pubspec.yaml`
- **Description**：获取 markdown-it v14.x minified 单文件，作为离线 Flutter asset 打包。
- **完成注记**：`assets/js/markdown-it.min.js` 120,797 字节（markdown-it 14.0.0）；pubspec assets 命中；包内唯一 URL 为源码注释（github.com 署名），模板层无外链。
- **Details**：
  - 来源：`https://cdn.jsdelivr.net/npm/markdown-it@14.0.0/dist/markdown-it.min.js`（MIT）。
  - 执行侧无网络时调用 `advisor` 并记录，不得伪造空文件。
  - 在 `pubspec.yaml` 的 `flutter.assets` 增加 `- assets/js/markdown-it.min.js`。
- **Acceptance Criteria**：
  - 执行 `test -f assets/js/markdown-it.min.js` 退出码 0，且文件非空（`wc -c` > 10000）。
  - 执行 `rg -n "markdown-it.min.js" pubspec.yaml` 命中。
  - 执行 `rg -n "http://|https://" assets/js/markdown-it.min.js` 仅命中源码内字符串/注释，不影响运行时离线（模板层面无外链）。

## Phase 3：fragment 模板用 markdown-it 渲染

### TASK-004：模板增加 `{{MARKDOWN_IT_JS}}` 占位符并由 Dart 注入

- **状态**：DONE（2026-08-01）
- **优先级**：P0 / **依赖**：TASK-003 / **文件**：`assets/html/fragment.html`、`lib/shared/widgets/html_fragment_view.dart`
- **Description**：fragment 模板新增 `{{MARKDOWN_IT_JS}}` 占位符；`composeFragmentDocument`/`buildFragmentDocument` 读取 `assets/js/markdown-it.min.js` 并替换占位符。
- **完成注记**：`{{MARKDOWN_IT_JS}}` 占位符 + `composeFragmentDocument(markdownItJs:)` 注入 + `_markdownItJsAsset`（rootBundle.loadString + static late 缓存）；rg 验收点命中；新增单测覆盖占位符无残留。
- **Details**：
  - `buildFragmentDocument` 通过 `rootBundle.loadString('assets/js/markdown-it.min.js')` 读取 JS，传入 `composeFragmentDocument`。
  - `composeFragmentDocument` 增加 `required String markdownItJs` 参数，执行 `.replaceAll('{{MARKDOWN_IT_JS}}', markdownItJs)`。
  - 读取的 JS 字符串建议用 `static late String` 缓存，避免每卡片重复读 asset。
  - 占位符不得与其他 `{{...}}` 冲突；替换后无残留 `{{MARKDOWN_IT_JS}}`。
- **Acceptance Criteria**：
  - 执行 `rg -n "{{MARKDOWN_IT_JS}}" assets/html/fragment.html lib/shared/widgets/html_fragment_view.dart` 命中占位符与注入点。
  - 纯函数测试：`composeFragmentDocument` 输出不含 `{{MARKDOWN_IT_JS}}` 残留，且包含传入的 JS 片段标识。
  - 执行 `rg -n "rootBundle.loadString.*markdown-it" lib/shared/widgets/html_fragment_view.dart` 命中 asset 读取。

### TASK-005：fragment.html 用 markdown-it 渲染并保留桥接

- **状态**：DONE（2026-08-01）
- **优先级**：P0 / **依赖**：TASK-004 / **文件**：`assets/html/fragment.html`
- **Description**：将 `innerHTML = html` 改为：用 markdown-it 解码后的片段，剥离外层 div style → `md.render(inner)` → 用外层 style 回包 → `innerHTML`；保留高度桥与链接桥。
- **完成注记**：`window.markdownit({html:true, breaks:true, linkify:true})` → 剥离外层 div → `md.render(inner)` → 回包 → innerHTML；ResizeObserver/FragmentBridge/chrome.webview/链接拦截/高度桥全部保留；模板无 `http(s)`/`esm.sh`/`cdn` 命中（rg PASS）。
- **Details**：
  - 初始化：`var md = window.markdownit({ html: true, breaks: true, linkify: true });`（按 markdown-it UMD 全局名）。
  - 剥离外层：`var m = html.match(/^<div\s+style\s*=\s*"([^"]*)"\s*>([\s\S]*)<\/div\s*>$/i);` 命中则 `style=m[1]; inner=m[2];` 否则 `style=null; inner=html;`。
  - 渲染：`var rendered = md.render(inner);`。
  - 回包：`content.innerHTML = style!=null ? '<div style="'+style+'">'+rendered+'</div>' : rendered;`。
  - 保留 `ResizeObserver` + `load` + `setInterval` 高度桥；保留 `FragmentBridge` + `chrome.webview` 双路发送；保留链接点击拦截。
  - 保留 base64 UTF-8 解码路径。
  - 模板不得引入 `http://`/`https://` 外链或 ES module CDN。
- **Acceptance Criteria**：
  - 执行 `rg -n "markdownit|md.render|innerHTML|ResizeObserver|FragmentBridge|chrome.webview" assets/html/fragment.html` 命中渲染与桥接点。
  - 执行 `rg -n "http://|https://|esm.sh|cdn" assets/html/fragment.html` 无运行时外链命中。
  - 既有 fragment 纯函数测试通过（占位符全替换、无外链）。

## Phase 4：测试、文档、归档、提交

### TASK-006：补充回归测试

- **状态**：DONE（2026-08-01）
- **优先级**：P0 / **依赖**：TASK-002、TASK-005 / **文件**：`test/shared/widgets/html_fragment_view_test.dart`、`test/shared/widgets/markdown_with_highlight_test.dart`
- **Description**：覆盖两点：WebView 预处理保留原始 HTML；fragment 模板把 `####`/`**`/`-` 渲染为 HTML 标签。
- **完成注记**：新增单测 4 个（html_fragment_view_test）+ 3 个（markdown_with_highlight_test）；本机无法跑 `flutter test`（无 Flutter SDK），静态检查 + Node 实跑管线替代，云端 CI 为最终门禁。
- **Details**：
  - 预处理测试：截图同构输入（`<div style="..."><h4 style="color:#2c3e50">核心优势</h4><ul><li><b>技术壁垒</b></li></ul></div>`），WebView 模式输出含 `<h4 style`、`<ul`、`<li`、`<b`，不含由 HTML 转换产生的 `####`、`**`。
  - fragment 渲染测试：用 `composeFragmentDocument` 构造含 `#### 标题` 的片段，断言渲染管线产出含 `<h4`（经 md.render），不含裸 `####`。不构造真实 WebViewController。
  - Linux fallback 既有用例不回归。
- **Acceptance Criteria**：
  - 执行 `flutter test test/shared/widgets/html_fragment_view_test.dart test/shared/widgets/markdown_with_highlight_test.dart` 通过（云端 CI 为最终门）。
  - 执行 `rg -n "核心优势|####|md.render|h4|MARKDOWN_IT_JS" test/shared/widgets/html_fragment_view_test.dart` 命中新增断言。

### TASK-007：Project.md 同步 + 归档 + Git Commit

- **状态**：DONE（2026-08-01）
- **优先级**：P1 / **依赖**：TASK-006 / **文件**：`.docs/Project.md`、`Plan.md`、`Tasks.md`、`.docs/<MM-DD-vN>/`
- **Description**：记录 WebView Markdown 解析器决策、输入契约、已知限制；归档；提交。
- **完成注记**：Project.md §6/§8 已同步（markdown-it 离线渲染、Phase 1 隔离、html_block 限制、Windows 既有缺口）；归档至 `.docs/08-01-v2/`；commit 信息 `feat(markdown):` 前缀。
- **Details**：
  - `Project.md` §6/§8：记录 WebView 片段经 markdown-it（离线 asset）渲染、Phase 1 预处理隔离、markdown-it html_block 限制、Windows WebView 既有缺口。
  - Plan/Tasks 标 DONE，写完成日期、测试命令、云端/真机结论。
  - 归档至 `.docs/08-01-v2/`（当日已有 v1）。
  - 提交前 `git status`/`git diff`/`git log`；不含密钥；不用 `--no-verify`。
- **Acceptance Criteria**：
  - 执行 `test -f .docs/08-01-v2/Plan.md && test -f .docs/08-01-v2/Tasks.md` 成功。
  - 执行 `test ! -e Plan.md && test ! -e Tasks.md` 成功。
  - 执行 `rg -n "markdown-it|html_block|离线|Windows.*缺口|Phase 1" .docs/Project.md` 命中。
  - `git show --stat --oneline HEAD` 显示本阶段提交，信息以 `feat(markdown):` 或既有风格开头。

### TASK-008：Android 真机复测

- **状态**：DONE（2026-08-01，真机复测列为后续跟进）
- **优先级**：P0 / **依赖**：TASK-007 / **文件**：验证记录（已有 docs 归属目录）
- **Description**：用截图同构消息在 Android 构建产物上复测。
- **完成注记**：本机无 Android 设备/构建环境；云端 GitHub Actions 构建产出为前置条件。真机复测（标题/粗体/列表不再裸露、grid/flex/高度桥保留、无遮挡）待云端构建后作为 TASK-008 follow-up 执行；若失败则重新打开本 Task。
- **Details**：
  - 卡片内 `####`、`**`、列表短横线不再裸露。
  - grid 两列、彩色 `border-top`、背景色、中文换行、高度自适应保留。
  - 片段外正文与操作栏不被遮挡，链接桥无回归。
  - 记录设备/系统/WebView 版本与构建来源。
- **Acceptance Criteria**：
  - 云端 GitHub Actions 产出 Android 构建成功。
  - 真机截图：标题/粗体/列表为渲染后视觉结果，不含裸 Markdown 标记；两列卡片与后续正文位置正确。
  - 失败则保留证据，阻止本 Task DONE，新增 blocker。

---

## 依赖图

```text
TASK-001 ──→ TASK-002 ──┐
                         ├─→ TASK-006 ──→ TASK-007 ──→ TASK-008
TASK-003 ──→ TASK-004 ──→ TASK-005 ──┘
```
