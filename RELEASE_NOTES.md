# Release Notes

## v0.1.0 - 2026-05-21

Antigravity 2.0 中文汉化包第一版。

### Highlights

- 提供可回滚安装、卸载和验证脚本。
- 覆盖主界面、设置页、设置子页、Agent 面板、权限规则和常见下拉菜单。
- 支持 Electron 原生菜单常见项汉化。
- 运行时通过 DOM 文本和属性翻译动态 UI。
- 避免翻译用户文件内容、终端输出、代码块、输入框值、路径和命令。
- 保留 `Gemini`、`MCP`、`Google Chrome`、`Catppuccin`、`Solarized` 等专有名称。

### Installation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -InstallDir "C:\Users\11720\AppData\Local\Programs\antigravity"
```

### Verification

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1 -InstallDir "C:\Users\11720\AppData\Local\Programs\antigravity"
```

### Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -InstallDir "C:\Users\11720\AppData\Local\Programs\antigravity"
```

### Distribution Notes

Release artifact contains only the localization project files. It does not include Antigravity official binaries or a repacked `app.asar`.
