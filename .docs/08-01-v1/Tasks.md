# Tasks：聊天 HTML 片段 WebView 渲染

**Plan**：Plan.md（根目录）  
**状态总览**：全部 DONE（2026-08-01）。  
**验证门**：本机无 Flutter SDK → 云端 CI（编译 + `flutter test`）为最终门；纯函数逻辑本机可机械验证（Node/静态断言）；WebView 真机行为记录为待验证项。

---

## Phase 1：fragment 模板 + 纯函数层

### TASK-001：创建 `assets/html/fragment.html` 模板

- **状态**：DONE
- **文件**：`assets/html/fragment.html`（新）
- **Description**：零外部依赖的内联模板：CSS 镜像 mark.html 风格 + 高度桥 JS + 链接拦截 JS + 双路 channel 发送。
- **Details**：
  1. `<head>`：`<meta charset="UTF-8">` + `<style>`。变量占位：`{{BACKGROUND}}` `{{ON_SURFACE}}` `{{ON_SURFACE_VARIANT}}` `{{PRIMARY}}` `{{OUTLINE_VARIANT}}` `{{BASE_FONT_SIZE}}` `{{LINE_HEIGHT}}` `{{FRAGMENT_BASE64}}`。
  2. CSS 规则：`html,body{margin:0;padding:0;overflow:hidden;background:{{BACKGROUND}};color:{{ON_SURFACE}};font-size:{{BASE_FONT_SIZE}}px;line-height:{{LINE_HEIGHT}};font-family:-apple-system,...sans-serif}`；h1-h6 字号递减/边距；p 间距；`code/pre` 背景 `{{OUTLINE_VARIANT}}` 淡色；`table` 边框；`a{color:{{PRIMARY}};text-decoration:none}`；`img{max-width:100%;height:auto}`；`blockquote/hr/ul/ol/li` 与 mark.html 一致风格。
  3. `<body>`：`<div id="content"></div>` + `<script>`：
     - 解码：`const b64=atob('{{FRAGMENT_BASE64}}');const bytes=Uint8Array.from(b64,c=>c.charCodeAt(0));document.getElementById('content').innerHTML=new TextDecoder('utf-8').decode(bytes);`
     - `send(msg)`：`if(window.FragmentBridge)FragmentBridge.postMessage(JSON.stringify(msg)); if(window.chrome&&window.chrome.webview)window.chrome.webview.postMessage(JSON.stringify(msg));`
     - 高度：`report()` 发送 `{type:'height',value:document.documentElement.scrollHeight}`；`new ResizeObserver(report).observe(document.body)`；`window.addEventListener('load',report)`；`setInterval(report,500)` 兜底。
     - 链接：`document.addEventListener('click',e=>{const a=e.target.closest('a[href]');if(a){e.preventDefault();send({type:'link',href:a.getAttribute('href')});}},true)`。
- **验收**：`ffgrep -n "http://\|https://" assets/html/fragment.html` 零命中（离线可用）；占位符 `{{FRAGMENT_BASE64}}` 等 8 个齐全。

### TASK-002：纯函数层（HTML 组装 + 平台判定）

- **状态**：DONE
- **依赖**：TASK-001
- **文件**：`lib/shared/widgets/html_fragment_view.dart`（新，本 Task 先写纯函数部分）
- **Description**：两个顶层纯函数 + 一个组件（组件见 TASK-003，本 Task 只写函数）：
  - `String composeFragmentDocument({required String template, required String fragmentHtml, required ColorScheme cs, required double fontSize, required double lineHeight, required Color bubbleBackground})`：同步纯函数，做全部 `{{...}}` 替换（`FRAGMENT_BASE64` 用 base64Encode(utf8.encode(fragmentHtml))，其余颜色用 `#RRGGBBAA` 格式——复用 `MarkdownPreviewHtmlBuilder` 的 `_toCssHex` 写法或导出等价小工具）。
  - `Future<String> buildFragmentDocument({required BuildContext context, required String fragmentHtml, required double fontSize, required double lineHeight})`：rootBundle 读模板 + 调 composeFragmentDocument（从 `Theme.of(context)` 取 cs 与 `surfaceContainerLow` 作背景）。
  - `bool shouldUseWebViewForHtml(TargetPlatform platform)`：`platform != TargetPlatform.linux && platform != TargetPlatform.fuchsia`。
