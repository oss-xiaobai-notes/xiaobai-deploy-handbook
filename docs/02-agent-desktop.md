# 让 AI 动手点桌面：agent-desktop 安装与第一次操作

GitHub 上突然冒出很多「让 AI 使用电脑」的项目。点开仓库，安装命令往往只有两行，好像很简单；真正跑起来，Linux 上却可能先报一句：无障碍总线不存在，任何应用都看不见。

这篇写的是 vercel-labs/agent-desktop。它不负责聊天，也不需要你填模型 API Key，只做一件事：读取桌面应用的无障碍树，把按钮、菜单变成带编号的 JSON，再按你或 AI 给出的引用去点击。下面的步骤和报错，都是我在 2026 年 11 月 12 日（Asia/Shanghai）在 Debian 13 的图形会话里从头跑过的。

先说结论：安装和第一次真正操作可以跑通，但 Linux 上不能只装 npm 包。补齐 AT-SPI 之后，我启动了终端窗口，拍到带引用的快照，并成功点击了 File 菜单。按窗口截图也成功了。向终端里输入文字这条没有跑通——先被无头模式的策略拒绝，加上 --headed 后又因为同一窗口里有两个相同的文本框报了 AMBIGUOUS_TARGET。文中只写实际发生的事。

原仓库：https://github.com/vercel-labs/agent-desktop
官方文档：https://agent-browser.dev/desktop
许可证：Apache-2.0
本次 npm 包版本：1.2.0

## 这是什么，适不适合你

适合已经在用 AI 编程助手、希望它能操作本机应用的人。它不是浏览器自动化（那是姐妹项目 agent-browser），也不能在一台没有图形界面的纯 SSH 服务器上「看见」应用。官方明确写过：TTY、未带会话变量的 SSH、没有总线的容器里，看不到任何应用。

官方 Linux 基线是 Ubuntu 24.04 或更高、glibc 2.35 或更高。本次实际系统是 Debian 13，glibc 2.41，命令可以运行。Windows 10 1809+ 和 macOS 13+ 也支持，权限方式不同，下面会分开写。

快照、截图和命令输出里可能出现桌面上的私密内容，不要发到公开地方。

## 环境准备

需要 Node.js 18 或更高（本次为 v24.22.1），以及已登录用户的图形桌面。

Windows：安装 Node.js 后即可装 CLI。官方提到程序未签名，Smart App Control 或杀毒软件可能拦截；用 npm 安装一般不会触发 SmartScreen。

macOS：安装 Node.js 后，还要给辅助功能授权；截图还要屏幕录制权限。用下面的引导命令打开系统设置：

```
agent-desktop permissions --guide
```

Linux（X11 或 Wayland）：除了 Node.js，还要安装 at-spi2-core，并且在图形会话里运行（有 DISPLAY 或 Wayland，以及会话的 D-Bus）。

先确认 Node 可用：

```
node -v
npm -v
```

## 安装 CLI

推荐这样装，避免官方的 postinstall 被 npm 拦住：

```
npm install -g agent-desktop --allow-scripts=agent-desktop
agent-desktop version
```

macOS 和 Linux 也可以用 `brew install agent-desktop`。本次走的是 npm。

成功时，version 会打印一段 JSON，`ok` 为 true，`data.version` 为 1.2.0。本次第一次少写了 `--allow-scripts`，命令其实已经能用，但 npm 给出了警告，见文后 FAQ。补上后再装一次，警告消失。

## 第一次运行

第一步，查看状态：

```
agent-desktop status
agent-desktop permissions
```

你希望看到无障碍权限为 granted，而且 supported_surfaces 不是空数组。本次 Linux 上是 window、sheet、alert、menu。如果是 denied，先不要拍快照。list-displays 即使在总线未就绪时也可能成功，不要把它当成「已经能点应用」。

第二步，Linux 用户安装无障碍总线：

```
sudo apt-get update
sudo apt-get install -y at-spi2-core
```

装好后，在图形会话的终端里再运行 `agent-desktop status`。一般不必手工启动进程，D-Bus 会拉起 org.a11y.Bus。本次我的软件源发生 500 错误，apt 没装上，后来改用官方 .deb 才成功，细节见 FAQ。你在正常的 Ubuntu 或 Debian 桌面上，用上面两条即可。

第三步，打开一个真实的桌面应用。总线就绪后，如果还没有向 AT-SPI 注册的窗口，list-apps 会返回空列表，这不是命令坏了。

```
export GTK_MODULES=gail:atk-bridge
export GTK_A11Y=atspi
xfce4-terminal &
# 也可以：
agent-desktop launch xfce4-terminal
agent-desktop list-apps
agent-desktop list-windows
```

macOS 官方示例用的是 Finder；Windows 请先 list-apps 查看正在运行的名字，不要照抄 Finder 或 xfce4-terminal。成功时应能看到应用名、pid，以及窗口的 id 和 title。请记下窗口 id。

第四步，拍快照，再点一个真正看得见的控件：

