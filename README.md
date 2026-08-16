# Runly

**Run anything. Automatically.**

Runly 是一款面向开发者和 AI Agent 的 **macOS 原生菜单栏任务调度器**。把任意 CLI（`python`、`node`、`ffmpeg`、`git`、`claude`、`codex`、`items` …）变成可定时、可追踪、可通知的本地任务。

```text
Schedule → Execute → Log → Notify
```

> 100% 本地 · 无账号 · 无云同步 · Apple 原生 API · 无第三方依赖

---

## 功能一览

### 菜单栏优先（Menu Bar First）

- 常驻顶部菜单栏（SF Symbol 螺栓图标）
- 一眼查看：Running / Failed / Recent / Up Next
- 快捷操作：New Task · Run Task · Stop · Open Runly · Settings
- 失败任务可直接 View Logs / Run Again / Dismiss
- 默认不占 Dock（`LSUIElement`）

### 任务类型

| 类型 | 说明 |
| --- | --- |
| **Command** | 任意可执行文件 + 参数（一行一个参数） |
| **Script** | 脚本路径；可执行则直接跑，否则按扩展名选解释器（python3 / node / zsh …） |
| **Agent** | Claude / Codex / OpenClaw / Custom，最终仍落到 Executable + Arguments |

### 调度与执行

- **Schedule**：Once · Interval · Daily · Weekly · Cron（best-effort）
- **launchd**：每个任务对应 `~/Library/LaunchAgents/com.runly.task.<UUID>.plist`
- **Run Now**：立即执行，不改动原有日程
- **Timeout / Retry**：超时终止、失败重试
- **Stop**：停止当前进程；对 launchd 无界面任务尝试 `launchctl kill`

### 环境与代理

- 自定义 `KEY=VALUE` 环境变量
- GUI App 自动补齐常见 PATH（Homebrew 等），**不覆盖**用户已有 PATH
- 任务级 HTTP / HTTPS / SOCKS / NO_PROXY（只作用于当前 Process）

### 日志与通知

- 每次执行产生 `TaskRun` 元数据（SwiftData）
- 完整输出落盘：`~/Library/Application Support/Runly/Logs/<task-id>/`
  - 合并日志 `.log` + 分离 `.out.log` / `.err.log`
- 实时终端风格日志查看
- 系统通知（点击可跳到对应 Run）
- 可选自定义通知命令，支持模板变量

### 其它

- **Launch at Login**（`SMAppService`，与任务 launchd 独立）
- 主窗口 Dashboard：完整 CRUD、编辑 Schedule / Agent、历史与日志
- 编辑器提供 **Command Preview** 与 **Test Run**

---

## 系统要求

- macOS 14+
- Xcode 15+（完整 Xcode，不能只用 Command Line Tools）

---

## 快速开始

### 1. 克隆并打开

```bash
git clone git@github.com:hlpsxc/runly.git
cd runly
open Runly.xcodeproj
```

### 2. 运行

在 Xcode 中选择目标 **My Mac**，按 **⌘R**。

启动后请看菜单栏右侧的 **螺栓图标**（默认无 Dock 图标）。

### 3. 创建第一个任务

1. 点击菜单栏图标 → **+ New Task**（或 Open Runly → New Task）
2. 填写例如：

| 字段 | 示例 |
| --- | --- |
| Name | Hello Runly |
| Type | Command |
| Command | `echo` |
| Arguments（每行一个） | `hello from Runly` |
| Schedule | Interval · `Every day` |

3. 查看 **Command Preview**，可先点 **Test Run**
4. **Save**，然后在详情页或菜单栏 **Run Task** → 立即执行

### 4. Agent 示例

| 字段 | 示例 |
| --- | --- |
| Type | Agent |
| Provider | Claude |
| Executable | `claude` |
| Prompt | `分析 {{date}} 的 AI 新闻` |
| Working Directory | `~/Projects/AIResearch` |

模板变量：`{{date}}` `{{time}}` `{{task_name}}` `{{working_directory}}` `{{prompt}}`

### 5. 定时后台执行

保存并 **Enabled** 后，Runly 会写入 LaunchAgent。到点由 macOS 调用：

```text
Runly --run-task <UUID>
```

无需一直打开主窗口。

---

## 使用说明

### 参数写法

- **一行一个参数**，行内空格会保留（适合 Prompt）
- 主执行路径使用 `Foundation.Process` + 结构化 argv，**不会**把命令拼成 shell 字符串

```text
Command:  claude
Arguments:
-p
分析最近 3 天的模型变化
```

### PATH

GUI 启动时 PATH 往往与 Terminal 不同。Runly 会在现有 PATH **末尾追加**：

```text
/opt/homebrew/bin
/opt/homebrew/sbin
/usr/local/bin
/usr/bin
/bin
…
```

也可在任务 Environment 中自行设置 `PATH=...`。

### 代理（仅当前任务）

开启 Proxy 后写入进程环境，例如：

```text
HTTP_PROXY=http://127.0.0.1:7890
HTTPS_PROXY=http://127.0.0.1:7890
ALL_PROXY=socks5://127.0.0.1:7890
NO_PROXY=localhost,127.0.0.1
```

不会修改 macOS 系统全局代理。

### 通知

- 默认：任务结束发送系统通知
- 若填写 Notification Command：支持

```text
{{task_name}} {{status}} {{exit_code}} {{duration}} {{stdout}}
```

推荐多行 argv；含管道/重定向的一行命令会回退到 `zsh -lc`。

### 数据位置

| 内容 | 路径 |
| --- | --- |
| SwiftData | 应用沙盒外 Application Support（Runly 容器） |
| 日志 | `~/Library/Application Support/Runly/Logs/` |
| LaunchAgents | `~/Library/LaunchAgents/com.runly.task.<UUID>.plist` |

---

## 界面结构

```text
                 Runly
                   │
          ┌────────┴────────┐
          │                 │
      Menu Bar          Main Window
   看状态 / 快跑 / 处理失败    配置 / 历史 / 完整日志
          │                 │
          └────────┬────────┘
                   │
                AppState
                   │
     TaskService · RunService · launchd
```

---

## 项目结构

```text
Runly/
├── App/           # 入口、Settings、headless --run-task
├── Models/        # RunlyTask、TaskRun、枚举
├── Services/      # AppState、Executor、Logs、Notifications…
├── Scheduler/     # LaunchAgent 生成与 launchctl
├── Views/         # MenuBar、Dashboard、Editor、LogViewer
├── Utilities/     # PATH、模板、日程计算、环境解析
└── Resources/     # Info.plist、Entitlements、Assets
```

技术栈：Swift · SwiftUI · SwiftData · Foundation.Process · UserNotifications · launchd · SMAppService

---

## 已知限制

- Cron 的列表/范围/步长语法为 best-effort，映射到 launchd 日历字段
- 应用内同一时间只跑一个前台 RunSession（launchd 仍可另起进程）
- 带管道/重定向的通知命令可能走 shell
- 开发时若从 DerivedData 路径注册 LaunchAgent，重编译后路径会变；正式使用请固定安装位置或重新 Enable 任务

---

## 开发

```bash
# 建议将 CLI 指向完整 Xcode
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

open Runly.xcodeproj
# ⌘R
```

可选：用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 重新生成工程。

---

## License

MIT（若仓库后续补充 LICENSE 文件则以该文件为准）

---

**Runly — A native macOS scheduler for commands and AI agents.**
