# 自己的账本自己托管：Sure 小白一键部署（含真实报错）

你是不是也遇过这种事：想记一笔自己的账，却不想把流水交给不知名的云记账应用；打开 GitHub 搜到一个看起来很完整的开源账本，README 全是英文，Docker、Postgres、Redis、密钥跳花了，试两次就卡在「打不开页面」。

这篇只解决这件事：把开源个人理财应用 Sure 装到你自己的电脑或小服务器上，用浏览器记账。下面的步骤和报错，都是我在 2026 年 11 月 12 日（Asia/Shanghai）在 Linux 上从头跑过的，不是翻译文档，也不是「应该会这样」。

先说结论：可以跑通。镜像启动后大约 15 秒，打开 http://127.0.0.1:3000 会跳到注册页，文案是 “Welcome to Self Hosted Sure!”。注册完成后进入新手引导，填写姓名、家庭/团体和国家。本次内存大约占用 800 MB（Web 约 379 MB，后台任务约 365 MB，数据库约 50 MB，Redis 约 6 MB）。建议机器至少 2 GB 内存。官方也写过：512 MB 能应付日常记账，但加载演示数据或打开 AI 功能会不够。

## 这是什么，适不适合你

Sure 能记账户、收支、预算和净资产，数据放在你自己的机器上。它是已停止维护的 Maybe Finance 的社区 fork，和 Maybe Finance Inc. 没有隶属或背书关系。

适合：想把账本放在自己电脑、NAS 或 VPS 上的个人和家庭。不需要先会 Ruby 或 PostgreSQL，跟着用 Docker 即可。应用里的 AI 对话、自动分类是可选项，不填 API Key 也能先记账。

原仓库：https://github.com/we-promise/sure
官方自托管文档：https://github.com/we-promise/sure/blob/main/docs/hosting/docker.md
许可证：AGPL-3.0

## 环境准备

你只需要三样东西：Docker（含 Compose v2，命令是 `docker compose`，中间有空格）、一个终端、一个浏览器。

Windows 10/11：安装 Docker Desktop（https://docs.docker.com/desktop/setup/install/windows-install/ ）。如果提示要开 WSL2，按官方向导开启。用 PowerShell 或 WSL2 里的 Ubuntu 运行命令。

macOS：安装 Docker Desktop（https://docs.docker.com/desktop/setup/install/mac-install/ ）。Apple Silicon 和 Intel 都可以。

Linux：按 Docker Engine 官方指南安装（https://docs.docker.com/engine/install/ ），并安装 Compose 插件。把当前用户加入 docker 组后，重新登录再继续。

三个系统都用下面的命令验证：

```
docker version
docker compose version
docker run hello-world
```

如果出现 `docker: command not found` 或 `Cannot connect to the Docker daemon`，说明还没装好，或 Docker Desktop / 服务没启动。先解决这一步，不要往下走。

家用电脑装好 Docker Desktop 后，一般不需要设置 DOCKER_HOST。默认端口是 3000；被占用时，可在后面的 `.env` 里改成 `PORT=3001`。本次 3000 空闲，没有改端口。

## 一步步部署

下面的命令在 macOS、Linux、WSL2 里可以直接用。Windows PowerShell 如果没有 curl 或 openssl，建议改用 WSL2，或先装 Git Bash。

第一步，建一个专门叫 sure 的目录。Docker Compose 会用目录名当项目名，数据卷的前缀也会跟着变。不要随手放在名叫 deploy 或 test 的文件夹里，否则后面对照官方排障文档时，卷名会对不上。

```
mkdir -p ~/docker-apps/sure
cd ~/docker-apps/sure
```

第二步，下载官方 Compose 文件：

```
curl --fail --location --silent --show-error --output compose.yml \
  https://raw.githubusercontent.com/we-promise/sure/main/compose.example.yml
```

成功后，当前目录应出现 compose.yml。

第三步，自己生成密钥并写 `.env`。官方说不配环境变量也能跑，但示例文件里的 SECRET_KEY_BASE 是公开默认值，不适合长期记账。

```
openssl rand -hex 64
openssl rand -hex 16
```

如果没有 openssl，可以用：

```
head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n' && echo
```

在同一目录创建 `.env`，把下面两处替换成你刚生成的字符串，不要带着尖括号：