```
agent-desktop snapshot --app xfce4-terminal --window-id "<你的窗口id>" -i
```

`-i` 表示只要可交互元素。每个可点控件的 ref_id 形如 `@<snapshot_id>:e<编号>`。必须使用刚刚那一次快照里的引用，不要抄我的，也不要写成 `@e2`。

本次成功点击的是菜单栏上的 File：

```
agent-desktop click '@快照编号:e编号'
agent-desktop snapshot --app xfce4-terminal --window-id "<你的窗口id>" -i
```

点击成功后，JSON 里 ok 为 true，并能看到 File 菜单项。不要随手点 Close Window。截图请带上窗口 id：

```
agent-desktop screenshot --window-id "<你的窗口id>" ./window.png
```

本次这样截图成功，全屏截图则会失败。

关于输入文字：终端文本框在快照里往往只有 RightClick 和 SetFocus。无头模式下对它执行 click、focus、type，本次都返回 POLICY_DENIED，提示需要 `--headed`。加上之后，我这边又因为同一窗口里有两个相同文本框（误触打开了新标签），得到 AMBIGUOUS_TARGET，所以没有写成「已经成功输入」。

## 一键脚本

下面的脚本只负责检查 Node、安装 CLI，并运行 status。它不会自动用管理员权限安装系统包，也不会替你点击桌面。若 status 显示权限未就绪，脚本会按系统打印下一步。把内容保存为 install.sh 后执行：

```
chmod +x install.sh
./install.sh
```

本次在权限已就绪的环境里复跑过，退出码为 0。脚本全文：

```
#!/usr/bin/env bash
# agent-desktop 安装脚本
# 原仓库：https://github.com/vercel-labs/agent-desktop  License: Apache-2.0
# 用法：
#   chmod +x install.sh
#   ./install.sh
# 本脚本只负责安装 CLI 并打印 status。它不会自动用 root 装系统包，
# 也不会替你点击桌面。Linux 若 status 提示缺少 AT-SPI，请按脚本输出的提示安装 at-spi2-core。
set -euo pipefail

log() { printf '%s\n' "$*"; }
die() { printf '错误：%s\n' "$*" >&2; exit 1; }

command -v node >/dev/null 2>&1 || die "未找到 node。请先安装 Node.js 18 或更高版本：https://nodejs.org/"
command -v npm >/dev/null 2>&1 || die "未找到 npm。请先安装 Node.js（会附带 npm）。"

node_major="$(node -p 'process.versions.node.split(".")[0]')"
if [[ "$node_major" -lt 18 ]]; then
  die "需要 Node.js 18 或更高版本，当前是 $(node -v)。"
fi

log "Node.js $(node -v)，npm $(npm -v)"
log "正在安装 agent-desktop（允许官方 postinstall，以便链接原生命令）..."

# 官方文档：部分 npm 会拦截 postinstall。加上 --allow-scripts 后，启动器会被替换成本机二进制。
if npm install -g agent-desktop --allow-scripts=agent-desktop; then
  :
else
  log "带 --allow-scripts 的安装未成功，回退到普通安装（命令仍可用，只是可能多一层 Node 启动器）..."
  npm install -g agent-desktop
fi

command -v agent-desktop >/dev/null 2>&1 || die "安装后仍找不到 agent-desktop 命令。请确认 npm 全局 bin 目录已加入 PATH，例如：npm prefix -g 下面的 bin。"

log "安装完成。当前版本："
agent-desktop version

log ""
log "正在检查平台和权限（agent-desktop status）..."
agent-desktop status || true

# 根据 status 给下一步提示（不把 JSON 解析失败当成安装失败）
status_json="$(agent-desktop status 2>/dev/null || true)"
if printf '%s' "$status_json" | grep -q '"state":"denied"'; then
  log ""
  log "status 显示无障碍权限尚未就绪。"
  case "$(uname -s)" in
    Linux)
      log "在 Linux 上请先安装 at-spi2-core，并在「已登录用户的图形会话」里运行本命令（需要有 DISPLAY 或 Wayland，以及会话的 D-Bus）。"
      log "Debian / Ubuntu 示例：sudo apt-get update && sudo apt-get install -y at-spi2-core"
      log "装好后重新打开终端，再运行：agent-desktop status"
      log "若 supported_surfaces 仍是空数组，说明无障碍总线没有响应。"
      ;;
    Darwin)
      log "在 macOS 上请运行：agent-desktop permissions --guide"
      log "按提示授予辅助功能权限；截图还需要屏幕录制权限。"
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      log "Windows 一般不必额外授权。若 Smart App Control 或杀毒软件拦截了未签名程序，请对照官方安装说明处理。"
      ;;
    *)
      log "请根据官方说明检查权限：https://github.com/vercel-labs/agent-desktop"
      ;;
  esac
  log "权限未就绪时，version / status / list-displays 仍可能成功，但 list-apps、snapshot 通常会失败。"
  exit 2
fi

log ""
log "权限看起来已就绪。可以继续："
log "  agent-desktop list-apps"
log "  agent-desktop list-windows"
log "  agent-desktop snapshot --app \"应用名\" -i"
log "请先打开一个真实的桌面应用再拍快照。引用必须带快照编号，例如 @s8f3k2p9:e1，不要写 @e1。"
log "全屏截图在部分 Linux 窗口管理器上会失败，请改用：agent-desktop screenshot --window-id <窗口id> out.png"


```

