#!/usr/bin/env bash
set -e

# Take model name from the first argument, default if not provided
MODEL_NAME="${1:-qwen3.8:27b}"

# 1. Install Ollama
echo "--- Installing Ollama ---"
sudo apt-get update && sudo apt-get install -y zstd curl
curl -L https://ollama.com/download/ollama-linux-amd64.tar.zst | sudo tar --zstd -x -C /usr/local

# 2. Start Ollama Server
echo "--- Starting Ollama Server ---"
pkill -f "ollama serve" || true
sleep 1

export OLLAMA_ORIGINS="*"
export OLLAMA_HOST="0.0.0.0"

ollama serve > /dev/null 2>&1 &
sleep 3
ollama --version

# 3. Pull Target Model
echo "--- Pulling Model: ${MODEL_NAME} ---"
ollama pull "${MODEL_NAME}"

# 4. Install Cloudflared
echo "--- Installing Cloudflared ---"
curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb
rm cloudflared.deb

# 5. Start Tunnel & Capture URL
echo "--- Starting Cloudflared Tunnel ---"
cloudflared tunnel --url http://localhost:11434 2>&1 | while read -r line; do
  echo "$line"
  if [[ "$line" =~ https://[a-zA-Z0-9-]+\.trycloudflare\.com ]]; then
    echo -e "\n=========================================="
    echo -e "Your Ollama public URL is:\n${BASH_REMATCH[0]}"
    echo -e "==========================================\n"
  fi
done
