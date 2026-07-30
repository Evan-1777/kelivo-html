# Project

> **本文件是项目的「单一事实来源」**，供 AI Agent 动手前快速建立全局认知。
>
> - **维护原则**：代码库变更后必须同步本文件——对照 §0 维护速查判断要改哪节，而非凭感觉。
> - **边界**：项目定位与设计原则见 `SCOPE.md`，工作流规则见 `AGENTS.md`，本文件不重复，仅在需要处引用。
> - **填写约定**：带 `<!-- 待填 -->` 为占位项，写完即删注释；标 `（可选）` 的节若无内容请**整节删除**（勿留空节）；`★` 标记易错点。

## 0. 维护速查

> 代码库变更后，按下表定位需同步更新的章节。未列出的变更类型默认无需改本文件。

| 变更类型 | 需更新章节 |
|----------|-----------|
| 新增 / 升级 / 移除库依赖 | §2 环境与运行（属关键选型时另记 §8） |
| 新增 / 重构 / 删除模块 | §3 目录结构、§4 架构与数据流 |
| 调整命名 / 编码 / 日志规范 | §5 关键约定 |
| 踩到新坑或确立新约束 | §6 约束与已知坑 |
| 引入 / 切换 / 下线外部服务或脚本 | §7 外部依赖与集成 |
| 关键技术选型定型 | §8 决策记录 |
| 引入项目特有名词 | §9 术语表 |
| 运行 / 启动 / 测试方式变化 | §2 环境与运行 |

## 1. 概述

- **一句话定位**：跨平台 LLM 聊天客户端，聚合多种 AI 提供商，支持对话、文件、工具、搜索、语音和自定义助手。
- **当前阶段**：开发中（v1.1.17+61）
- **非目标（不做什么）**：不构建自有 AI 模型、不替代 LLM 提供商原生平台、不做企业级团队协作。

## 2. 环境与运行

> AI 最易踩坑处。所有「换台机器就不一样」的前提都写在这里。

