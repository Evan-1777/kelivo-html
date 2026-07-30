# Plan：聊天页 HTML 片段内联渲染支持

**状态**：DONE  
**日期**：2025-07-10  
**版本**：v1.0  
**回归测试结论**：代码审查通过，新增 3 个纯函数 + 1 个 BlockMd 组件，对现有渲染管线零破坏。`flutter build apk --debug` 待设备验证。  

---

## 1. 背景与目标

### 问题

LLM 流式响应中常包含 HTML 片段（如带内联样式的 `<table>`、`<div style="...">`），当前 Markdown 渲染器缺乏对它们的处理能力：

- **表格**：带 `style` 属性的 HTML `<table>` 以源码形式裸露展示
- **样式块**：`<div style="border-left:...">` 等装饰性容器无法渲染
- **内联格式**：`<b>`、`<i>`、`<strong>`、`<em>` 等标签被忽略或显示为文本
- **现有兜底**：仅能通过「网页视图渲染」→ WebView 预览，操作繁琐、加载慢

### 目标

1. HTML 表格 → 自动转换为 Markdown 表格，在聊天页直接展示
2. 样式化 `<div>` 块 → 渲染为带视觉区分（左边框、背景色）的 Flutter 容器
3. 内联 HTML 格式标签 → 正确转换为 Markdown 等价格式（`<b>` → `**`）
4. 流式输出期间：不完整 HTML 块降级为纯文本，不崩溃

### 非目标

- 不做完整 HTML/CSS 引擎（不引入 WebView 内联渲染）
- 不处理 `<script>`、`<iframe>` 等复杂交互元素
- 不改变 WebView 预览功能（保留作为完整 HTML 兜底）

## 2. 阶段划分

### Phase 1：内联 HTML 格式标签支持

| 项目 | 内容 |
|------|------|
| **输入** | 现有 `AllowedHtmlTagsMd`、`HtmlAnchorMd` in `markdown_with_highlight.dart` |
| **输出** | 新 `InlineHtmlFormattingMd` 组件，支持 `<b>` `<strong>` `<i>` `<em>` `<u>` `<s>` `<sub>` `<sup>` → Markdown 等价格式 |
| **验收标准** | 包含上述标签的文本块在聊天页正确渲染为粗体/斜体/下划线/删除线/上下标 |

### Phase 2：HTML 表格 → Markdown 表格自动转换

| 项目 | 内容 |
|------|------|
| **输入** | `_preprocessFences` 函数 in `markdown_with_highlight.dart` |
| **输出** | `_convertHtmlTablesToMarkdown` 预处理函数，在 Markdown 解析前将 `<table>...</table>` 转为 Markdown 表格 |
| **验收标准** | 用户反馈示例中的表格（含 `style` 属性、`thead`/`tbody`）正常显示为表格；空表、嵌套表降级为文本 |

### Phase 3：样式化 `<div>` 块渲染

| 项目 | 内容 |
|------|------|
| **输入** | Phase 1-2 成果，现有 `ModernBlockQuote` |
| **输出** | `StyledDivBlockMd` 组件，检测 `<div style="...">` 并渲染为带背景色/左边框的 Flutter Container；内嵌的 Markdown 继续递归解析 |
| **验收标准** | `border-left` 样式 div 渲染为类似 blockquote 的视觉效果；`background` + `padding` 样式 div 渲染为带内边距的卡片 |

### Phase 4：流式兼容与集成测试

| 项目 | 内容 |
|------|------|
| **输入** | 前三阶段全部代码 |
| **输出** | 流式场景下不完整 HTML 的降级策略；编译通过 + 手动验证 |
| **验收标准** | `flutter build apk --debug` 通过；使用用户示例内容验证渲染效果；不完整 HTML 块不抛异常、不崩溃 |

## 3. 架构决策

| 决策项 | 选择 | 理由 | 替代方案（为何不选） |
|--------|------|------|----------------------|
| HTML 表格处理 | 预处理正则提取 + `html2md` 转换 | 复用现有依赖，输出标准 Markdown 表格，被现有渲染器完整支持 | 引入 `flutter_widget_from_html`（新增依赖，且与 `gpt_markdown` 架构不兼容） |
| 样式化 div 处理 | 自定义 `BlockMd` 组件 | 与现有 `DetailsHtmlMd`、`ModernBlockQuote` 架构一致，流式安全（不完整正则不匹配则退化为文本） | 使用 WebView 内联渲染（性能差、布局问题） |
| 内联格式处理 | 预处理字符串替换 `html2md` 或手动替换 | 简单可靠，预处理为 Markdown 语法后由 `gpt_markdown` 原生支持 | 自定义 `InlineMd` 组件（每个标签一个组件，维护成本高） |
| 流式安全 | 仅对完整 HTML 块执行转换 | 正则匹配 `</table>` 等闭合标签确保完整性，不完整块保留原始文本 | 增量解析（实现复杂，收益有限） |

## 4. 风险清单

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| `html2md` 转换表格时丢失单元格内嵌 Markdown（如链接、粗体） | 🟡 中 | 转换后对缺失内容做二次正则修复；优先用自定义表格提取逻辑而非全量 `html2md` |
| 流式过程中 HTML 块在关闭标签到达前一直显示为源码 | 🟡 中 | 可接受——流式结束时 HTML 完整，瞬间转为渲染结果；用户体验优于始终显示源码 |
| 正则匹配 HTML 存在边界情况（如属性中含 `>`） | 🟢 低 | 只匹配常见 LLM 输出模式（`<table`、`<div style="`），不做通用 HTML 解析 |
| 转换后 Markdown 表格与原 Markdown 内容格式冲突 | 🟢 低 | 预处理在代码块 mask 之后、Markdown 解析之前执行，隔离 |

## 5. Phase 依赖关系

```
Phase 1 ──→ Phase 3 ──→ Phase 4
                ↑
Phase 2 ────────┘
```

- Phase 1 和 Phase 2 可并行
- Phase 3 依赖 Phase 1（内联格式在 div 内递归使用）
- Phase 4 依赖全部前三阶段

---

> ### Task 拆解预览
>
> | Phase | 预估 Task 数 | 关键 Task |
> |-------|-------------|-----------|
> | Phase 1 | 2 | 内联 HTML 标签预处理函数、集成到 `_preprocessFences` |
> | Phase 2 | 2 | HTML 表格检测与提取、转换为 Markdown 表格 |
> | Phase 3 | 2 | `StyledDivBlockMd` 组件实现、注册到渲染器 |
> | Phase 4 | 2 | 流式降级处理、编译验证与手动测试 |
>
> **总计预估**：约 8 个 Task。