- **Details**：`_toCssHex` 需含 alpha（模板背景需要）；颜色 map 键：BACKGROUND←bubbleBackground、ON_SURFACE←cs.onSurface、ON_SURFACE_VARIANT←cs.onSurfaceVariant、PRIMARY←cs.primary、OUTLINE_VARIANT←cs.outlineVariant。
- **验收**：`ffgrep -n "composeFragmentDocument\|shouldUseWebViewForHtml" lib/shared/widgets/html_fragment_view.dart` 命中。

---

## Phase 2：组件 + 集成

### TASK-003：`HtmlFragmentView` 组件

- **状态**：DONE
- **依赖**：TASK-002
- **文件**：`lib/shared/widgets/html_fragment_view.dart`
- **Description**：StatefulWidget：WebViewController + JS channel 高度桥 + 链接桥 + 内容变更 reload。
- **Details**：
  1. 参数：`fragmentHtml`（必填）、`fontSize`、`lineHeight`、`bubbleBackground`（默认取 Theme 注入值）、`onLinkTap`（`void Function(String url)?`）。其余从 `Theme.of(context)` 自取。
  2. `initState`：`WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..addJavaScriptChannel('FragmentBridge', onMessageReceived: _onMessage)`；`_load()` 里 `await _controller.loadHtmlString(buildFragmentDocument(...))`（异步 fire-and-forget，`mounted` 检查）。
  3. `_onMessage`：`jsonDecode` → `type=='height'` → 值 != 当前 `_height` 才 `setState`；`type=='link'` → `widget.onLinkTap?.call(href)`。
  4. `didUpdateWidget`：`widget.fragmentHtml != oldWidget.fragmentHtml` → 重新 build 文档并 `loadHtmlString`（防流式闪烁：内容相同不 reload）。
  5. `dispose`：`_controller.dispose()`。
  6. `build`：`Container(color: bubbleBackground, child: SizedBox(height: _height, width: double.infinity, child: WebViewWidget(controller: _controller)))`；`_height` 初始 48。
- **验收**：`ffgrep -n "class HtmlFragmentView\|addJavaScriptChannel\|WebViewWidget" lib/shared/widgets/html_fragment_view.dart` 命中；无未使用 import（编译由 CI 把关）。

### TASK-004：`StyledDivBlockMd.build()` 委托 WebView

- **状态**：DONE
- **依赖**：TASK-003
- **文件**：`lib/shared/widgets/markdown_with_highlight.dart`
- **Description**：块匹配成功后按平台分流：WebView 平台 → `HtmlFragmentView`；否则 → 既有 `_buildDivContainer`（原生 fallback，零改动保留）。
- **Details**：
  1. import `html_fragment_view.dart`。
  2. `build()` 中 `if (match == null) ...` 之后、原单列路径之前插入：
     ```dart
     if (shouldUseWebViewForHtml(defaultTargetPlatform)) {
       final base = config.style ?? const TextStyle();
       return HtmlFragmentView(
         fragmentHtml: text,
         fontSize: base.fontSize ?? 15.7,
         lineHeight: base.height ?? 1.5,
         onLinkTap: config.onLinkTap == null ? null : (url) => config.onLinkTap!(url, ''),
       );
     }
     ```
  3. 其余路径（含多列分支）原样保留（多列分支现在仅 Linux/异常时可达，不删——fallback 完整）。