- **运行平台**：Android / iOS / Windows / macOS / Linux，全平台 Flutter 应用
  - ★ 易错：跨平台差异——路径分隔符（`/` vs `\`）、文件选择器各平台行为不同、桌面端需 bitsdojo_window 与 window_manager 处理窗口
- **Shell**：PowerShell（Windows 默认） / bash（macOS/Linux）
  - ★ 易错：路径含中文/空格须加引号
- **版本管理**：Git，master 分支；提交风格以 fix/feat/perf 前缀为主
- **语言 / 运行时**：
  - Dart SDK ^3.12.1
  - Flutter >=3.44.1
- **依赖管理**：`pubspec.yaml`（根目录）；本地依赖路径：`./dependencies/`（mcp_client、flutter_tts、tray_manager、gpt_markdown、downsize 等）
- **如何运行**：
  - `flutter run`（开发运行，选择目标设备）
  - `flutter build <platform>`（构建产物）
  - ★ 易错：首次运行须 `flutter pub get`；Windows 构建需 bitsdojo_window 的 C++ 编译环境；iOS 构建需 Xcode
- **如何测试**：
  - `flutter test`（单元测试）
  - `flutter test integration_test/`（集成测试）
  - 手动验证：修改后跑 `flutter build` / `flutter run` 确认无编译错误

## 3. 目录结构与模块职责

> 让 AI 无需全盘扫描即可定位代码。仅列关键文件/目录，一行说清职责。

```
Kelivo-html/
├── .docs/                      # 工作流文档（Project.md, Plan.md, Tasks.md）
│   ├── SCOPE.md                # 项目定位与设计原则
│   ├── Project.example.md      # Project.md 模板
│   ├── Plan.example.md         # Plan.md 模板
│   └── Tasks.example.md        # Tasks.md 模板
├── .pi/agents/                 # pi 工作流 agent 定义
├── lib/                        # 主源码
│   ├── main.dart               # 应用入口，Provider 注册与路由初始化
│   ├── core/                   # 核心层（业务无关/跨模块）
│   │   ├── database/           # Drift/SQLite 数据库：表定义、迁移、仓库、网关
│   │   ├── models/             # 数据模型：对话/消息/助手/标签等实体
│   │   ├── providers/          # 全局状态 Provider：设置/助手/模型/MCP 等
│   │   ├── services/           # 核心服务：API 通信/聊天/备份/存储/TTS/搜索/MCP
│   │   │   ├── api/providers/  # 各 AI 提供商 API 适配器
│   │   │   ├── chat/           # 聊天服务、文档提取、提示词转换
│   │   │   ├── backup/         # 备份与恢复核心逻辑
│   │   │   ├── mcp/            # MCP 工具服务
│   │   │   ├── search/         # 搜索引擎适配器
│   │   │   ├── storage/        # 本地存储抽象
│   │   │   └── tts/            # TTS 语音服务
│   │   └── utils/              # 核心工具函数
│   ├── features/               # 功能模块（按业务拆分）
│   │   ├── assistant/          # 助手管理
│   │   ├── backup/             # 备份 UI 与流程
│   │   ├── chat/               # 聊天页面、模型/组件/工具
│   │   ├── home/               # 首页入口
│   │   ├── mcp/                # MCP 工具配置 UI
│   │   ├── migration/          # Hive → SQLite 迁移
│   │   ├── model/              # 模型选择与配置
│   │   ├── provider/           # 提供商配置
│   │   ├── search/             # 搜索页面
│   │   ├── settings/           # 设置页面
│   │   ├── scan/               # 扫码功能
│   │   ├── stats/              # 使用统计
│   │   ├── translate/          # 翻译功能
│   │   ├── world_book/         # World Book（世界书）功能
│   │   ├── quick_phrase/       # 快捷短语
│   │   └── instruction_injection/ # 指令注入
│   ├── shared/                 # 共享组件
│   │   ├── widgets/            # 通用 Widget 组件库
│   │   ├── pages/              # 通用页面（如关于/许可）
│   │   ├── dialogs/            # 通用对话框
│   │   ├── animations/         # 共享动画
│   │   ├── cache/              # 缓存层
│   │   └── responsive/         # 响应式布局适配
│   ├── desktop/                # 桌面端专属代码（窗口/托盘/快捷键）
│   ├── theme/                  # Material 3 主题（动态颜色、调色板、字体）
│   ├── utils/                  # 通用工具函数
│   ├── secrets/                # 密钥/敏感配置管理
│   ├── icons/                  # 自定义图标
│   └── l10n/                   # 本地化（英/中）
├── assets/                     # 静态资源（图标、HTML渲染模板、mermaid.js）
├── dependencies/               # 本地 fork 依赖包
│   ├── mcp_client/
│   ├── flutter_tts/
│   ├── tray_manager/
│   ├── gpt_markdown/
│   ├── downsize/
│   └── flutter-permission-handler/
├── test/                       # 单元测试
├── integration_test/           # 集成测试
├── docs/                       # 项目文档/截图
├── docx/                       # 文档资源（截图等）
├── drift_schemas/              # Drift 迁移 Schema 版本快照
└── tool/                       # 开发工具脚本
```

## 4. 架构与数据流

- **核心模块**：

  | 模块 | 职责 | 对外接口 |
  |------|------|---------|
  | `core/database/` | Drift/SQLite ORM，包含对话库与业务数据库 | `AppDatabase`、`ChatDatabaseGateway`、`BusinessRepository` |
  | `core/models/` | 数据实体定义（Conversation, ChatMessage, Assistant 等） | 纯 Dart 数据类，含 JSON 序列化 |
  | `core/providers/` | Provider 状态管理，全局单例 | ChangeNotifier 派生类，通过 `context.read/watch` 访问 |
  | `core/services/api/` | AI 提供商 API 适配层 | `ChatApiService`，各 provider 适配器实现标准接口 |
  | `core/services/chat/` | 聊天逻辑编排 | `ChatService` — 消息发送、流式响应、工具调用编排 |
  | `core/services/backup/` | 备份与恢复引擎 | 导出/导入业务流程，含加密与校验 |
  | `core/services/search/` | 搜索引擎适配 | 多引擎统一接口（Bing, DuckDuckGo, Exa, Tavily 等） |
  | `core/services/mcp/` | MCP 工具调用服务 | 工具发现、调用、结果处理 |
  | `features/chat/` | 聊天 UI | 消息列表、输入栏、Markdown 渲染、附件的页面组件 |
  | `theme/` | Material 3 动态颜色主题 | `ThemeFactory` 根据调色板 + 亮度生成 ThemeData |

- **数据流**：
  ```
  用户输入 → ChatService → ChatApiService → AI Provider API
       ↓                                            ↓
   流式响应 ← ChatApiService ←── SSE/Stream ────────┘
       ↓
   ChatMessage 写入 Drift/SQLite (ChatDatabaseGateway)
       ↓
   Provider 通知 → UI 重建 (Consumer/Selector)
  ```

- **模块依赖**：
  - `features/*` → `core/providers/` → `core/services/` → `core/database/`、`core/models/`
  - `core/` 内部：`services/` → `database/`、`models/`、`utils/`
  - `shared/widgets/` ← 被所有 `features/*` 引用
  - `theme/` ← 被 `main.dart` 引用，无反向依赖
  - ★ 易错：`features/` 之间禁止互相依赖；跨模块复用走 `shared/` 或 `core/`

## 5. 关键约定

- **命名约定**：
  - Dart：小驼峰（`camelCase`）函数/变量，大驼峰（`PascalCase`）类/枚举
  - 文件：全小写蛇形（`snake_case.dart`）
  - Flutter Widget：`XxxPage` / `XxxWidget` / `XxxCard`
  - Provider：`XxxProvider`（ChangeNotifier 子类）
  - Service：`XxxService`
- **注释 / 文档语言**：
  - 用户面向（UI 文案、README、发布说明）：中文（主） / 英文
  - 代码内部注释、文档字符串：英文
  - ★ 易错：与 `AGENTS.md` 的「用户面中文 / 内部英文」对齐
- **错误处理 / 日志方式**：
  - 使用 `logging` 包（`package:logging`）
  - provider 层异常通过 `ChangeNotifier` 状态字段暴露，UI 层消费展示

## 6. 约束与已知坑

- `dependencies/flutter_tts/` 为本地 fork，涉及原生 TTS 适配，修改须谨慎——原因：非标准 pub 依赖，无自动版本管理
- `dependencies/mcp_client/` 为本地 fork 的 MCP 客户端协议——原因：上游未稳定，fork 适配特定需求
- `pubspec.yaml` 中 `enable-swift-package-manager: false`——原因：iOS 插件依赖 CocoaPods 尚未兼容 SPM 依赖图
- `permission_handler_windows` 通过 `dependency_overrides` 使用本地 fork——原因：上游 Windows 持续位置访问有已知 bug
- `assets/mermaid.min.js` 用于 Markdown 渲染中的 Mermaid 图——原因：WebView 内执行 JS 渲染
- CI workflow 的 `FLUTTER_VERSION` 须 >= pubspec 的 `flutter` 下限（当前 `>=3.44.1` / Dart `^3.12.1`）——原因：低于下限会导致 `flutter pub get` 版本解析失败；`build-stable*.yml`、`build-linux-arm64.yml` 已统一至 3.44.8

## 7. 外部依赖与集成（可选）

- **第三方服务 / API**：
  - AI 提供商 API：OpenAI、Google Gemini、Anthropic、SiliconFlow 等（凭据由用户在 UI 中配置，存本地）
  - 搜索引擎：Bing、DuckDuckGo、Exa、Tavily、Zhipu、LinkUp、Brave、Metaso、SearXNG、Ollama、Jina、Perplexity、Bocha、Serper、Grok
  - TTS 语音：系统 TTS + OpenAI / Google Gemini / ElevenLabs
  - Apple App Store：上架渠道（ID: 6752122930）
- **本地工具脚本**：`tool/` 目录下的开发辅助脚本

## 8. 决策记录（可选）

- 2025-01（推定）选择 Drift（SQLite）而非仅用 Hive——理由：需要关系查询与迁移支持；Hive 保留用于 KV 存储场景
- 2025-01（推定）使用 Provider 而非 Riverpod/Bloc——理由：复杂度适中，项目初期选型延续
- 2025-01（推定）本地 fork 关键依赖（mcp_client、flutter_tts、tray_manager）——理由：上游不满足定制需求，或不稳定

## 9. 术语表（可选）

- **MCP** = Model Context Protocol，模型工具调用协议
- **World Book** = 世界书，用于注入角色/世界观上下文提示词
- **Instruction Injection** = 指令注入，在对话中动态插入系统指令
- **Drift** = Dart 版 SQLite ORM（原 Moor）
- **TTS** = Text-to-Speech，文本转语音
