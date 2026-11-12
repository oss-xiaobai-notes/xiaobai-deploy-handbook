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
