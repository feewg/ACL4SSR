#!/bin/bash

# 定义颜色变量
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# 检查是否以 root 权限运行
if [ "$(id -u)" != "0" ]; then
  echo -e "${RED}请以 root 权限运行此脚本。${RESET}"
  exit 1
fi

# 更新并安装必要的依赖项
echo -e "${CYAN}更新系统并安装必要的依赖项...${RESET}"
apt update && apt install -y wget unzip vim

# 下载并解压 Snell Server
SNELL_VERSION="v4.1.1"
ARCH=$(uname -m)
if [[ ${ARCH} == "aarch64" ]]; then
  SNELL_URL="https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-aarch64.zip"
else
  SNELL_URL="https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-amd64.zip"
fi

echo -e "${CYAN}下载 Snell Server...${RESET}"
wget -O snell-server.zip ${SNELL_URL}
if [ $? -ne 0 ]; then
  echo -e "${RED}下载 Snell 失败，请检查网络连接。${RESET}"
  exit 1
fi

echo -e "${CYAN}解压 Snell Server...${RESET}"
unzip -o snell-server.zip -d /usr/local/bin/
chmod +x /usr/local/bin/snell-server
rm -f snell-server.zip

# 创建 Snell 配置目录
echo -e "${CYAN}创建 Snell 配置目录...${RESET}"
mkdir -p /etc/snell/

# 生成 Snell 配置文件
echo -e "${CYAN}生成 Snell 配置文件...${RESET}"
/usr/local/bin/snell-server --wizard -c /etc/snell/snell-server.conf

# 创建并启动 Snell 服务
echo -e "${CYAN}创建并启动 Snell 服务...${RESET}"
cat > /etc/systemd/system/snell.service << EOF
[Unit]
Description=Snell Proxy Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/snell-server -c /etc/snell/snell-server.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置并启动 Snell 服务
systemctl daemon-reload
systemctl enable snell
systemctl start snell

# 获取并显示 Snell 配置信息
echo -e "${CYAN}Snell 服务已安装并启动。以下是您的配置信息：${RESET}"
cat /etc/snell/snell-server.conf

echo -e "${GREEN}安装完成！${RESET}"
