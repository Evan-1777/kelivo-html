# Plan：聊天 HTML 片段资源打包修复

**状态**：DONE  
**日期**：2026-07-31  
**版本**：v5.0  
**回归测试结论**：执行侧已完成——`pubspec.yaml` 已声明 fragment 模板，新增 `fragment.html bundled asset` 回归测试组（rootBundle 加载 + 占位符断言）；本机按项目约束不运行 Flutter 构建，云端 CI 的 `flutter analyze` 与 `flutter test` 为最终门（无 Flutter SDK，`flutter pub get`/`flutter test` 待云端执行）。

---

## 1. 背景与目标

用户提供的 Android 截图显示，聊天中的普通 Markdown 正常，但两个包含 `<div style="...">` 的 HTML 卡片区域呈现为空白矩形，后续文本仍继续显示。

Explore 已沿 `StyledDivBlockMd → HtmlFragmentView → fragment.html` 链路确认：

- `StyledDivBlockMd` 在 Android 识别完整 div，并返回 `HtmlFragmentView`，因此不是原生 CSS grid/flex fallback 排版问题。
- `HtmlFragmentView._load()` 依赖 `rootBundle.loadString('assets/html/fragment.html')` 生成 WebView 文档。
- `assets/html/fragment.html` 文件已存在且已被 Git 跟踪，但 `pubspec.yaml` 的 Flutter assets 清单仅声明了 `assets/html/mark.html`。
- 资源加载异常发生在异步 `_load()` 中，未被组件展示；WebView 容器保留初始高度 48，最终表现为截图中的空白卡片占位。

目标：将 fragment 模板正确打入 Flutter 资源包，并加入能检测资源声明与内容可加载性的回归检查，恢复 Android/iOS/macOS/Windows 上 HTML 卡片的实际渲染。

## 2. 阶段划分

### Phase 1：资源声明与回归验证

| 项目 | 内容 |
|------|------|
| **输入** | 已存在的 `assets/html/fragment.html`、`HtmlFragmentView` 的 `rootBundle` 读取路径 |
| **输出** | `pubspec.yaml` 中的资源声明；资源打包回归测试 |
| **验收标准** | 资源路径同时出现在文件系统和 `pubspec.yaml` 的 `flutter.assets` 列表；测试能通过 `rootBundle` 读取模板且包含关键占位符；静态资源路径检查通过 |

### Phase 2：项目文档与阶段收尾

| 项目 | 内容 |
|------|------|
| **输入** | Phase 1 代码与测试结果 |
| **输出** | `.docs/Project.md` 约束记录；完成的 Plan/Tasks 归档；Git 提交 |
| **验收标准** | Project.md 与实际资源依赖一致；Plan/Tasks 含完成日期与测试结论；根目录无完成阶段文档残留；提交不包含密钥或用户无关修改 |

## 3. 架构决策

| 决策项 | 选择 | 理由 | 替代方案（为何不选） |
|--------|------|------|----------------------|
| 资源修复位置 | 在 `pubspec.yaml` 声明既有 fragment 模板 | Flutter asset bundle 由 pubspec 管理，改动最小且直接修复根因 | 在运行时读取文件系统路径（移动端无稳定路径且绕过 asset bundle） |
| 回归检查 | 同时做静态声明检查与 `rootBundle` 读取测试 | 静态检查覆盖声明遗漏，运行测试覆盖路径/模板内容错误 | 仅测试 HTML 字符串（无法发现资源未打包） |
| 渲染架构 | 保留片段 WebView 与 Linux/Web 原生 fallback | 本次故障是资源打包遗漏，不需要重写渲染器 | 回退到自研 CSS 解析（无法覆盖完整 CSS，且扩大风险） |

## 4. 风险与缓解

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 资源声明缩进或路径错误导致 `pubspec` 解析失败 | 中 | 执行 `flutter pub get`/CI 解析，并运行资源读取测试 |
| 测试环境未注册 WebView 平台 | 低 | 回归测试只读取 `rootBundle`，不构造 WebView；既有 Linux fallback 测试保持不变 |
| 运行时资源加载异常仍被静默吞掉 | 中 | 本次先修复打包根因；保留真机验证项，后续可按日志策略补充可观测性 |

## 5. 阶段依赖关系

```
Phase 1 ──→ Phase 2
```

严格串行。
