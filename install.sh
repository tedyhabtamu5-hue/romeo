#!/usr/bin/env bash
set -u
echo "[*] ROMEO deps"
apt update
apt install -y metasploit-framework tor proxychains4 hping3 nmap hydra aircrack-ng \
  airodump-ng mdk4 macchanger apktool default-jdk python3 curl wget git bettercap \
  wifite theharvester pipx golang-go
curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
  -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared
GOBIN=/usr/local/bin go install github.com/Ullaakut/cameradar/v5@latest
pipx install sherlock-project 2>/dev/null
systemctl enable tor 2>/dev/null
mkdir -p ~/.android
[ -f ~/.android/debug.keystore ] || keytool -genkey -keystore ~/.android/debug.keystore \
  -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
  -validity 10000 -dname "CN=Android Debug,O=Android,C=US" 2>/dev/null
echo "[+] done"