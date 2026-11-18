# 自己的家用 DNS 自己管：TelltaleDNS 小白安装（含真实报错）

你是不是也遇过这种事：想在家里拦广告、看清每台设备在查哪些域名，搜索时全是 Pi-hole 教程；GitHub 上新冒出来的 TelltaleDNS 星涨得很快，说明却几乎全是英文，一不小心就会把 53 端口或系统 DNS 改乱。

这篇只解决这件事：在自己的 Linux 电脑或小服务器上，先用官方静态二进制把 TelltaleDNS 跑起来，用浏览器打开控制台，并确认「放行」和「拦截」两种结果。下面的步骤和报错，都是我在 2026 年 11 月 18 日（Asia/Shanghai）在 Linux x86_64 上从头跑过的，不是翻译文档，也不是「应该会这样」。

先说结论：可以跑通。本次使用官方发布的 v0.7.0 静态二进制（`telltale 0.7.0`，commit 9c9c3a6，2026-11-16 构建）。进程启动后约 1 秒开始监听，广告列表 HaGeZi Light 在约 0.3 秒内下载完成（本次为 2,268,530 字节、92,926 行）。我把 DNS 绑在 `127.0.0.1:5300`，网页控制台绑在 `127.0.0.1:8053`，**没有改这台机器的系统 DNS，也没有占用 53 端口**。向它查询 `example.com` 会转发并返回结果；查询 `google-analytics.com`、`pagead2.googlesyndication.com` 会被列表拦截，回答 `0.0.0.0`（带 AA 标志）。确认无误后，再考虑把监听改到 53 端口，并在路由器 DHCP 里指向这台机器。

项目目前是 0.x（pre-1.0）。官方说 1.0 之前配置项和 API 仍可能变动，升级前请先读对应版本的 Release 说明。

## 这是什么，适不适合你

TelltaleDNS 是给家庭或小型网络用的 DNS 解析器和广告拦截器：每条查询会记下来、说明为什么这样回答，也可以按设备或分组设置规则。官方定位接近 Pi-hole / Technitium，可以跑在树莓派、普通 Linux，或用 Docker / Kubernetes。控制台在浏览器里打开，不需要再装一套 Web 服务器。

适合：想在自己电脑、树莓派、NAS 旁路机器或小服务器上先试起来的普通人。不需要会写 Rust。本次验证的是「官方静态二进制 + 本地配置文件」这条路径，不依赖 Docker。

不太适合：只想在手机里装一个现成 App、完全不想碰终端的人；以及必须在 Windows / macOS 上原生安装的人——v0.7.0 的 Release 里只有 Linux 二进制（`x86_64`、`aarch64`、`armv7`），没有 Windows 或 macOS 安装包。这两类系统若要试，只能走官方 Docker 镜像，或在 WSL2 的 Linux 里用和本文相同的方法。

原仓库：https://github.com/paimonsoror/telltaledns  
官方运行文档：https://github.com/paimonsoror/telltaledns/blob/main/docs/running.md  
项目站点：https://paimonsoror.github.io/telltaledns/  
许可证：Apache-2.0 或 MIT，由你选择

## 环境准备

你需要：一台 Linux（本次是 x86_64）、终端、curl，以及一个浏览器。`dig` 不是必须的；本机当时 `apt-get install dnsutils` 失败了（Debian 仓库返回 500），没有现成的 `dig`。我改用 Python 向 `127.0.0.1:5300` 发送 DNS 查询做验证。你的机器上若已有 `dig`，用下面的 `dig` 命令即可，不必再装别的工具。

请先做到这两件事：

1. **先不要改系统 DNS，也先不要在路由器里把 DNS 指过来。** 先在高端口上验证「能解析、能拦截」，再考虑切换。
2. **先不要用默认监听地址。** 官方默认会在 `0.0.0.0:53` 提供 DNS，并在 `0.0.0.0:8053` 打开网页控制台、在 `0.0.0.0:9153` 打开指标端口。对正在使用的电脑来说，53 端口通常需要 root 或 `CAP_NET_BIND_SERVICE`；8053 若暴露到局域网，谁先打开页面，谁就可能领走第一个管理员。本次配置全部改成只监听 `127.0.0.1`，DNS 用 5300 端口。