不要在未读过脚本的情况下，随意从网上拷一条「一键管道」直接运行。

## 我实际遇到的报错（只记这次出现过的）

1）第一次 npm 安装时的脚本警告。原文大意是 agent-desktop@1.2.0 的 postinstall 尚未被 allowScripts 覆盖，并提示运行 `npm install -g --allow-scripts=agent-desktop`。处理：按提示再装一次。本次复测后警告消失。

2）status 显示 accessibility 为 denied，supported_surfaces 为空数组，建议安装 at-spi2-core。此时不要急着 snapshot。

3）list-apps / list-windows 失败。原文：

```
"code":"PLATFORM_NOT_SUPPORTED",
"message":"The AT-SPI accessibility bus is not available in this session",
"platform_detail":"org.freedesktop.DBus.Error.ServiceUnknown: The name org.a11y.Bus was not provided by any .service files"
```

处理：安装 at-spi2-core，并在图形会话中重试。本次装好后再次 status，权限变为 granted。

4）本机 apt-get update 失败（软件源 500，仓库显示未签名），随后安装 at-spi2-core 报没有安装候选，并提示已被 at-spi2-common 取代。当时机器上只有 common 包（文档和翻译），没有总线程序。这是本次软件源异常，不能推广成「Debian 都不能用 apt」。你的电脑如果 update 正常，继续用 apt 即可。本次改为从 Debian 官方池下载 .deb，再用 dpkg 安装。

5）dpkg 安装 at-spi2-core 时缺依赖 gsettings-desktop-schemas，软件包停留在未配置状态。补装该依赖后再配置，两个包都变为已安装。

6）总线已就绪，但 list-apps 仍是空列表。打开会向 AT-SPI 注册的图形应用即可。本次给 GTK 加上 gail:atk-bridge 后，终端出现在列表中。另外有一条可忽略的警告：未设置 SESSION_MANAGER。当时系统里也没有 gsettings 命令，但不影响启动应用。

7）点击工具栏的 Open Tab，报 ACTION_FAILED，原文为 Target is not actionable: visible (live offscreen state is true)。该窗口工具栏在无障碍树里是隐藏的。改点菜单栏上看得见的 File，就成功了。

8）使用裸引用 `@e14`，报 INVALID_ARGS：必须写成 `@<snapshot_id>:e<N>`。不要省略快照编号，也不要复用过期引用。

9）无头模式下对终端文本框执行 click、focus、type，均返回 POLICY_DENIED，提示只允许无障碍语义动作，若要物理交互需加 `--headed`。

10）不带窗口 id 的全屏截图失败。原文指出在合成窗口管理器下，根窗口不能如实反映各个应用窗口，建议改用 `screenshot --window-id`。按建议后截图成功。

11）在 Linux 上运行 `permissions --guide`，报 PLATFORM_NOT_SUPPORTED：start_permission_guide is not supported on this platform。这是 macOS 的引导命令，Linux 不要靠它授权。

12）加上 `--headed` 后 type 仍失败，报 AMBIGUOUS_TARGET：保存的引用在捕获时不能被证明唯一。当时同一窗口里有两个相同的 Terminal 文本框。应先关掉多余标签再拍快照，或按官方建议用带坐标的 headed 点击来区分。本次未继续模拟坐标点击。

## 原仓库 README 要点（不是全文翻译）

agent-desktop 让 AI 在不靠截图、也不靠像素匹配的情况下使用电脑。循环由你的智能体完成，工具内部不含模型。引用从属于某一次快照；多个窗口或两个一模一样的控件会得到 AMBIGUOUS_TARGET。默认无头，加 --headed 才允许移动指针或焦点。PowerShell 里每个引用都要加引号。完整命令列表、各平台差异和 C 库说明，请直接看原文：

https://github.com/vercel-labs/agent-desktop
https://github.com/vercel-labs/agent-desktop/blob/main/README.md
https://agent-browser.dev/desktop/installation

## 协议声明

本项目使用 Apache-2.0 许可证。本文是我自己的操作记录。翻译或转载 README 时必须保留原仓库链接、版权和许可声明，不能把译文当成原创，也不得让人误以为本文代表 Vercel 官方。不要公开传播可能含有桌面隐私的快照或截图。本工具不需要模型 API Key；如果你后来把它接到某个 AI 服务上，那些密钥请用你自己的，不要使用任何占位符。

## 下期预告

下一篇计划写 milind-soni/OpenMausBot：一个带虚拟机、可以自己托管的开源机器人平台。它的 Star 涨得很快，中文几乎只有转载式介绍，但安装体量会比本篇更重，我会按同样标准亲自跑一遍再写。
