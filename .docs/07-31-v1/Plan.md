# Plan：修复 CI 构建 Flutter/Dart SDK 版本不匹配

**状态**：DONE  
**日期**：2026-07-31  
**版本**：v1.0  
**回归测试结论**：YAML 语法校验通过，本地 `flutter pub get` 解析正常；CI 真实验证需重跑受影响 workflow_dispatch。

---

## 1. 背景与目标

`pubspec.yaml` 近期将约束提升为 `sdk: ^3.12.1` / `flutter: ">=3.44.1"`（commit `ff1cabf1`），但多个 CI workflow 仍使用低于该下限的 Flutter 版本，导致 `flutter build apk` 在依赖解析阶段失败（`version solving failed`）。

报错中的 Dart 3.9.2 对应 Flutter 3.35.7（即 `build-stable.yml`）。Flutter→Dart 映射（官方确认 3.44 = Dart 3.12）：3.35→3.9、3.38→3.10、3.41→3.11，均低于 `^3.12.1`。

目标：将所有低于 `3.44.1` 下限的 workflow 统一提升至 `3.44.8`（pub 建议、真实发布的热修复版），消除全部同类失败。

## 2. 阶段划分

### Phase 1：提升受影响 workflow 的 Flutter 版本

| 项目 | 内容 |
|------|------|
| **输入** | 5 个使用旧 Flutter 的 workflow 文件 |
| **输出** | 各文件 `FLUTTER_VERSION` 提升至 `3.44.8` |
| **验收标准** | 5 个文件 `FLUTTER_VERSION: '3.44.8'`，YAML 语法不变；不触及已满足约束的 workflow |

## 3. 架构决策

| 决策项 | 选择 | 理由 | 替代方案（为何不选） |
|--------|------|------|----------------------|
| 目标版本 | 3.44.8 | pub 建议值，真实发布的热修复版，bundled Dart 3.12.x 满足 `^3.12.1` | 3.44.6（已用于 build-stable-44/pr-check，但用户明确选择 3.44.8） |
| 修复范围 | 全部 5 个受影响 workflow | 用户选择「修全部」，一次性消除同类失败 | 仅修报错的 build-stable.yml（会遗留 4 个潜在失败） |
| 是否删除/改名旧版本 workflow | 否 | 用户未选删除方案；改名文件会丢失 Actions 运行历史 | 删除 3.35/3.38/3.41 固定版本 workflow（超出本次范围） |

## 4. 风险清单

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 3.44.8 在 ARM64 runner（build-linux-arm64）可用性 | 🟢 低 | subosito/flutter-action 从官方 archive 拉取，3.44.8 已发布 |
| 版本固定 workflow 名称与实际版本不符（如「Build Stable 3.41」实跑 3.44.8） | 🟡 中 | 仅改 env 变量；`name:`/文件名保留以维持运行历史，后续可单独清理 |
| 受影响清单遗漏 | 🟢 低 | 已逐一核验 8 个 workflow，确认仅 5 个低于下限 |

## 5. Phase 依赖关系

```
Phase 1（单一阶段，无后续）
```

> 受影响文件（仅改 `FLUTTER_VERSION` env 行）：
> `build-stable.yml`、`build-stable-38.yml`、`bulid-stable-38-new.yml`、`build-stable-41.yml`、`build-linux-arm64.yml`