验证本机架构：

```
uname -m
```

`x86_64` 用 `telltale-x86_64-linux`；树莓派 64 位系统一般是 `aarch64`；32 位 Pi OS 用 `armv7`。ARMv6（Pi 1、第一代 Zero W）官方不支持。

## 一步步安装（本次实测：官方静态二进制）

下面的命令在 Linux 或 WSL2 里可以直接用。请先建一个专门的目录，数据和配置都放在这里，不要写到系统目录里。

```
mkdir -p ~/apps/telltale/{bin,config,data}
cd ~/apps/telltale
```

### 1. 下载 v0.7.0 并核对校验和

```
cd ~/apps/telltale/bin
curl -fL --output telltale-x86_64-linux \
  https://github.com/paimonsoror/telltaledns/releases/download/v0.7.0/telltale-x86_64-linux
curl -fL --output SHA256SUMS \
  https://github.com/paimonsoror/telltaledns/releases/download/v0.7.0/SHA256SUMS
grep 'telltale-x86_64-linux$' SHA256SUMS
sha256sum telltale-x86_64-linux
grep 'telltale-x86_64-linux$' SHA256SUMS | sha256sum -c
chmod +x telltale-x86_64-linux
ln -sfn telltale-x86_64-linux telltale
./telltale --version
```

本次校验和是：

```
1833510c2521197d48f89279c51ea9b2aa99329a25c07d304a442c6c4dc5db31  telltale-x86_64-linux
```

`sha256sum -c` 输出 `telltale-x86_64-linux: OK`。`./telltale --version` 的原文是：

```
telltale 0.7.0 (commit 9c9c3a6, built 2026-11-16T17:10:28Z, channel stable, x86_64-unknown-linux-musl)
```

注意：没有 `telltale version` 这个子命令。我一开始写了它，得到的是 `error: unrecognized subcommand 'version'`，提示里让我看 `--help`。正确写法是 `telltale --version` 或 `telltale -V`。

其他架构把文件名换成 `telltale-aarch64-linux` 或 `telltale-armv7-linux`，并核对自己那一行校验和，不要复制上面这一行 x86_64 的值。

### 2. 写一份只监听本机高端口的配置

把下面的内容保存为 `~/apps/telltale/config/telltale.toml`。路径请改成你自己的目录。这份配置故意不用 53 端口，也不把控制台暴露到所有网卡。

```
# 先在本机高端口试跑，确认能解析、能拦截，再考虑改到 53 端口
config_version = 1

[node]
data_dir = "/home/你的用户名/apps/telltale/data"

[cluster]
listen = "127.0.0.1:8443"

[api]
listen = "127.0.0.1:8053"

[telemetry.metrics]
listen = "127.0.0.1:9153"

[[listen]]
proto = "udp"
addr = "127.0.0.1:5300"

[[listen]]
proto = "tcp"
addr = "127.0.0.1:5300"

[[upstream]]
name = "cloudflare"
url = "udp://1.1.1.1"

[[upstream]]
name = "quad9"
url = "udp://9.9.9.9"

[[upstream_group]]
name = "default"
members = ["cloudflare", "quad9"]
strategy = "fastest"

# 先用体积更小的 Light 列表，官方 Compose 默认是 HaGeZi Pro（约 15 万条）
[[list]]
name = "hagezi-light"
url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/light.txt"

[telemetry.qlog]
retention_days = 1
```

说明几处容易误解的地方：

- 不写 `[[group]]` 也可以。官方文档写明：未指定 `lists` 时，`default` 分组会使用全部列表。本次就是这样。
- 上游我先用普通 UDP（`udp://1.1.1.1`），是为了减少变量。官方 Compose 起步配置用的是加密 DNS（`tls://1.1.1.1:853`，并带 `tls_server_name`）。等本机跑通后，可以再改成加密上游。
- `data_dir` 必须是当前用户写得进去的目录。若不写，默认是 `/var/lib/telltale`，普通用户常常既建不了，也读不到里面的 setup token。

