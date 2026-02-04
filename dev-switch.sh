#!/bin/bash

# 1. 环境准备：定位真实的家目录
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# --- 路径定义区 ---
# [文件 A] 用户级服务文件 (这是一个普通文本文件)
SERVICE_FILE="$REAL_HOME/.config/systemd/user/openclaw-gateway.service"
# [文件 B] CLI 软链接 (这是一个指向 mjs 的快捷方式)
CLI_LINK="$REAL_HOME/.nvm/versions/node/v24.13.0/bin/openclaw"

# [路径组 1] 生产环境 (Production) 
PROD_SERVICE_JS="$REAL_HOME/.nvm/versions/node/v24.13.0/lib/node_modules/openclaw/dist/index.js"
PROD_CLI_MJS="$REAL_HOME/.nvm/versions/node/v24.13.0/lib/node_modules/openclaw/openclaw.mjs"

# [路径组 2] 开发环境 (Development)
DEV_SERVICE_JS="$REAL_HOME/development/fast-development/source-doc/openclaw/dist/index.js"
DEV_CLI_MJS="$REAL_HOME/development/fast-development/source-doc/openclaw/openclaw.mjs"

# 检查必要文件/链接是否存在
if [ ! -f "$SERVICE_FILE" ]; then echo "❌ 错误: 找不到服务文件 $SERVICE_FILE"; exit 1; fi
if [ ! -L "$CLI_LINK" ] && [ ! -f "$CLI_LINK" ]; then echo "❌ 错误: 找不到 CLI 链接 $CLI_LINK"; exit 1; fi

# --- 切换逻辑 ---
# 使用 readlink 检查当前软链接指向哪里
CURRENT_LINK_TARGET=$(readlink -f "$CLI_LINK")

if [[ "$CURRENT_LINK_TARGET" == "$PROD_CLI_MJS" ]]; then
    echo "🚀 检测到 [生产版本]，正在切换至 [开发版本]..."
    
    # 1. 修改 Service 文件内容
    sed -i "s|$PROD_SERVICE_JS|$DEV_SERVICE_JS|g" "$SERVICE_FILE"
    
    # 2. 修改 CLI 软链接指向 (ln -sf 强制重定向)
    ln -sf "$DEV_CLI_MJS" "$CLI_LINK"
    
    STATUS="开发版本 (Development)"
else
    echo "⏪ 检测到 [开发版本]，正在还原至 [生产版本]..."
    
    # 1. 还原 Service 文件内容
    sed -i "s|$DEV_SERVICE_JS|$PROD_SERVICE_JS|g" "$SERVICE_FILE"
    
    # 2. 还原 CLI 软链接指向
    ln -sf "$PROD_CLI_MJS" "$CLI_LINK"
    
    STATUS="生产版本 (Production)"
fi

# --- 让改动生效 ---
echo "⚙️  正在重新加载用户级 systemd 并重启服务..."
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway.service

echo "------------------------------------------------"
echo "✅ 切换成功！"
echo "当前模式: $STATUS"
echo "Service 执行路径: $(grep 'ExecStart' "$SERVICE_FILE" | awk '{print $NF}')"
echo "CLI 命令指向:   $(readlink -f "$CLI_LINK")"
echo "------------------------------------------------"
