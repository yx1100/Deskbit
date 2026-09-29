# 随便记 Whatnote

<p align="center">
  <img src="Assets/Whatnote-icon.png" width="128" alt="随便记 app icon">
</p>

<p align="center">随手记下任何事的 macOS 桌面便签。</p>

英文名 **Whatnote** 取自 “whatnot”（随便什么东西）加 “note”（记）。

## 功能

- 液态玻璃界面，便签始终为浅色，正文 18 号字
- 蓝、绿、黄、粉四种便签颜色
- Markdown：标题、粗体、斜体、删除线、行内代码、链接、项目符号列表、编号列表、核对清单、分隔线
- 可点按勾选的圆形核对清单
- 粘贴或拖入图片；输入或粘贴的网址自动成为链接
- 全局快捷键 `⌃⌥⌘空格` 在任何 App 中新建便签
- 置顶便签跨所有桌面显示
- 在桌面上框选多张便签，一起移动、置顶或排列
- 已完成的便签可恢复或删除
- 登录时打开
- 数据只保存在本机：`~/Library/Application Support/Whatnote/notes.json`

## 系统要求

- Apple Silicon Mac
- macOS 11 或更高版本

## 界面

- **左上角**：完成
- **右上角**：颜色、新建便签、置顶、排列便签
- **底部**：粗体、项目符号列表、编号列表、核对清单、分隔线、插入图片
- **菜单栏图标**：新建便签、排列便签、已完成的便签、显示所有便签、设置…、退出随便记

拖动顶部按钮之间的空白处移动便签，拖动边缘调整大小。

## 快捷键

| 功能 | 快捷键 | Markdown |
| --- | --- | --- |
| 新建便签（全局） | `⌃⌥⌘空格` | — |
| 新建便签 | `⌘N` | — |
| 设置… | `⌘,` | — |
| 粗体 | `⌘B` | `**文本**` |
| 斜体 | `⌘I` | `*文本*` |
| 添加链接 | `⌘K` | `[文字](网址)` |
| 项目符号列表 | `⇧⌘7` | `- ` |
| 编号列表 | `⇧⌘9` | `1. ` |
| 核对清单 | `⇧⌘L` | `- [ ] ` |
| 标记为已勾选 | `⇧⌘U` | — |
| 增加 / 减少缩进 | `Tab` / `⇧Tab` | — |
| 标题 | — | `# `、`## `、`### ` |
| 删除线 | — | `~~文本~~` |
| 行内代码 | — | `` `代码` `` |
| 分隔线 | — | 单独一行 `---` |

列表中按回车继续下一项，在空项上按回车结束列表；在列表标记后按删除键把这一行变回普通文字。

## 设置

在菜单栏图标 → 设置… 中可以：

- 修改全局新建便签快捷键，点“还原”回到 `⌃⌥⌘空格`
- 开启“登录时打开”

## 构建

需要 Xcode。

```bash
git clone https://github.com/yx1100/whatnote.git
cd whatnote
./scripts/build-app.sh
open dist/Whatnote.app
```

运行检查：

```bash
for test_script in scripts/test-*.sh; do "$test_script"; done
```

生成 DMG：

```bash
MARKETING_VERSION=1.3.0 BUILD_NUMBER=6 ./scripts/build-app.sh
./scripts/make-dmg.sh 1.3.0
```

## 项目结构

```text
Sources/Whatnote/  应用源码
Tests/             功能检查
Tools/             图标生成
scripts/           构建与测试脚本
Casks/             Homebrew Cask
.github/workflows/ 发布流程
```

## 许可证

[MIT](LICENSE)，基于 [tonyjianchina/Deskbit](https://github.com/tonyjianchina/Deskbit)。