检查配置：

```
~/apps/telltale/bin/telltale config check ~/apps/telltale/config/telltale.toml
```

成功时只打印 `config OK`。若写错字段，它会一次性列出所有问题，并且把未知字段当成错误，不会默默忽略。

### 3. 启动

```
~/apps/telltale/bin/telltale run -c ~/apps/telltale/config/telltale.toml
```

本次日志里，关键几行的原文如下（时间戳按你自己的机器）：

```
INFO starting TelltaleDNS version="0.7.0" commit="9c9c3a6" role=All workers=8
INFO listening (udp) addr=127.0.0.1:5300 workers=8
INFO listening (tcp) addr=127.0.0.1:5300 proxy_protocol=false
INFO serving /metrics, /healthz, /readyz, /livez addr=127.0.0.1:9153
WARN no users yet: create the first admin in the web UI with the setup token; `telltale auth setup-token` prints it (or read the file) file=.../data/setup-token
INFO serving the API at /api/v1 (OpenAPI: /api/v1/openapi.json) addr=127.0.0.1:8053 scheme="http"
INFO list fetcher started lists=1 dir=.../data/lists
INFO list updated list=hagezi-light bytes=2268530 lines=92926
```

请注意：日志只告诉你 setup token 在哪个文件，**不会把令牌本身打到日志里**。这是有意的。

另开一个终端，确认端口：

```
ss -lntu | grep -E '5300|8053|9153'
```

本次 `127.0.0.1:5300`（UDP/TCP）、`127.0.0.1:8053`、`127.0.0.1:9153` 都在监听。指标接口 `http://127.0.0.1:9153/healthz` 返回 `ok`，`/readyz` 返回 `{"ready":true}`。

### 4. 验证「能解析」和「能拦截」

有 `dig` 时：

```
dig @127.0.0.1 -p 5300 example.com A
dig @127.0.0.1 -p 5300 google-analytics.com A
dig @127.0.0.1 -p 5300 pagead2.googlesyndication.com A
```

没有 `dig` 时，可以用 Python 发一条最简单的 DNS 查询（下面这段就是我本次实际用的思路：向 `127.0.0.1:5300` 问 A 记录，看返回地址和是否带 AA 标志）。被拦截的名字会回答 `0.0.0.0`，并且响应带 AA（权威回答）标志；被转发的名字则把上游的结果原样带回。

本次实测：

- `example.com`、`google.com`、`wikipedia.org`、`facebook.com`：状态是转发（查询日志里为 `forwarded`），得到一条 A 记录。
- `google-analytics.com`、`www.google-analytics.com`、`analytics.google.com`、`pagead2.googlesyndication.com`、`pixel.facebook.com`、`ads.facebook.com`：状态是拦截（`blocked`），回答 `0.0.0.0`，TTL 60，带 AA 标志。
- 不要想当然地认为所有「看起来像广告」的域名都会被拦。本次 `doubleclick.net` 和 `ad.doubleclick.net` **没有**被 HaGeZi Light 拦截，查询日志里是 `forwarded`。换列表或改规则之前，先用官方的 explain 命令看原因：

```
~/apps/telltale/bin/telltale explain pagead2.googlesyndication.com -c ~/apps/telltale/config/telltale.toml
~/apps/telltale/bin/telltale explain doubleclick.net -c ~/apps/telltale/config/telltale.toml
~/apps/telltale/bin/telltale explain example.com -c ~/apps/telltale/config/telltale.toml
```

本次原文分别是：

- `pagead2.googlesyndication.com`：`outcome  BLOCKED: blocked by list hagezi-light for group default: answered 0.0.0.0 / ::`，命中规则 `||googlesyndication.com^`。
- `doubleclick.net` 和 `example.com`：`outcome  RESOLVED: no rule applies; resolved normally`。

