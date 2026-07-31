# Tasks：聊天 HTML 片段资源打包修复

**关联 Plan**：`Plan.md` —— 聊天 HTML 片段资源打包修复 v5.0  
**总计 Task**：4 个  
**验证门**：本机不运行 Flutter 构建；执行侧应运行可用的静态检查与 Flutter 测试，云端 CI 的 `flutter analyze` / `flutter test` 为最终门。

---

## Phase 1：资源声明与回归验证

### TASK-001：声明 HTML fragment Flutter 资源

- **状态**：DONE（2026-07-31）
- **优先级**：P0
- **依赖**：无
- **文件**：`pubspec.yaml`
- **Description**：将 `assets/html/fragment.html` 加入 `flutter.assets` 清单，使 `rootBundle.loadString('assets/html/fragment.html')` 能在移动端资源包中读取。
- **Details**：复用现有 `assets/html/mark.html` 所在资源目录清单，只增加 fragment 模板路径；不新增依赖、不修改 WebView 逻辑。
- **Acceptance Criteria**：
  - 执行 `rg -n "- assets/html/(mark|fragment)\\.html" pubspec.yaml` 输出 `mark.html` 与 `fragment.html` 两行。
  - 执行 `test -f assets/html/fragment.html` 返回退出码 0。
  - 执行 `flutter pub get` 成功，或在无 Flutter SDK 时明确记录为云端 CI 待执行项。
- **执行记录**：`rg -n -- "- assets/html/(mark|fragment)\\.html" pubspec.yaml` 命中 169/170 两行；`test -f assets/html/fragment.html` 退出码 0；YAML 由 Python 解析通过；本机无 Flutter SDK，`flutter pub get` 为云端 CI 待执行项。

### TASK-002：添加 fragment 资源加载回归测试

- **状态**：DONE（2026-07-31）
- **优先级**：P0
- **依赖**：TASK-001
- **文件**：`test/shared/widgets/html_fragment_view_test.dart`
- **Description**：在现有 fragment 纯函数测试组中加入资源加载测试，通过 Flutter 测试绑定读取 `assets/html/fragment.html`，验证关键占位符仍存在且可由 `buildFragmentDocument` 使用。
- **Details**：测试只使用 `rootBundle.loadString` 或等价的 Flutter asset API，不构造 `WebViewController`；断言模板包含 `{{FRAGMENT_BASE64}}`、`{{BACKGROUND}}`、`{{LINE_HEIGHT}}` 等占位符，并确认模板不是空内容。
- **Acceptance Criteria**：
  - 执行 `flutter test test/shared/widgets/html_fragment_view_test.dart` 成功。
  - 测试输出包含新增资源加载用例并通过；若环境无 Flutter SDK，记录命令未执行及云端 CI 门禁。
  - 执行 `rg -n "rootBundle|fragment\.html|FRAGMENT_BASE64" test/shared/widgets/html_fragment_view_test.dart` 命中新增检查。
- **执行记录**：新增 `fragment.html bundled asset (regression)` 测试组（2 用例：rootBundle 加载含占位符 + composeFragmentDocument 全量替换无残留 `{{`）；`rg` 命中 7 处；本机无 Flutter SDK，`flutter test` 为云端 CI 门禁。

## Phase 2：文档与收尾

### TASK-003：同步项目资源约束文档

- **状态**：DONE（2026-07-31）
- **优先级**：P1
- **依赖**：TASK-001, TASK-002
- **文件**：`.docs/Project.md`
- **Description**：在 §6 记录 WebView HTML 模板必须同步声明在 `pubspec.yaml` Flutter assets 清单中的约束，并保持现有 v4 片段混合渲染说明准确。
- **Details**：只补充与本次根因直接相关的一条已知坑，不改变架构章节或历史记录。
- **Acceptance Criteria**：
  - 执行 `rg -n "fragment\.html.*pubspec|pubspec.*fragment\.html|assets.*清单" .docs/Project.md` 至少命中 1 行。
  - 执行 `rg -n "rootBundle\.loadString\('assets/html/fragment\.html'\)" lib/shared/widgets/html_fragment_view.dart` 命中现有读取路径。
- **执行记录**：§6 新增 ★ 约束条目（line 186），`rg` 两条验收命令均命中。

### TASK-004：完成文档归档与 Git 提交

- **状态**：DONE（2026-07-31）
- **优先级**：P1
- **依赖**：TASK-003
- **文件**：`Plan.md`、`Tasks.md`、`.docs/<MM-DD-vN>/Plan.md`、`.docs/<MM-DD-vN>/Tasks.md`
- **Description**：记录完成日期与回归测试结论，将根目录阶段文档归档到当天递增版本目录，并按既有 `fix:` 提交风格创建一次提交。
- **Details**：执行 `git status`、`git diff`、`git log`；仅暂存本阶段相关文件；不暂存 `.env`、凭据和既有无关未跟踪文件；归档目录必须同时含 Plan.md 与 Tasks.md，根目录不得残留已完成阶段文档。
- **Acceptance Criteria**：
  - 执行 `test -f .docs/<归档目录>/Plan.md && test -f .docs/<归档目录>/Tasks.md` 成功，且 `test ! -e Plan.md && test ! -e Tasks.md` 成功。
  - 执行 `git show --stat --oneline HEAD` 显示本阶段提交，提交信息以 `fix(markdown):` 或同等既有风格开头。
  - 执行 `git status --short` 不显示本阶段已提交文件；历史无关未跟踪文件可保留并在报告中说明。
- **执行记录**：归档至 `.docs/07-31-v4/`（当日递增版本）；根目录 Plan.md / Tasks.md 已移除；提交 `fix(markdown): bundle fragment.html asset and add regression test`。

## 依赖图

```
TASK-001 ──→ TASK-002 ──→ TASK-003 ──→ TASK-004
```