```
SECRET_KEY_BASE="<用 openssl rand -hex 64 的结果替换>"
POSTGRES_PASSWORD="<用 openssl rand -hex 16 的结果替换>"
POSTGRES_USER="sure_user"
POSTGRES_DB="sure_production"
PORT=3000

# 必须写这一行（可以为空）。不写的话，每次 docker compose 都会警告，见文后 FAQ。
OPENAI_ACCESS_TOKEN=

# 可选：只有当你要使用应用内 AI 功能（聊天、规则等）时才填写。
# 填写后会产生第三方 API 费用，请先在对应控制台设置消费上限。
# OPENAI_ACCESS_TOKEN="sk-REPLACE_ME"
# OPENAI_URI_BASE="https://api.openai.com/v1"
# OPENAI_MODEL="gpt-4o-mini"
```

OPENAI_ACCESS_TOKEN 是可选项。本次没有填写任何真实 API Key，注册和记账流程仍然可用。不要把真实密钥写进笔记、截图或 Git 仓库。上面的 sk-REPLACE_ME 只是占位符。如果你用的是兼容 OpenAI 接口的其它服务，把 OPENAI_URI_BASE 换成该服务地址即可，能不能用取决于对方接口是否兼容。

第四步，启动。第一次会下载镜像，需要几分钟。本次大约是：Sure 镜像 912 MB，Postgres 451 MB，Redis 146 MB。

```
docker compose pull
docker compose up -d
docker compose ps
```

正常时应看到 web、worker、db、redis 四个容器。db 和 redis 应为 healthy。web 刚启动的几秒内可能还不能访问，这是正常现象。

第五步，等 15 到 30 秒（容器要跑数据库迁移并启动网页服务），再打开：

http://127.0.0.1:3000

本次实际时间线是：启动后大约 0 到 9 秒访问失败，错误原文见下面 FAQ；大约 15 秒后，访问首页返回 302，跳到 /registration/new。注册页标题是 Sure，正文是 “Welcome to Self Hosted Sure!”，需要创建第一个账号。密码要求至少 8 位，并包含大小写字母、数字和特殊字符（例如 !@#$%）。提交后进入 /onboarding。

官方 Docker 文档写的是「你会看到登录页」。实测在第一次、还没有账号时，并不是登录页，而是注册页。这不是故障。

注册完成后，建议到 Settings > Self-Hosting > Onboarding，把注册策略改成 Closed 或 Invite-only，避免别人在你的实例上自行注册。

第六步，常用维护命令（都在 ~/docker-apps/sure 目录下）：

```
docker compose logs -f web worker
docker compose stop
docker compose up -d
```

更新到当前 stable 镜像前请先备份（官方命令是 `docker compose run --rm backup create`），然后：

```
docker compose pull web worker
docker compose up -d
```

## 一键脚本

如果你已经验证过 Docker 可用，也可以把下面的脚本保存为 install.sh，放到任意目录后运行。它会检查 Docker、下载 compose.yml（若还没有）、在没有 .env 时生成密钥、补上空的 OPENAI_ACCESS_TOKEN，然后启动并等待页面就绪。已有 .env 时不会覆盖你的密钥。用法：

```
chmod +x install.sh
./install.sh ~/docker-apps/sure
```

本次已在本机对已部署目录执行过，能够识别现有 .env、不覆盖密钥，并把服务保持在可访问状态。脚本全文如下：

