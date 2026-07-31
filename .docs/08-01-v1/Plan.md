# Plan：聊天 HTML 片段 WebView 渲染（片段混合方案）

**状态**：DONE  
**日期**：2026-08-01  
**版本**：v4.0  
**回归测试结论**：纯函数/平台判定单测 + Linux fallback widget 测试已写入；本机无 Flutter SDK，云端 CI 编译与 `flutter test` 为最终门。待真机验证项：iOS 高度自适应与内部滚动、Windows JS channel（双路发送 + setInterval 兜底）、流式 AnimatedSize 包裹 WebView 闪烁、WebView 内文本选择为平台原生菜单（已接受折衷）。

---

## 1. 背景与目标

07-31 原生增强（grid/flex 多列 + 方向边框）后，实测（2026-08-01 手机长截屏对比）仍不达标：grid 两列卡片竖排错乱、flex 三卡片内容缺失错位。用户定性"渲染完全达不到要求、大量日常小错误干扰"，要求评估并确认引入 Web 能力渲染**片段化 HTML**。经 Explore 判断 + 用户确认，采用**片段混合 WebView 方案**：

- 消息中的完整 `<div style="...">...</div>` 块交给 WebView（平台引擎解析全部 CSS，与预览一致）
- 其余文本继续原生 gpt_markdown（选择/复制/引用 tap 全部保留）
- 原生 `StyledDivBlockMd` 保留为 fallback（Linux 无 WebView 平台 + WebView 异常兜底）

**目标**：`<div style>` 卡片块渲染与 Markdown 预览一致（flex 换行、grid 两列、border-top 彩色顶边、内联样式全支持），一次投入永久正确。

## 2. 关键事实（Explore 结论）

| 事实 | 影响 |
|------|------|
| `webview_flutter ^4.13.1` + `wkwebview` + `webview_windows` 已是依赖 | 零新依赖 |
| 项目已用 4.x API：`WebViewWidget(controller:)`（html_preview_page） | 复用同一 API 风格 |
| 已有 `MarkdownPreviewHtmlBuilder` 颜色注入模式 + mark.html 的 console bridge（`window.Console.postMessage` + `window.chrome.webview.postMessage` 双路，Windows 已验证） | 注入与桥接模式可复用 |
| **片段是纯 HTML，无需 markdown-it** | 模板零 CDN 依赖（mark.html 的 esm.sh CDN 不可用场景被绕开）、离线可用 |
| `GptMarkdownConfig.onLinkTap(url, title)` 已存在 | 链接点击桥接可复用 |
| 无 pubspec.lock、本机无 Flutter SDK | 验证门 = 云端 CI + 真机 |

## 3. 阶段划分

### Phase 1：fragment 模板 + 纯函数层

| 项目 | 内容 |
|------|------|
| **输入** | 无（新文件） |
| **输出** | `assets/html/fragment.html`（内联 CSS 镜像 mark.html 风格 + 高度桥 JS + 链接拦截 JS + 双路 channel）+ `lib/shared/widgets/html_fragment_view.dart` 的纯函数（`composeFragmentDocument` / `shouldUseWebViewForHtml`） |
| **验收** | 模板零外部 URL；纯函数单测机械可验证（内容 base64 往返、颜色注入、平台判定） |

### Phase 2：HtmlFragmentView 组件 + 集成

| 项目 | 内容 |
|------|------|
| **输入** | Phase 1 模板与纯函数 |
| **输出** | `HtmlFragmentView`（StatefulWidget：WebViewController + JS channel 高度桥→SizedBox 高度 + 链接桥→onLinkTap；didUpdateWidget 内容变化才 reload）；`StyledDivBlockMd.build()` 委托 WebView，非 WebView 平台走既有原生 `_buildDivContainer` |
| **验收** | 组件存在且可构建；grep 命中委托点；Linux 下原生 fallback 不回归（既有测试绿） |

### Phase 3：测试 + 文档 + 归档 + 提交

