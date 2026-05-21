# 项目归档

## 第一次归档 - 2026-05-21

Antigravity 2.0 中文汉化包第一版已完成，当前没有继续开发的必需功能。

### 完成范围

- 建立可回滚汉化包项目结构：`translations`、`src`、`scripts` 和文档。
- 实现 `install.ps1`：自动检查运行进程、备份原始 `app.asar`、注入汉化运行时和原生菜单补丁、重新打包并写入 manifest。
- 实现 `uninstall.ps1`：按 manifest 恢复原始 `app.asar` 并校验哈希。
- 实现 `verify.ps1`：校验翻译源、运行时语法、备份、补丁标记、中文资源和 manifest 哈希。
- 完成 Antigravity 自定义 UI 的深度汉化，包括设置页、设置子页、下拉菜单、权限规则、Agent 面板和主界面侧栏。
- 运行时已处理动态 DOM、portal/dropdown/modal，同时跳过编辑器、终端、代码块、输入框值、WebView 和 iframe。
- 修复 `.select-text` 区域中下拉项标题漏翻问题，例如 `Full Machine` 已能显示为 `整机访问`。

### 当前验证

已在本机 Antigravity 安装目录完成安装和验证：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -InstallDir "C:\Users\11720\AppData\Local\Programs\antigravity"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1 -InstallDir "C:\Users\11720\AppData\Local\Programs\antigravity"
```

验证结果：

- 翻译源 JSON 可由 Node.js 和 PowerShell 解析。
- `src\ag-zh-cn-runtime.js` 语法检查通过。
- `src\ag-zh-cn-native-menu.js` 语法检查通过。
- 安装后的 `app.asar` 包含汉化标记和中文资源。
- manifest 中记录的 patched SHA256 与当前 `app.asar` 一致。

### 恢复信息

- 本地仓库分支：`main`
- 本地发布标签：`v0.1.0`
- 计划远程仓库：`https://github.com/zxcvbnm12138/antigravity-zh-cn.git`
- 当前远程状态：GitHub 返回 `Repository not found`，需要先创建远程仓库后再 push。
- 默认安装目录：`C:\Users\11720\AppData\Local\Programs\antigravity`
- 备份目录：`C:\Users\11720\AppData\Local\Programs\antigravity\resources\antigravity-zh-cn\backups`
- 安装清单：`C:\Users\11720\AppData\Local\Programs\antigravity\resources\antigravity-zh-cn\manifest.json`
- 回滚命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -InstallDir "C:\Users\11720\AppData\Local\Programs\antigravity"
```

### 后续维护建议

- Antigravity 更新后重新运行安装脚本。
- 新发现英文 UI 时优先补充 `translations\zh-CN.json`。
- 不把官方 `app.asar` 或二进制文件提交到仓库或 release 包中。