```
#!/usr/bin/env bash
# Sure 小白一键部署脚本（Docker Compose）
# 原仓库：https://github.com/we-promise/sure  License: AGPL-3.0
# 用法：
#   chmod +x install.sh
#   ./install.sh                 # 部署到当前目录
#   ./install.sh ~/docker-apps/sure
set -euo pipefail

COMPOSE_URL="https://raw.githubusercontent.com/we-promise/sure/main/compose.example.yml"
TARGET="${1:-.}"

log() { printf '%s\n' "$*"; }
die() { printf '错误：%s\n' "$*" >&2; exit 1; }

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
cd "$TARGET"
log "部署目录：$TARGET"

# 部分环境只有 TCP 2375、没有默认的 docker.sock（本次实测机器就是这样）
if [[ -z "${DOCKER_HOST:-}" && ! -S /var/run/docker.sock ]]; then
  if (echo >/dev/tcp/127.0.0.1/2375) >/dev/null 2>&1; then
    export DOCKER_HOST=tcp://127.0.0.1:2375
    log "未找到 /var/run/docker.sock，已设置 DOCKER_HOST=tcp://127.0.0.1:2375"
  fi
fi

command -v docker >/dev/null 2>&1 || die "未找到 docker 命令。请先安装 Docker Desktop 或 Docker Engine，然后再运行本脚本。"
docker info >/dev/null 2>&1 || die "无法连接到 Docker 引擎。请先启动 Docker Desktop，或在 Linux 上启动 docker 服务。"
docker compose version >/dev/null 2>&1 || die "未找到 docker compose（Compose v2）。请升级 Docker，使 'docker compose version' 能成功运行。"

if [[ ! -f compose.yml ]]; then
  log "正在下载官方 compose.example.yml ..."
  curl --fail --location --silent --show-error --output compose.yml "$COMPOSE_URL"
  log "已写入 $TARGET/compose.yml"
else
  log "已存在 compose.yml，跳过下载。"
fi

rand_hex() {
  local bytes="${1:-64}"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
  else
    head -c "$bytes" /dev/urandom | od -An -tx1 | tr -d ' \n'
    printf '\n'
  fi
}

if [[ ! -f .env ]]; then
  log "未找到 .env，正在生成 SECRET_KEY_BASE 和数据库密码..."
  SECRET="$(rand_hex 64 | tr -d '\n')"
  DBPASS="$(rand_hex 16 | tr -d '\n')"
  cat > .env <<EOF
SECRET_KEY_BASE="${SECRET}"
POSTGRES_PASSWORD="${DBPASS}"
POSTGRES_USER="sure_user"
POSTGRES_DB="sure_production"
PORT=3000
# 先留空即可消除 compose 警告；启用 AI 时再改成你自己的密钥（不要使用占位符 sk-REPLACE_ME）
OPENAI_ACCESS_TOKEN=
# OPENAI_URI_BASE="https://api.openai.com/v1"
# OPENAI_MODEL="gpt-4o-mini"
EOF
  log "已写入 $TARGET/.env（请自行备份，不要提交到 Git）。"
else
  log "已存在 .env，不会覆盖密钥。"
  if ! grep -q '^OPENAI_ACCESS_TOKEN=' .env; then
    printf '\nOPENAI_ACCESS_TOKEN=\n' >> .env
    log "已在 .env 末尾补充空的 OPENAI_ACCESS_TOKEN=，避免 compose 警告。"
  fi
fi

log "正在拉取镜像并启动（首次可能需要几分钟）..."
docker compose pull
docker compose up -d

PORT="$(grep -E '^PORT=' .env 2>/dev/null | tail -n1 | cut -d= -f2- | tr -d '"' || true)"
PORT="${PORT:-3000}"
URL="http://127.0.0.1:${PORT}"

log "等待 ${URL} 就绪..."
ok=0
for i in $(seq 1 60); do
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 "$URL" || true)"
  if [[ "$code" == "200" || "$code" == "301" || "$code" == "302" || "$code" == "303" ]]; then
    log "已就绪（HTTP $code），共等待约 $((i * 3)) 秒。"
    ok=1
    break
  fi
  sleep 3
done

if [[ "$ok" -ne 1 ]]; then
  log "等待超时。请运行：docker compose logs --tail=80 web"
  log "若刚刚启动，也可能仍在迁移，请再等一会儿后打开 $URL"
  exit 2
fi

log ""
log "部署完成。请在浏览器打开：$URL"
log "第一次访问会进入注册页（Welcome to Self Hosted Sure!），创建的第一个账号将是管理员。"
log "建议注册后到 Settings > Self-Hosting > Onboarding 关闭公开注册。"
log "查看状态：cd $TARGET && docker compose ps"
log "查看日志：cd $TARGET && docker compose logs -f web worker"


```

把上面代码块里的内容保存成 install.sh 后再执行。不要在未读过脚本的情况下，随意从网上拷一条「一键管道」直接运行。

## 我实际遇到的报错（只记这次出现过的）

下面只记录这次真实遇到的原文和对应处理，没有编造未出现的报错。

1）`The "OPENAI_ACCESS_TOKEN" variable is not set. Defaulting to a blank string.`

每次执行 docker compose pull、up、ps、logs、exec 都会各打印 3 次。原文类似：

```
time="2026-11-12T00:17:08+08:00" level=warning msg="The \"OPENAI_ACCESS_TOKEN\" variable is not set. Defaulting to a blank string."
```

原因是官方 compose.yml 写了 OPENAI_ACCESS_TOKEN: ${OPENAI_ACCESS_TOKEN}，而 .env 里如果完全没有这个键（包括被注释掉），Compose 就会警告。处理：在 .env 里增加一行空值 `OPENAI_ACCESS_TOKEN=`，不必申请 Key。不处理也不影响启动，只是警告很吵。补上之后，我复测 compose 警告消失。

2）启动后立刻访问：`Recv failure: Connection reset by peer`

`docker compose up -d` 成功后马上访问 http://127.0.0.1:3000，本次第 1 到 3 次尝试（大约前 9 秒）都失败，第 4 次（大约 15 秒）才返回 302。原文：

