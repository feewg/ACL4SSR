#!/bin/bash
set -e

# === 用户输入部分 ===
read -p "请输入 Snell 监听端口 [默认 443]: " PORT
PORT=${PORT:-443}

# === 获取系统架构 ===
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    ARCH="arm64"
else
    echo "❌ 不支持的架构: $ARCH"
    exit 1
fi

# === 获取最新版本并下载 ===
echo "📦 正在获取 Snell 最新版本..."
SNELL_VERSION=$(curl -s https://api.github.com/repos/surge-networks/snell/releases/latest | grep tag_name | cut -d '"' -f 4)
SNELL_URL="https://github.com/surge-networks/snell/releases/download/${SNELL_VERSION}/snell-server-${SNELL_VERSION}-linux-${ARCH}.zip"
echo "🔗 下载链接: $SNELL_URL"

curl -L -o /tmp/snell.zip "$SNELL_URL"
unzip -o /tmp/snell.zip -d /tmp/
chmod +x /tmp/snell-server
mv /tmp/snell-server /usr/local/bin/

# === 自动生成 PSK ===
PSK=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)

# === 写入配置文件 ===
mkdir -p /etc/snell
cat > /etc/snell/snell-server.conf <<EOF
[snell-server]
listen = 0.0.0.0:${PORT}
ipv6 = true
psk = ${PSK}
obfs = tls
EOF

# === 设置 systemd 启动项 ===
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

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable snell
systemctl start snell

# === 获取 IPv6 地址 ===
IPV6=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1)

# === 输出 Surge YAML 配置 ===
echo
echo "✅ Snell 已安装并启动成功"
echo "📄 以下是 Surge/SingBox 可用的代理配置："
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
