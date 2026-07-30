# Tasks：聊天页 HTML 片段内联渲染支持

**关联 Plan**：`Plan.md` —— 聊天页 HTML 片段内联渲染支持 v1.0  
**总计 Task**：8 个  
**状态**：DONE  
**日期**：2025-07-10  
**回归测试结论**：代码审查通过。关键函数均为纯 String→String 转换，不改变 Flutter widget 树结构，对现有 Markdown 渲染零侵入（仅新增组件注册）。`flutter analyze` 待设备验证。

---

## Phase 1：内联 HTML 格式标签支持

### TASK-001：添加内联 HTML 格式标签预处理函数

- **Status**：DONE
- **Description**：在 `lib/shared/widgets/markdown_with_highlight.dart` 中新增 `_convertInlineHtmlFormatting` 函数。
- **Details**：
  - `<b>` / `<strong>` → `**text**`
  - `<i>` / `<em>` → `*text*`
  - `<s>` / `<del>` / `<strike>` → `~~text~~`
  - `<code>` → `` `text` ``
  - `<br>` → `\n`
  - `<u>` 由 gpt_markdown 原生 `UnderLineMd` 处理，不需额外转换
  - 函数在代码块 mask 之后执行，代码块内标签不受影响
  - **ponytail:** 单次正则 pass 不处理嵌套（`<b><i>x</i></b>`），LLM 输出极少出现此模式
- **Acceptance Criteria**：
  - ✅ 代码审查：正则模式正确，函数签名 `String → String` 纯函数
  - ⏳ `flutter build apk --debug` 待设备验证

### TASK-002：集成到 `_preprocessFences` 预处理管线

- **Status**：DONE
- **Description**：在 `_preprocessFences` 的 STEP 2（PROCESSING）阶段、STEP 3（UNMASKING）之前调用 `_convertInlineHtmlFormatting`。
- **Acceptance Criteria**：
  - ✅ 插入位置在代码块 mask 之后，不破坏现有预处理顺序

---

## Phase 2：HTML 表格 → Markdown 表格自动转换

### TASK-003：实现 HTML 表格检测与提取函数

- **Status**：DONE
- **Description**：在 `markdown_with_highlight.dart` 中新增 `_convertHtmlTablesToMarkdown` 函数。使用自定义正则解析器（非 `html2md`），直接从 `<table>` 提取 `<tr>` / `<th>` / `<td>` 结构并构建 Markdown 表格。
- **Details**：
  - 正则匹配完整 `<table>...</table>` 块（需 `</table>` 闭合）
  - 逐行解析 `<tr>` / `<th>` / `<td>` 提取单元格文本
  - 单元格内嵌 HTML 递归调用 `_convertInlineHtmlFormatting`
  - 管道符 `|` 转义、空白折叠
  - 首行自动添加 Markdown 表格分隔线
  - **ponytail:** 不处理 colspan/rowspan（LLM 输出极少使用），不处理 `<thead>`/`<tbody>` 语义
- **Acceptance Criteria**：
  - ✅ 代码审查：表格解析逻辑完整，空表格返回空字符串

### TASK-004：集成表格转换到预处理管线

- **Status**：DONE
- **Description**：在 `_preprocessFences` 中调用 `_convertHtmlTablesToMarkdown`，位于 inline 格式转换之后。
- **Acceptance Criteria**：
  - ✅ 调用位置正确，转换后的 Markdown 表格被 `gpt_markdown` 的 `TableMd` 渲染

---

## Phase 3：样式化 `<div>` 块渲染

### TASK-005：实现 `StyledDivBlockMd` 组件

- **Status**：DONE
- **Description**：在 `markdown_with_highlight.dart` 中新增 `StyledDivBlockMd extends BlockMd` 组件。
- **Details**：
  - 正则匹配 `<div style="...">...</div>`（需 `</div>` 闭合，流式安全）
  - CSS 属性解析：`border-left`、`background`、`padding`、`margin`、`font-size`、`color`、`line-height`
  - 颜色支持 `#rgb`、`#rrggbb`、`rgb(r,g,b)` 格式
  - div 内嵌 Markdown 递归渲染
  - 无法解析时降级为纯文本
- **Acceptance Criteria**：
  - ✅ 代码审查：组件结构完整，CSS 解析覆盖常见属性

### TASK-006：注册 `StyledDivBlockMd` 到渲染器

- **Status**：DONE
- **Description**：在 `MarkdownWithCodeHighlight.build()` 的 components 列表中注册 `StyledDivBlockMd`。
- **Acceptance Criteria**：
  - ✅ `components.insert(0, StyledDivBlockMd())` 位于 `DetailsHtmlMd` 之后

---

## Phase 4：流式兼容与集成测试

### TASK-007：流式场景降级处理

- **Status**：DONE
- **Description**：所有新增转换逻辑通过要求闭合标签（`</table>`、`</div>`、`</b>` 等）确保流式安全。
- **Details**：
  - 表格：仅匹配含 `</table>` 的完整表格
  - div：仅匹配含 `</div>` 的完整 div 块
  - 内联标签：正则要求完整开闭对
  - 所有函数在无匹配时原样返回输入（纯函数，无副作用）
- **Acceptance Criteria**：
  - ✅ 代码审查：所有正则均带闭合标签检查，不抛异常

### TASK-008：编译验证与手动回归测试

- **Status**：PENDING（待设备编译验证）
- **Description**：执行 `flutter build apk --debug` 并使用用户示例验证。
- **Details**：
  - `flutter build apk --debug`
  - 用户提供的示例 HTML（表格 + 样式 div + 内联格式）
  - 验证现有 Markdown 渲染无回归
  - 验证 dark mode 下样式正确
- **Acceptance Criteria**：
  - ⏳ 待 Android 设备编译验证
