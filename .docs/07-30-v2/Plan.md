# Plan：聊天页 HTML 片段渲染修复（嵌套 div + 属性标签 + 标题/列表转换）

**状态**：DONE  
**日期**：2026-07-30  
**版本**：v2.0（已完成，2026-07-30）

## 背景

v1.0 上线了 HTML 内联渲染（内联标签转换、表格转换、StyledDivBlockMd），但用户实测（截图）仍裸露源码：
- 外层 `<div style="flex:1; border:1px solid #e0e0e0; border-radius:8px; ...">` 开标签原样显示
- `<h4 style="...">科技与半导体产业</h4>` 原样显示
- 卡片边框样式丢失

真实 LLM 输出 = 外层 flex 容器 div 包裹多个卡片 div，每个卡片内含带 style 属性的 h4 + p。

## 根因（Explore 已验证，证据见 Tasks.md）

1. **H3 主因**：`StyledDivBlockMd.expString` 非贪婪 `[\s\S]*?` 在第一个内层 `</div>` 截断 → 嵌套 div 结构崩坏
2. **H2**：h1-h6 / ul / ol / li / hr / blockquote / span 无转换逻辑
3. **H1**：内联正则 `\s*` 不允许属性 → 一切带 style/class 的标签失配
4. **H4**：CSS 解析缺 `border` 简写与 `border-radius`
5. **H5 已知限制**：gpt_markdown 组合扫描正则无 caseSensitive → 大写标签不匹配（LLM 极少输出大写，不处理）

## 修复方案（全部在 lib/shared/widgets/markdown_with_highlight.dart）

### Fix A：`_convertInlineHtmlFormatting` 升级
- 内联正则改 `\b[^>]*` 容忍属性（`\b` 防止 `<b\b` 误食 `<br>`，已推演验证）
- 新增转换（顺序：br → 内联样式 → 标题 → 列表 → hr → blockquote → span剥离）：
  - `<h1-6 ...>` → ATX 标题（行锚定 `(^|\n)...(?=\n|$)`，反向引用 `\2` 配对闭合）
  - `<ul>/<ol>/<li>` → `- item`（ol 编号丢失，ponytail 上限注释）
  - `<hr>` → `---`；`<blockquote>` → 逐行 `> ` 前缀
  - `span/font/mark/sub/sup/small/center/section/article/header/footer/main/aside/figure/figcaption` → 剥标签留文本
- 加 `{bool inlineOnly = false}` 参数：表格单元格调用传 true（只转 b/i/s/code/br），防止标题标记注入表格单元格

### Fix B：StyledDivBlockMd 嵌套平衡模式
- 仿 `_detailsPattern`（L5693）写 `_divPattern(depth)` 递归平衡模式，深度 3
- expString：最外层开标签仍要求 `style="..."`（避免吞噬普通 `<div>` 文本）
- `build()` 提取正则 body 改贪婪 `[\s\S]*`（exp 已验证平衡 → 贪婪到最后一个 `</div>` 即正确配对）
- 内层 div 经现有 `MarkdownComponent.generate(body, config, true)` 递归渲染（组件表随 config 传递，与 DetailsHtmlMd 同机制）

### Fix C：CSS 解析补全
- 新增：`border` 简写（复用 `_extractBorderWidth/_extractBorderColor`）、`border-width/border-color`、`border-radius`
- 装饰优先级：border-left > 全 border > 无；radius 默认 8
- 无视觉属性（纯 layout 容器如 display:flex）时不加默认底色 → 外层容器透明，卡片各自成卡

## 阶段

| Phase | 内容 | 验收 |
|-------|------|------|
| 1 | Fix A 内联转换升级 | grep 可验证正则与函数签名 |
| 2 | Fix B 嵌套 div 平衡 | grep 可验证 _divPattern 存在且 build 用贪婪 body |
| 3 | Fix C CSS 补全 | grep 可验证 border-radius/border 解析 |
| 4 | Test + 文档 + 归档 + 提交 | flutter/dart 可用则 analyze 无 error，否则记录待设备验证 |

## 风险

- 流式安全：所有转换要求闭合标签，未闭合原样保留 —— 已推演，无风险
- 代码块内 HTML：转换在 mask 后执行，不受影响 —— 已有机制
- 增量流式（≥4096 字符按空行切块）时跨块 div 在流式期间暂不匹配，结束后正常 —— 可接受，不动切块器

## 关键决策

- 不引入新依赖；不动 gpt_markdown 包本身；不动增量切块器
- 大写 HTML 标签不处理（H5），记为已知限制
