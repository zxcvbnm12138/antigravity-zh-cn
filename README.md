# Antigravity 2.0 中文汉化包

面向 Windows 版 Google Antigravity 2.0.1 的可回滚中文汉化补丁。项目只修改 `resources\app.asar` 的注入层，不修改 `Antigravity.exe`、`language_server.exe` 或其他程序二进制。

## 当前状态

- 目标版本：Antigravity 2.0.1
- 汉化包版本：0.1.0
- 发布状态：当前功能已完成第一版归档
- 回滚方式：通过安装时生成的原始 `app.asar` 备份恢复
- 分发内容：脚本、运行时注入代码、翻译词库、文档；不分发官方应用二进制

## 汉化范围

已覆盖 Antigravity 自定义 UI 的高频区域：

- 主界面侧栏：新建会话、会话历史、计划任务、项目、设置等
- 设置页：账号、权限、外观、模型、自定义、浏览器、应用、会话等
- 设置子页面：文件权限、网络权限、终端命令、沙盒外命令、MCP 工具、浏览器执行规则
- Agent 面板：概览、审查、子智能体、产物、后台任务、已停止状态等
- 深层下拉项：安全预设、文件夹外访问策略、终端命令自动执行、产物审查策略、主题预设等
- 原生菜单：File、View、Window 等顶部菜单的常见项目

保留专有名称和开发工具术语，例如 `Gemini`、`MCP`、`Google Chrome`、`Catppuccin`、`Solarized`。

## 目录结构

```text
.
├── translations/
│   └── zh-CN.json                 # 唯一翻译源
├── src/
│   ├── ag-zh-cn-runtime.js        # DOM 运行时汉化逻辑
│   └── ag-zh-cn-native-menu.js    # 原生菜单汉化逻辑
├── scripts/
│   ├── install.ps1                # 安装并备份 app.asar
│   ├── uninstall.ps1              # 从备份回滚
│   └── verify.ps1                 # 静态校验补丁状态
├── ARCHIVE.md
├── RELEASE_NOTES.md
└── README.md
```

## 环境要求

- Windows PowerShell
- Node.js
- `npx.cmd`
- 已安装 Antigravity，默认路径为 `C:\Users\11720\AppData\Local\Programs\antigravity`

安装脚本会优先使用 `npx.cmd --yes @electron/asar`，失败时回退到 `npx.cmd --yes asar`。

## 安装

先关闭 Antigravity，然后在项目根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -InstallDir "C:\Users\11720\AppData\Local\Programs\antigravity"
```

安装过程会：

1. 检查 Antigravity 是否仍在运行。
2. 解包 `resources\app.asar`。
3. 备份原始 `app.asar` 到 `resources\antigravity-zh-cn\backups`。
4. 注入运行时汉化脚本和原生菜单补丁。
5. 重新打包 `app.asar`。
6. 写入 `resources\antigravity-zh-cn\manifest.json` 安装清单。

## 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1 -InstallDir "C:\Users\11720\AppData\Local\Programs\antigravity"
```

验证项包括：

- 翻译 JSON 可解析
- 运行时 JS 和菜单 JS 语法检查通过
- 备份文件存在
- `app.asar` 包含汉化标记和中文资源
- 当前 `app.asar` 哈希与 manifest 记录一致

## 卸载

先关闭 Antigravity，然后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -InstallDir "C:\Users\11720\AppData\Local\Programs\antigravity"
```

卸载脚本会按 manifest 记录恢复原始 `app.asar`，并校验恢复后的 SHA256。

## 翻译维护

新增或修正文案时优先修改 `translations\zh-CN.json`：

- `exact`：精确匹配的 UI 文案
- `patterns`：带数字、动态文本或大小写变化的正则替换
- `attributes`：`title`、`aria-label`、`placeholder` 等属性文案
- `nativeMenus`：Electron 原生菜单文案

运行时会跳过编辑器、终端、代码块、输入框值、WebView 和 iframe 等区域，避免误改用户文件内容、终端输出、路径和命令。

## 发布包

Release 压缩包应包含本仓库源码、脚本和文档，不包含：

- Antigravity 官方安装目录
- `app.asar`
- `Antigravity.exe`
- `language_server.exe`
- 用户本机备份文件

发布包生成后可直接解压，在项目根目录执行安装脚本。

## 免责声明

这是本机可回滚汉化补丁，不是 Antigravity 官方语言包。Antigravity 更新后可能覆盖 `app.asar`，重新运行安装脚本即可再次注入汉化补丁。
