# 开源工具小白部署手册

GitHub 上常有 Star 突然暴涨的小工具，官方说明却只有英文，中文教程要么没有，要么是没人跑过的机翻。这里只做一件事：盯热门仓库，自己从安装跑到第一次能用，把真实报错和解决步骤写成可跟做的小白笔记。

适合想把工具装到自己电脑、NAS 或小服务器上的普通人。每篇讲清适用场景、环境要求、逐步命令、实际踩过的报错，以及如何确认已经跑通。

你看到的是亲自跑通的记录，不是整篇 README 译文。原文仓库链接和开源协议声明都会保留。

## 目录

1. [自己的账本自己托管：Sure 小白一键部署（含真实报错）](docs/01-sure.md) — [we-promise/sure](https://github.com/we-promise/sure)，AGPL-3.0
2. [让 AI 动手点桌面：agent-desktop 安装与第一次操作](docs/02-agent-desktop.md) — [vercel-labs/agent-desktop](https://github.com/vercel-labs/agent-desktop)，Apache-2.0

配套脚本（请先读对应教程再运行）：

- [scripts/sure-install.sh](scripts/sure-install.sh)
- [scripts/agent-desktop-install.sh](scripts/agent-desktop-install.sh)

## 阅读前请注意

- 不要把 `.env`、API Key 或私密桌面截图发到公开地方。
- 本仓库只发布教程和安装脚本，不包含任何实测密钥。
- 所涉及的开源项目仍按各自许可证授权；本仓库中的笔记与脚本是对安装过程的记录，不是这些项目的官方文档。

## 更新

先从已跑通的两篇开始公开。后续仍会按「星涨得快、中文教程少、普通人能在自己的机器上跑起来」这个标准补新篇。