```
curl: (56) Recv failure: Connection reset by peer
```

原因是 web 容器虽然显示已 Started，但仍在执行迁移、加载种子数据和启动 Puma。日志稍后会出现 `Listening on http://0.0.0.0:3000`。处理：等 15 到 30 秒再刷新浏览器。不要在这一阶段反复 docker compose down 重来。

3）启动日志里的安全警告：ActiveRecord Encryption is NOT configured

web 和 worker 启动时都出现了。原文大意是：未配置加密，API Key、银行令牌、MFA 密钥和部分个人信息会以明文写进数据库；需要设置 ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY、ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY、ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT，可用 `bin/rails db:encryption:init` 生成。

需要注意的是：官方 .env.example 写着「自托管模式下若不提供，将根据 SECRET_KEY_BASE 自动生成」。但实测容器里这三个变量并未设置，警告仍然出现。而且官方 compose.example.yml 没有把这三个变量传进容器——即使只写在 .env 里，应用也可能读不到（官方文档在 SMTP 一节也强调过：.env 不会整体传入容器，必须在 compose 里列出）。

建议在第一次启动、还没注册账号之前就配好：先把应用起起来，运行 `docker compose exec web bin/rails db:encryption:init`，把打印出的三个值写入 .env（不要发到网上），再在 compose.yml 的 x-rails-env 里增加对应的三行引用，然后执行 `docker compose up -d` 让配置生效。注意：`docker compose restart` 不会加载新的环境变量。本次实例在出现该警告后已经写入了用户数据，中途打开加密可能读不旧数据，所以没有在已有库上强制开启。密钥务必备份，丢失后已加密字段将无法解密。

4）重置数据库时，卷名可能和官方文档不一样

官方排障写的是 `docker volume rm sure_postgres-data`。如果你的目录不叫 sure，前缀就会变。请先运行 `docker volume ls` 查看真实名称再删除。删卷会丢掉全部账本数据。

另外还有几条本次真实出现、但不影响注册和打开引导页的日志，可以忽略：PostHog 未提供个人 API Key、Skylight 无法启动、未配置 OIDC / SSO。自托管可以不管它们。

备份、HTTPS、邮件和银行同步，本次没有完整实测（未配置域名、证书或 SMTP），这里只标明路径，避免漏掉：升级前可用 `docker compose run --rm backup create` 备份；从外网用 HTTPS 访问时，要自己准备反向代理和证书，并把 compose 里的 RAILS_ASSUME_SSL 改为 "true"，不要把未加密的 3000 端口直接暴露到公网；邮件相关变量必须写进 compose 的 x-rails-env，不能只写在 .env；自托管模式下邀请链接不会自动发信。

## 原仓库 README 要点（不是全文翻译）

Sure 的定位是「面向所有人的个人理财应用」，可以用 Docker 自托管，也可通过浏览器、macOS 桌面应用、移动应用、API 和 LLM 智能体访问。仓库是 Maybe Finance 的社区 fork，许可证为 AGPLv3。开发者本地搭建（Ruby、PostgreSQL、Redis、bin/setup）和 Render / PikaPods 等一键托管按钮，见原文，不是本篇的跟做路径。

请直接阅读官方 README 和自托管文档：

https://github.com/we-promise/sure
https://github.com/we-promise/sure/blob/main/README.md
https://github.com/we-promise/sure/blob/main/docs/hosting/docker.md

我另外做了一份忠实译文，只作对照，不替代原文：如需查阅，见本专栏配套材料中的 README 中文摘要说明。发布时请以原仓库为准。

## 协议声明

软件与官方 README 使用 AGPL-3.0。本文是我自己的操作记录。翻译或转载 README 时必须保留原仓库链接、版权和许可证声明，不能把译文当成原创单独出售。自托管给自己或家人用，一般没有额外义务；如果修改了 Sure 并通过网络提供给他人使用，AGPL 要求提供对应源代码。"Maybe" 是 Maybe Finance Inc. 的商标，本文介绍的是社区 fork Sure，不是官方 Maybe 产品。

不要把 `.env` 里的真实密钥发到网上，也不要把占位符 sk-REPLACE_ME 当作可用的 Key。

## 下期预告

下一篇写 vercel-labs/agent-desktop：一个让 AI 通过系统无障碍树「看到」并点击桌面应用的命令行工具。中文系统教程很少，安装本身不重，但 Linux 上缺 AT-SPI、以及引用过期时怎么报错，都需要亲自跑过才写得清楚。