关于本次转发结果里的 IP：在我这台机器上，`example.com` 经 TelltaleDNS、以及我直接向 `1.1.1.1:53`、`8.8.8.8:53` 查询，A 记录都是 `198.18.0.1`。这是 RFC 5737 里的测试网段地址，说明**这台机器所在网络会拦截对公网 DNS 的查询**，并统一改写成这个地址。这不是 TelltaleDNS 自己编出来的「标准答案」。你在家里的普通网络上，转发结果应该是该域名真实的公网地址。判断软件有没有跑通，请看这两点是否同时成立：未被拦截的域名能返回 A 记录；被列表命中的域名稳定返回 `0.0.0.0`。

### 5. 打开网页，创建第一个管理员

浏览器打开：

http://127.0.0.1:8053/

本次首页标题是 `TelltaleDNS`，HTTP 200，带严格的 Content-Security-Policy（脚本和样式都只来自自身）。还没登录时，调用 `/api/v1/system/health` 会返回 401，原文为 `Authentication required` / `sign in to use the API`。这是正常的。

打印一次性 setup token（必须带上和运行时相同的 `-c` 配置，这样才会去你的 `data_dir` 里找）：

```
~/apps/telltale/bin/telltale auth setup-token -c ~/apps/telltale/config/telltale.toml
```

也可以直接阅读 `data_dir/setup-token`（权限是仅所有者可读）。在页面里用这个令牌创建第一个管理员，密码至少 10 位。创建成功后，这个文件会被删掉。我用 HTTP API 复核过同一流程：`POST /api/v1/auth/setup` 返回 201，随后 `setup-token` 文件消失；再执行上面的命令，得到：

```
setup is done: sign in with an admin account
```

退出码为 1。登录后，`GET /api/v1/system/health` 返回 `{"level":"healthy","reasons":[]}`。查询日志里能看到刚才那些域名，以及 `blocked` / `forwarded` 状态。

不要把 setup token、管理员密码、`data_dir` 里的 `state.db` 或 `privacy.key` 发到网上。

### 6. 什么时候再改到 53 端口、改路由器

只有在本机高端口已经验证「能解析、能拦截、能登录控制台」之后，才值得改。常见做法是：

- 监听改成 `0.0.0.0:53` 或只监听局域网地址；53 端口需要 root、`CAP_NET_BIND_SERVICE`，或按官方文档把 `net.ipv4.ip_unprivileged_port_start` 调到 53。
- 网页控制台如果只给家里用，仍然建议绑定局域网地址，并尽快创建管理员；需要的话按官方文档给 `[api]` 打开 HTTPS。
- 最后才在路由器的 DHCP 里把 DNS 指到这台机器，并让设备重新获取地址。

本次**没有**改系统 DNS，也没有改路由器。我另外用一份临时配置尝试以普通用户监听 `127.0.0.1:53`，进程立刻退出，原文是：

```
telltale: Udp 127.0.0.1:53: Permission denied (os error 13)
```

这是预期行为，不是软件损坏。家庭环境若要用 53 端口，请按官方「Raspberry Pi and Linux」一节处理权限，或改用官方 Docker Compose（容器里可以用 53 端口）。

## 官方 Docker 路径（本机未完整实测）

官方更推荐树莓派和家用 Linux 用 Docker Compose，因为它会按 host 网络启动，日志里能看到设备的真实地址，并直接占用 53 端口。命令在官方文档里是：

```
mkdir telltale && cd telltale
curl -fsSLO https://raw.githubusercontent.com/paimonsoror/telltaledns/main/deploy/compose/compose.yaml
curl -fsSLO https://raw.githubusercontent.com/paimonsoror/telltaledns/main/deploy/compose/telltale.toml
docker compose up -d
docker compose exec telltale telltale auth setup-token
# 然后打开 http://<这台机器的地址>:8053/
```

还有一条 `install.sh` 可以把二进制装成 systemd 服务。

这台机器不宜占用 53 端口，也不宜往共享的 Docker 守护进程里加入 host 网络容器，所以**这条路径我没有完整跑通，上面的命令没有在本机得到启动日志**。它们来自官方文档，不是我编的结果。你如果在自己的树莓派或家用电脑上走这条路，请以官方文档和你自己的终端输出为准；验证方法仍建议先用 `dig @<机器IP> example.com` 和前面那些拦截域名对照，再改路由器。

