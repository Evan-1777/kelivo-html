# Tasks：聊天页 HTML 片段渲染修复 v2.0

**关联 Plan**：`Plan.md`（根目录）  
**总计 Task**：5 个  
**状态**：DONE  
**日期**：2026-07-30

所有修改仅限 `lib/shared/widgets/markdown_with_highlight.dart`。

---

## Phase 1：Fix A — 内联转换升级

### TASK-001：升级 `_convertInlineHtmlFormatting`（约 L765-795）

- **Status**：DONE
- **Description**：属性容忍 + 新增标题/列表/hr/blockquote/span 转换 + `inlineOnly` 参数。
- **Details**：
  1. 现有 4 个内联正则 `<(?:strong|b)\s*>` 等改为 `<(?:strong|b)\b[^>]*>`（em/i、s/del/strike、code 同理）。`\b` 必须保留——防止 `<b\b` 匹配 `<br>`、`<s\b` 匹配 `<span>`、`<i\b` 匹配 `<img>`
  2. 函数签名改为 `String _convertInlineHtmlFormatting(String input, {bool inlineOnly = false})`
  3. 转换顺序（必须遵守）：`<br>`→`\n` → b/i/s/code 内联 → 标题 → 列表 → hr → blockquote → span 类剥离
  4. `inlineOnly=true` 时只执行 br + b/i/s/code，跳过后续块级转换
  5. 新增（仅 inlineOnly=false 时）：
     - 标题：`RegExp(r'(^|\n)[ \t]*<h([1-6])\b[^>]*>([\s\S]*?)</h\2\s*>[ \t]*(?=\n|$)', caseSensitive: false)` → `'${m[1]}\n\n${'#' * int.parse(m[2]!)} ${m[3]!.trim()}\n\n'`
     - 列表容器 `</?(?:ul|ol)\b[^>]*>` → `'\n'`；`<li\b[^>]*>([\s\S]*?)</li\s*>` → `'\n- ${m[1]!.trim()}'`（ponytail 注释：ol 编号降级为 bullet，升级路径=按 ol 块计数器）
     - `<hr\s*/?>` → `'\n\n---\n\n'`
     - blockquote：`<blockquote\b[^>]*>([\s\S]*?)</blockquote\s*>` → body 按 `\n` 拆行逐行加 `> ` 前缀，前后各包 `\n`
     - 剥离：`</?(?:span|font|mark|sub|sup|small|center|section|article|header|footer|main|aside|figure|figcaption)\b[^>]*>` → `''`
  6. `_convertHtmlTablesToMarkdown` 中单元格调用改为 `_convertInlineHtmlFormatting(cellContent, inlineOnly: true)`
- **Acceptance Criteria**：
  - `grep -n "inlineOnly" lib/shared/widgets/markdown_with_highlight.dart` ≥ 3 处命中（签名 + 块级守卫 + 表格调用处） ✅ 4 hits
  - `grep -n '<h(\[1-6\])' lib/shared/widgets/markdown_with_highlight.dart` 命中 ✅ L798
  - `grep -n 'blockquote' lib/shared/widgets/markdown_with_highlight.dart` 命中（_convertInlineHtmlFormatting 区域内） ✅ L811, L813
  - `grep -n '<(?:strong|b)\\\\b' lib/shared/widgets/markdown_with_highlight.dart` 命中（属性容忍） ✅ L772

## Phase 2：Fix B — 嵌套 div 平衡匹配

### TASK-002：StyledDivBlockMd 平衡模式（约 L5850-5930）

- **Status**：DONE
- **Description**：仿 `_detailsPattern`（L5693-5701）实现 `_divPattern` 递归平衡模式，修复嵌套截断。
- **Acceptance Criteria**：
  - `grep -n "_divPattern" lib/shared/widgets/markdown_with_highlight.dart` ≥ 2 处命中（定义 + 引用） ✅ 2 hits (L5905, L5909)
  - tempered 负前瞻结构可见 ✅ L5903, L5906
  - build() 区域贪婪 body 正则命中 ✅ L5967 `[\s\S]*`

## Phase 3：Fix C — CSS 解析补全

### TASK-003：build() CSS 解析（StyledDivBlockMd.build 约 L5935-5995）

- **Status**：DONE
- **Description**：补 `border` 简写、`border-width/color`、`border-radius` 解析；纯 layout 容器不加默认底色。
- **Acceptance Criteria**：
  - `grep -n "border-radius\|borderRadius" lib/shared/widgets/markdown_with_highlight.dart` 在 StyledDivBlockMd 区域命中 ✅ L6000, L6020+
  - `grep -n "hasVisual" lib/shared/widgets/markdown_with_highlight.dart` 命中 ✅ 3 hits (L6003, L6020, L6028)
  - `grep -n "_extractBorderWidth(css\['border'\])" lib/shared/widgets/markdown_with_highlight.dart` 命中 ✅ L6000

## Phase 4：Test + 文档 + 归档 + 提交

### TASK-004：编译/静态验证

- **Status**：DONE
- **Description**：无 Flutter/Dart SDK。静态验证：grep 确认括号平衡差值与修改前一致（+3 来自字符串字面量），三个修改区域结构完整。待设备 `flutter analyze` 最终验证。
- **Acceptance Criteria**：
  - ✅ 静态检查通过，记录「待设备验证」

### TASK-005：Document Maintenance + Archive + Git Commit

- **Status**：DONE
- **Description**：
  1. Project.md：本次无新依赖/新模块/架构变更，不改 Project.md ✅
  2. Plan.md / Tasks.md 标记 `状态：DONE` + 完成日期 + 测试结论 ✅
  3. Archive：→ `.docs/07-30-v2` ✅
  4. Commit：`fix(markdown): ...` + `docs: archive Plan.md and Tasks.md to .docs/07-30-v2` ✅
- **Acceptance Criteria**：
  - 根目录无 Plan.md/Tasks.md 残留；`.docs/<归档目录>/` 含两文件 ✅
  - `git log --oneline -3` 显示新提交；`git status` 干净（除既有 untracked） ✅