| 项目 | 内容 |
|------|------|
| **输入** | Phase 1/2 代码 |
| **输出** | 新测试（纯函数单测 + Linux fallback widget 测试）；既有 div 测试加 Linux override（防 WebViewPlatform null 崩溃）；Project.md 同步；归档；commit |
| **验收** | 云端 CI 编译 + 测试为最终门；工作树仅含本次变更 |

## 4. 架构决策

| 决策项 | 选择 | 理由 | 替代方案（为何不选） |
|--------|------|------|----------------------|
| 渲染范围 | 仅完整 `<div style>` 块走 WebView | 用户确认；普通文本/选择/引用零回归 | 整条消息 WebView（全量重构，风险大） |
| 触发平台 | `defaultTargetPlatform != linux && !kIsWeb` | Android/iOS/macOS/Windows 均有 WebView 实现；Linux 无 | 全平台（Linux 会崩） |
| 内容注入 | base64 + TextDecoder（UTF-8 中文安全） | 免转义、防 `{{`/`</script>` 冲突 | 直接插值（注入风险） |
| 高度自适应 | JS `ResizeObserver` → `FragmentBridge.postMessage` + `setInterval` 兜底（Windows） | 简单可靠；mark.html 已证双路 channel | 定时 evaluateJavascript 轮询（移动端开销） |
| 链接桥 | 模板 JS 拦截 `a[href]` click → postMessage → `config.onLinkTap(url, '')` | 复用既有回调 | 自建 url_launcher 路径（重复） |
| 流式更新 | didUpdateWidget 比较 fragment，变化才 reload | 流式重建不闪 WebView | 每次 build reload（闪烁） |
| 背景色 | 注入 `Theme.colorScheme.surfaceContainerLow`（气泡级） | PlatformView 白底突兀问题 | 透明背景（iOS opaque 风险） |
| 测试策略 | 纯函数单测 + Linux override 走原生 fallback 的 widget 测试 | WebView 平台无本机 SDK，机械可验证的部分最大化 | Fake WebViewPlatform（接口庞大，脆） |

## 5. 风险清单

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 测试环境 `WebViewPlatform.instance == null` → 含 div 用例崩溃 | 🔴 高 | 所有渲染 div 的 widget 测试统一 `debugDefaultTargetPlatformOverride = TargetPlatform.linux`（走原生 fallback，断言仍成立） |
| iOS 高度自适应/滚动（PlatformView 尺寸同步） | 🟡 中 | 模板 `html,body{overflow:hidden}`；真机验证项，记录在 Tasks 收尾注释 |
| Windows JS channel（webview_windows 对 addJavaScriptChannel 支持度） | 🟡 中 | 双路发送（FragmentBridge + chrome.webview，mark.html 已验证模式）+ setInterval 兜底 |
| 流式 `AnimatedSize` 包裹 WebView 动画闪烁 | 🟡 中 | didUpdateWidget 内容比较不 reload；StreamingMotion 开启时若闪烁，接受或后续排除 WebView 子树（记录已知限制） |
| WebView 内文本选择为平台原生菜单（与 SelectionArea 行为不同） | 🟢 低 | 用户已确认接受的折衷，Plan 记录 |
| div 内 mermaid/katex 不渲染（fragment 模板无对应 JS） | 🟢 低 | 与原生一致（原生同样不渲染）；已知限制记录 |
| 无 Flutter SDK，编译正确性依赖 CI | 🟡 中 | 严格镜像既有 API 用法（WebViewWidget/WebViewController/addJavaScriptChannel 均已在项目中使用过） |

## 6. Phase 依赖关系

```
Phase 1 ──→ Phase 2 ──→ Phase 3
```

严格串行。

## 7. 关键决策记录

- 原生 `StyledDivBlockMd` 多列/方向边框能力**保留**（Linux fallback + WebView 异常兜底），不删除。
- div 内引用格式（`[citation]`）为 markdown 语法，div 原始 HTML 内不解析 → 链接统一走 `onLinkTap`，不做 citation 特殊转发（已知限制）。
- 模板 CSS 仅覆盖常见元素（h1-h6/p/ul/ol/li/pre/code/table/img/a/hr/blockquote），镜像 mark.html 风格；div 内联 style 优先级更高，自动生效。