- **验收**：`ffgrep -n "shouldUseWebViewForHtml\|HtmlFragmentView" lib/shared/widgets/markdown_with_highlight.dart` 命中；`_buildDivContainer`/`_buildMultiColumn` 仍存在（fallback 未删）。

---

## Phase 3：测试 + 文档 + 归档 + 提交

### TASK-005：既有 div 测试加 Linux override

- **状态**：DONE
- **依赖**：TASK-004
- **文件**：`test/shared/widgets/markdown_with_highlight_test.dart`
- **Description**：所有渲染 `<div>` 内容的 `testWidgets` 前设置 `debugDefaultTargetPlatformOverride = TargetPlatform.linux`（`addTearDown` 复位），否则测试环境 `WebViewPlatform.instance == null` 崩溃。原生 fallback 路径被断言（行为不变）。
- **Details**：定位上一轮新增的 3 个用例（grid 两列 / flex 三卡 / 全量内容不丢）及任何其他含 `<div style` 的用例；在用例体内首行加 override + `addTearDown(() => debugDefaultTargetPlatformOverride = null)`。若用例用了共享 pump helper，把 override 放 helper 内统一处理。
- **验收**：`ffgrep -n "debugDefaultTargetPlatformOverride" test/shared/widgets/markdown_with_highlight_test.dart` 命中 ≥3 处；测试文件无裸 WebViewController 构造（CI 把关）。

### TASK-006：新测试（纯函数 + fallback widget）

- **状态**：DONE
- **依赖**：TASK-002（纯函数）、TASK-004（widget 路径）
- **文件**：`test/shared/widgets/html_fragment_view_test.dart`（新）
- **Description**：机械可验证的测试三组：
- **Details**：
  1. `composeFragmentDocument` 单测：
     - 注入 fragment（含中文，如 `<p>核心优势</p>`）→ 输出含 base64 编码（断言模板占位符被替换、不含 `{{FRAGMENT_BASE64}}` 残留）；base64 解码输出 → 还原原文（中文无损）。
     - 颜色/字号/行高/背景注入断言（输出含 `#RRGGBBAA` 形式与 `font-size:15.7px` 等）。
     - 输出不含 `http://` / `https://`（离线断言）。
  2. `shouldUseWebViewForHtml` 单测：android/ios/macos/windows → true；linux → false。
  3. widget 测试（Linux override）：pump 含 grid div 块的消息（复用既有 fixture 片段）→ 找到原生 fallback 的卡片文本（如 `核心优势`）不崩溃；断言未出现 `HtmlFragmentView`（find.byType 无匹配）。
- **验收**：3 组测试存在且逻辑自洽；CI `flutter test` 为最终门。

### TASK-007：文档维护 + 归档 + Git Commit

- **状态**：DONE
- **依赖**：TASK-005, TASK-006
- **Description**：按 Document Maintenance → Archive → Git Commit 顺序收尾。
- **Details**：
  1. `.docs/Project.md`：§6 约束/§8 决策追加 v4.0 记录（HTML 片段走 WebView，原生 fallback 保留，Linux 无 WebView 平台）。
  2. Plan.md / Tasks.md 标 `状态：DONE` + 完成日期 + 回归测试结论（云端 CI 为门；记录待真机验证项：iOS 高度、Windows channel、流式 AnimatedSize 闪烁）。
  3. 归档 `.docs/08-01-v1/`（今日首个归档）。
  4. `git status`/`git diff`/`git log` 对齐既有 `feat:` 风格提交；不含密钥；不用 `--no-verify`。
- **验收**：`.docs/08-01-v1/` 同时含 Plan.md + Tasks.md；根目录无残留；一次干净提交（`git status` 工作树仅剩历史遗留 untracked 文件）。

---

## 依赖图

```
TASK-001 ──→ TASK-002 ──→ TASK-003 ──→ TASK-004 ──┬─→ TASK-005 ──→ TASK-007
                                                  └─→ TASK-006 ──↗
```
