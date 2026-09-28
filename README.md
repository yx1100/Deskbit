# Deskbit（个人版）

<p align="center">
  <img src="Assets/Deskbit-icon.png" width="128" alt="Deskbit app icon">
</p>

<p align="center">一款轻量、原生的 macOS 桌面便签应用，仅支持 Apple Silicon。</p>

本仓库 fork 自 [tonyjianchina/Deskbit](https://github.com/tonyjianchina/Deskbit)，在原版基础上改成个人专用版本：

- 只构建 Apple Silicon（arm64）版本，不再支持 Intel Mac
- 支持 Markdown 语法、图片和链接
- 全局快捷键一键新建便签（默认 `⌃⌥⌘空格`，可在偏好设置中修改）
- 移除了用户反馈功能和多语言切换，界面固定为简体中文

便签内容只保存在本机，无需账号，也不会上传到服务器。

## 系统要求

- macOS 11 Big Sur 或更高版本
- Apple Silicon Mac（M 系列芯片）

## 主要功能

- 黄色、蓝色、绿色和粉色四种便签配色
- Markdown：标题、粗体、斜体、删除线、行内代码、链接、列表、待办
- 图片：粘贴、拖入或通过底栏按钮插入，自动缩小以适应便签
- 链接：`⌘K` 插入或编辑链接，输入或粘贴的网址会自动识别，点击即可打开
- 全局快捷键，在任何应用中一键新建便签
- 开机自启动（偏好设置中开启，需要 macOS 13 或更高版本）
- 多级项目符号，以 `•`、`∘`、`▪` 区分层级
- 在 Finder 桌面框选多张便签后整组移动、置顶或取消置顶
- 自动排列全部便签，或只排列当前框选的便签
- 未置顶时使用普通窗口层级；置顶后可跨桌面空间显示
- 历史便签面板，可恢复已完成内容或将其永久删除
- 自动保存富文本、图片、颜色、窗口位置和置顶状态

## 使用方法

### 全局快捷键

- 默认 `⌃⌥⌘空格`（Control + Option + Command + 空格）：在任何地方新建便签并直接开始输入。
- 修改：点击菜单栏 Deskbit 图标 → 偏好设置…（`⌘,`），点击快捷键输入框后按下新的组合键。
  - 组合键必须包含 `⌘`、`⌥` 或 `⌃` 中的至少一个
  - `Esc` 取消录制，`Delete` 清除快捷键（即关闭全局快捷键）
  - “恢复默认”回到 `⌃⌥⌘空格`
- 基于系统热键接口实现，不需要授予“辅助功能”权限。

### 开机自启动

- 菜单栏 Deskbit 图标 → 偏好设置… → 勾选“登录 Mac 时自动启动 Deskbit”。
- 建议先把 `Deskbit.app` 放进“应用程序”文件夹再开启：登录项记录的是 App 所在位置，放在构建目录里重新构建后可能失效。
- 如果系统要求确认，点“打开系统设置…”，在“通用 → 登录项”中允许 Deskbit。

### 菜单栏

- 菜单栏只显示 Deskbit 图标，点击打开菜单。
- “显示所有便签”（`⌘0`）：把所有便签移到当前桌面并放到最前面，包括留在其他桌面（空间）或已断开显示器上的便签。

### 便签窗口

- 拖动顶部导航栏空白区域：移动便签。
- 拖动窗口边缘：调整便签大小。
- 点击颜色圆点：切换便签颜色。
- 点击 `+`：在当前便签附近、同一块显示器上新建便签。
- 点击图钉：置顶或取消置顶。
- 点击对勾：完成当前便签并移入历史。
- 点击左上角排列图标：在主屏幕自动排列，每列最多 4 张。

### 历史便签

- 每条历史记录显示原颜色、内容摘要和完成时间。
- 点击“恢复”会将便签重新放回桌面，并以普通未置顶窗口打开。
- 单条永久删除和“清空历史”都会在操作前再次确认。
- 从 macOS 菜单栏打开“历史便签”；点击列表外任意位置即可收起。

### 编辑与快捷键

支持选中文字后剪切、复制和粘贴：`⌘X`、`⌘C`、`⌘V`，`⌘A` 可全选。

| 功能 | 按钮 | 快捷键 | Markdown |
| --- | --- | --- | --- |
| 标题 | — | — | 行首输入 `# `、`## `、`### ` |
| 加粗 | 底栏 `B` | `⌘B` | `**文本**` |
| 斜体 | — | — | `*文本*` |
| 删除线 | — | — | `~~文本~~` |
| 行内代码 | — | — | `` `代码` `` |
| 链接 | 底栏链接图标 | `⌘K` | `[文字](https://example.com)` |
| 图片 | 底栏图片图标 | `⌘V` 粘贴 | 也可从 Finder 或浏览器拖入 |
| 项目符号 | 底栏列表图标 | `⌘⇧8` | 行首输入 `- ` 或 `* ` |
| 待办事项 | 底栏待办图标 | `⌘⇧X` | 行首输入 `- [ ] ` 或 `- [x] ` |
| 增加项目层级 | — | `Tab` | — |
| 减少项目层级 | — | `Shift+Tab` | — |

Markdown 语法在输入或粘贴时自动转换为对应格式。在标题行末尾按回车会回到正文样式。拖入非图片文件时会插入指向该文件的链接。

## 数据与隐私

- 数据保存在 `~/Library/Application Support/Deskbit/notes.json`。
- 含图片的便签以 RTFD 格式保存；图片插入时会缩小到最长边 1600 像素，以控制文件大小。
- 快捷键设置保存在 `UserDefaults` 中。
- Deskbit 没有账号、云同步、广告、遥测或任何网络请求。

建议升级或更换电脑前备份上述 `notes.json` 文件。

## 从源码构建

在 Apple Silicon Mac 上安装 Xcode Command Line Tools 后执行：

```bash
git clone https://github.com/yx1100/Deskbit.git
cd Deskbit
./scripts/build-app.sh
open "dist/Deskbit.app"
```

构建脚本生成仅包含 arm64 架构的 `dist/Deskbit.app`。

如需生成 DMG 安装包：

```bash
MARKETING_VERSION=1.3.0 BUILD_NUMBER=6 ./scripts/build-app.sh
./scripts/make-dmg.sh 1.3.0
```

### 运行检查

```bash
./scripts/build-app.sh
for test_script in scripts/test-*.sh; do "$test_script"; done
swift build
```

## 项目结构

```text
Sources/Deskbit/   应用源码
Tests/             功能检查程序
Tools/             图标生成工具
scripts/           构建与测试脚本
Casks/             Homebrew Cask
.github/workflows/ 自动发布流程
```

## 发布维护

发布工作流由 `vX.Y.Z` 标签或 GitHub Actions 手动触发。它会运行检查、构建 arm64 App、生成 ZIP 和 DMG、创建 GitHub Release，并更新 Homebrew Cask。

## 许可证

本项目使用 [MIT 许可证](LICENSE)，原作者为 tonyjianchina。