## 我实际遇到的报错（只记这次出现过的）

1）`telltale version` 报 `unrecognized subcommand 'version'`。应使用 `telltale --version` 或 `-V`。

2）普通用户监听 `127.0.0.1:53` 报 `Permission denied (os error 13)`。先用 5300 这类高端口验证，或按官方文档提升绑低端口的权限。不要用 `sudo` 随手把整个进程跑成长期 root 服务；官方 native 安装脚本会做成只带 `CAP_NET_BIND_SERVICE` 的 systemd 单元。

3）执行 `telltale auth setup-token` 时如果漏了 `-c`，本次报 `Permission denied (os error 13)`。因为默认 `data_dir` 是 `/var/lib/telltale`，普通用户写不进去。必须带上和 `telltale run` 相同的配置文件。

4）第一个管理员创建完成后，再执行 `telltale auth setup-token -c ...`，报 `setup is done: sign in with an admin account`，退出码 1。这是正常状态，不是安装失败。

5）未登录时访问 `/api/v1/system/health` 返回 401 `Authentication required`。先完成网页注册或登录。

6）本机 `sudo apt-get install dnsutils` 失败，仓库返回 500，InRelease 无法校验。这是本次软件源的问题，与 TelltaleDNS 无关。没有 `dig` 时，向 `127.0.0.1:5300` 发 DNS 查询同样可以验证。

7）本机上游 DNS 被网络改写成 `198.18.0.1`。我直接问 `1.1.1.1` 和 `8.8.8.8` 也是同样的地址；问 `9.9.9.9:53` 则超时。不要把这个地址写成 TelltaleDNS 的「正常公网解析结果」。拦截是否生效，以 `0.0.0.0` 和 `telltale explain` 为准。

8）默认配置会把控制台监听在 `0.0.0.0:8053`。若你直接用空配置启动，局域网里的人可能先打开页面并创建管理员。先改成 `127.0.0.1` 或你的局域网地址，并尽快完成管理员注册。

## 原仓库 README 要点（不是全文翻译）

TelltaleDNS 的目标是：看清家里每台设备的 DNS 查询，并按你的规则回答，同时尽量保持体积和速度。官方给的启动方式有三种：Docker Compose（推荐给树莓派和家用 Linux）、native systemd 安装脚本、以及直接运行静态二进制。镜像约 13 MiB，支持 amd64、arm64 和 32 位 Pi OS。控制台、API 和 MCP 都做在同一个二进制里。可以从 Pi-hole 的 Teleporter 导出或 Technitium 配置导入。1.0 之前，发布说明会标明不兼容的配置或 API 变化。完整命令、加密 DNS、分组、集群和备份，请直接看原文：

https://github.com/paimonsoror/telltaledns  
https://github.com/paimonsoror/telltaledns/blob/main/README.md  
https://github.com/paimonsoror/telltaledns/blob/main/docs/running.md  
https://paimonsoror.github.io/telltaledns/start.html

## 协议声明

本项目允许在 Apache-2.0 或 MIT 下使用，由你选择。本文是我自己的操作记录。翻译或转载 README 时必须保留原仓库链接、版权和许可声明，不能把译文当成原创，也不得让人误以为本文代表项目官方。

不要公开 setup token、管理员密码、查询日志里可能出现的设备名或内网地址，也不要上传 `data_dir` 里的 `state.db`、`privacy.key` 或 `setup-token` 文件。把家里的 DNS 指到某台机器之前，请先在本机高端口验证拦截和解析都符合预期。

## 下期预告

下一篇仍按同样标准：盯最近星涨得快、中文跟做记录少、普通人能在自己机器上用起来的开源工具，亲自跑通再写。候选里比较接近的还有自托管电子签署 SignuDoc，但它的主推安装方式是 Vercel + Neon + Resend，和「装在自己的 NAS 或小服务器上」并不完全一样，要等本地路径真正跑通才写。

本文的 GitHub 副本：https://github.com/oss-xiaobai-notes/xiaobai-deploy-handbook/blob/main/docs/03-telltaledns.md
