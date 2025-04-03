#!/bin/bash

# Snell 安装脚本

set -e

# 设置默认端口
read -p "请输入 Snell 监听端口 [默认 443]: " PORT
PORT=${PORT:-443}

# 下载并安装 Snell 最新版本（根据系统架构）
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    ARCH="arm64"
else
    echo "不支持的架构: $ARCH"
    exit 1
fi

SNELL_VERSION=$(curl -s https://api.github.com/repos/surge-networks/snell/releases/latest | grep tag_name | cut -d '"' -f 4)
SNELL_URL="https://github.com/surge-networks/snell/releases/download/${SNELL_VERSION}/snell-server-${SNELL_VERSION}-linux-${ARCH}.zip"

echo "下载 Snell: $SNELL_URL"
curl -L -o snell.zip "$SNELL_URL"
unzip -o snell.zip
chmod +x snell-server
mv snell-server /usr/local/bin/

# 生成随机 PSK
PSK=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)

# 创建配置文件
mkdir -p /etc/snell
cat > /etc/snell/snell-server.conf <<EOF
[snell-server]
listen = 0.0.0.0:${PORT}
ipv6 = true
psk = ${PSK}
obfs = tls
EOF

# 创建 systemd 服务
cat > /etc/systemd/system/snell.service <<EOF
[Unit]
Description=Snell Proxy Service
After=network.target

[Service]
ExecStart=/usr/local/bin/snell-server -c /etc/snell/snell-server.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 启动并设置开机自启
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable snell
systemctl start snell

# 获取服务器 IPv6 地址
IPV6=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1)

# 输出客户端配置（YAML）
echo
echo "✅ Snell 已安装并启动成功"
echo "📦 客户端 Surge YAML 配置如下："
echo "----------------------------------------"
echo "proxies:"
echo "  - name: Snell"
echo "    type: snell"
echo "    server: \"[$IPV6]\""
echo "    port: $PORT"
echo "    psk: \"$PSK\""
echo "    obfs: tls"
echo "    tfo: true"
echo "----------------------------------------"
