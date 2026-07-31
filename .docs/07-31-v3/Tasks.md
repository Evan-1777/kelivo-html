# Tasks：Flutter 构建错误修复

**关联流程**：Quick
**目标**：修复 Markdown HTML 片段渲染相关的 Dart 编译错误，保持现有 WebView 混合渲染行为不变。
**总计 Task**：3 个

---

## TASK-001：补充平台 API 导入

- **Status**：DONE
- **Priority**：P0
- **Description**：在 `lib/shared/widgets/markdown_with_highlight.dart` 中显式导入 `defaultTargetPlatform` 所属的 Flutter foundation API。
- **Details**：
  - 仅增加 `package:flutter/foundation.dart` 的精确符号导入。
  - 保持 `StyledDivBlockMd` 的平台判断和其他渲染逻辑不变。
- **Acceptance Criteria**：
  - 执行 `rg "defaultTargetPlatform" lib/shared/widgets/markdown_with_highlight.dart` 能找到调用。
  - 执行 `rg "foundation.dart.*defaultTargetPlatform|defaultTargetPlatform.*foundation.dart" lib/shared/widgets/markdown_with_highlight.dart` 能找到对应导入。

## TASK-002：移除不存在的 WebViewController 释放调用

- **Status**：DONE
- **Priority**：P0
- **Description**：从 `lib/shared/widgets/html_fragment_view.dart` 的 State dispose 流程中移除 `WebViewController.dispose()` 调用，以兼容当前 `webview_flutter` 4.x API。
- **Details**：
  - 保留 State 自身的 `super.dispose()` 调用。
  - 不新增依赖、不改变 WebView 加载、桥接或高度计算逻辑。
- **Acceptance Criteria**：
  - 执行 `rg "_controller\\?\\.dispose|WebViewController.*dispose" lib/shared/widgets/html_fragment_view.dart` 无匹配。
  - 执行 `rg "super\\.dispose\\(\\)" lib/shared/widgets/html_fragment_view.dart` 能找到 State 生命周期释放调用。

## TASK-003：执行轻量验证并维护项目约束

- **Status**：DONE
- **Priority**：P1
- **Description**：对两个修改文件执行 Dart 格式检查，并在 `.docs/Project.md` 记录 `webview_flutter` 4.x 控制器生命周期约束。
- **Details**：
  - 按项目约束不运行本机 Flutter/Gradle 构建；构建结果由 GitHub Actions 验证。
  - 使用 `dart format --output=none --set-exit-if-changed` 检查修改文件格式。
  - 更新 `.docs/Project.md` 的已知坑，说明 `WebViewController` 不提供 `dispose()`，由插件管理生命周期。
- **Acceptance Criteria**：
  - `dart format --output=none --set-exit-if-changed lib/shared/widgets/markdown_with_highlight.dart lib/shared/widgets/html_fragment_view.dart`：当前环境无 `dart` 命令，未执行；GitHub Actions 负责最终 Flutter release 构建验证。
  - `rg "WebViewController.*dispose|生命周期" .docs/Project.md` 能找到该约束记录。
  - `git -c core.whitespace=cr-at-eol diff --check` 通过；源码匹配确认平台导入存在、`WebViewController.dispose()` 调用不存在、State 的 `super.dispose()` 保留。
  - GitHub Actions 的 Flutter release 构建应不再出现本次两个 Dart 编译错误。

## 验证结论

- 完成日期：2026-07-31
- 本地未运行 Flutter/Gradle 构建，遵循项目 `SCOPE.md` 的云端构建约束。
- `dart format` 因当前环境缺少 Dart SDK 未执行；`git -c core.whitespace=cr-at-eol diff --check` 与目标源码检查通过。
