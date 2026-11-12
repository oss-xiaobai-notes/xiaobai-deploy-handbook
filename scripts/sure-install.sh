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
