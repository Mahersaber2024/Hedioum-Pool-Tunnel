#!/bin/bash

# ==========================================================
# Hedioum Dynamic Pool Tunnel - Custom Installer (Mahersaber2024)
# ==========================================================

REPO_OWNER="Mahersaber2024"   # <-- نام کاربری شما
REPO_NAME="Hedioum-Pool-Tunnel"
BINARY_NAME="hedioum-tunnel"
CONFIG_DIR="/etc/hedioum"
BIN_DIR="/usr/local/bin"
SERVICE_NAME="hedioum.service"

if [ "$EUID" -ne 0 ]; then
  echo "[x] CRITICAL: Please run the installer as root."
  exit 1
fi

echo "=================================================="
echo "  Deploying Hedioum Stealth Mesh Daemon (Custom)..."
echo "  Repo: ${REPO_OWNER}/${REPO_NAME}"
echo "=================================================="

mkdir -p ${CONFIG_DIR}
mkdir -p ${BIN_DIR}

# --- Stop and unlink old binary ---
if systemctl is-active --quiet ${SERVICE_NAME}; then
    echo "[*] Stopping existing daemon..."
    systemctl stop ${SERVICE_NAME} > /dev/null 2>&1
fi
rm -f ${BIN_DIR}/${BINARY_NAME}

# --- Architecture Detection ---
OS_ARCH=$(uname -m)
TARGET_ASSET="${BINARY_NAME}"

if [ "$OS_ARCH" = "aarch64" ] || [ "$OS_ARCH" = "arm64" ]; then
    TARGET_ASSET="${BINARY_NAME}-arm64"
    echo "[*] Detected ARM64 architecture."
else
    echo "[*] Detected AMD64/x86_64 architecture."
fi

# --- Download from YOUR fork (Mahersaber2024) ---
echo "[*] Fetching latest release from ${REPO_OWNER}/${REPO_NAME}..."

LATEST_URL=$(curl -s https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest | grep "browser_download_url" | grep "${TARGET_ASSET}\"" | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
    echo "[-] No release found in your fork. Using main branch binary (manual compile needed)."
    echo "    Please create a Release in your GitHub fork or compile manually."
    exit 1
fi

# --- Download with proxy fallback ---
URL_PROXY="https://ghp.ci/${LATEST_URL}"

if curl -f -L -s -o ${BIN_DIR}/${BINARY_NAME} "$LATEST_URL"; then
    echo "[✓] Binary downloaded successfully (Direct Release)."
elif curl -f -L -s -o ${BIN_DIR}/${BINARY_NAME} "$URL_PROXY"; then
    echo "[✓] Binary downloaded successfully (Proxy Fallback)."
else
    echo "[x] ERROR: Failed to download binary from your fork."
    echo "    Please check that you have created a Release in:"
    echo "    https://github.com/${REPO_OWNER}/${REPO_NAME}/releases"
    exit 1
fi

chmod +x ${BIN_DIR}/${BINARY_NAME}

# --- Systemd service ---
echo "[*] Configuring Systemd service..."
cat << EOF > /etc/systemd/system/${SERVICE_NAME}
[Unit]
Description=Hedioum Dynamic Pool Tunnel Daemon (Custom Fork)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${CONFIG_DIR}
ExecStart=${BIN_DIR}/${BINARY_NAME}
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${SERVICE_NAME} > /dev/null 2>&1

echo "=================================================="
if [ ! -f "${CONFIG_DIR}/hedioum.json" ]; then
    echo -e "[!] Fresh installation. Launching Setup Wizard..."
    sleep 2
    cd ${CONFIG_DIR} && ${BIN_DIR}/${BINARY_NAME}
    echo -e "\n[✓] Setup complete!"
else
    echo "[✓] Existing config found. Restarting service..."
    systemctl restart ${SERVICE_NAME}
    echo "[✓] Restarted successfully."
fi

echo "=================================================="
echo " [✓] Installation complete from your fork!"
echo "     Command: ${BINARY_NAME}"
echo "=================================================="
