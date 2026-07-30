# Tasks：修复 CI 构建 Flutter/Dart SDK 版本不匹配

**关联 Plan**：`Plan.md` —— 修复 CI 版本不匹配 v1.0  
**总计 Task**：5 个（每 Task 对应一个 workflow 文件的单行 env 修改）

---

## Phase 1：提升受影响 workflow 的 Flutter 版本

### TASK-001：build-stable.yml 提升至 3.44.8

- **Status**：DONE
- **Description**：将 `.github/workflows/build-stable.yml` 第 4 行 `FLUTTER_VERSION` 由 `3.35.7` 改为 `3.44.8`。
- **Details**：
  - 仅修改 env `FLUTTER_VERSION` 行；`channel: stable` 与其余步骤不变
  - 此文件为本次报错（Dart 3.9.2）的直接来源
- **Acceptance Criteria**：
  - `grep "FLUTTER_VERSION" .github/workflows/build-stable.yml` 输出 `'3.44.8'`

### TASK-002：build-stable-38.yml 提升至 3.44.8

- **Status**：DONE
- **Description**：将 `.github/workflows/build-stable-38.yml` 第 4 行 `FLUTTER_VERSION` 由 `3.38.5` 改为 `3.44.8`。
- **Details**：仅修改 env 行；3.38→Dart 3.10 不满足 `^3.12.1`
- **Acceptance Criteria**：
  - `grep "FLUTTER_VERSION" .github/workflows/build-stable-38.yml` 输出 `'3.44.8'`

### TASK-003：bulid-stable-38-new.yml 提升至 3.44.8

- **Status**：DONE
- **Description**：将 `.github/workflows/bulid-stable-38-new.yml` 第 4 行 `FLUTTER_VERSION` 由 `3.38.4` 改为 `3.44.8`。
- **Details**：仅修改 env 行（注意文件名拼写为 `bulid`）
- **Acceptance Criteria**：
  - `grep "FLUTTER_VERSION" .github/workflows/bulid-stable-38-new.yml` 输出 `'3.44.8'`

### TASK-004：build-stable-41.yml 提升至 3.44.8

- **Status**：DONE
- **Description**：将 `.github/workflows/build-stable-41.yml` 第 4 行 `FLUTTER_VERSION` 由 `3.41.2` 改为 `3.44.8`。
- **Details**：仅修改 env 行；3.41→Dart 3.11 不满足 `^3.12.1`
- **Acceptance Criteria**：
  - `grep "FLUTTER_VERSION" .github/workflows/build-stable-41.yml` 输出 `'3.44.8'`

### TASK-005：build-linux-arm64.yml 提升至 3.44.8

- **Status**：DONE
- **Description**：将 `.github/workflows/build-linux-arm64.yml` 第 4 行 `FLUTTER_VERSION` 由 `3.38.4` 改为 `3.44.8`。
- **Details**：仅修改 env 行；ARM64 runner 同样从官方 archive 拉取
- **Acceptance Criteria**：
  - `grep "FLUTTER_VERSION" .github/workflows/build-linux-arm64.yml` 输出 `'3.44.8'`
