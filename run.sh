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

# 3. Pull Target Model (Single-line progress update)
echo "--- Pulling Model: ${MODEL_NAME} ---"
python3 -u -c "
import urllib.request, json, sys

model = sys.argv[1]
req = urllib.request.Request(
    'http://localhost:11434/api/pull',
    data=json.dumps({'name': model}).encode(),
    headers={'Content-Type': 'application/json'}
)

last_pct = -1
last_status = ''
try:
    with urllib.request.urlopen(req) as resp:
        for line in resp:
            if not line.strip():
                continue
            d = json.loads(line.decode())
            status = d.get('status', '')
            total = d.get('total', 0)
            completed = d.get('completed', 0)
            if total > 0:
                pct = int((completed / total) * 100)
                if pct != last_pct:
                    mb_done = completed // (1024 * 1024)
                    mb_tot = total // (1024 * 1024)
                    sys.stdout.write(f'\r\033[K[Ollama] {status} {pct}% ({mb_done}/{mb_tot} MB)')
                    sys.stdout.flush()
                    last_pct = pct
            else:
                if status != last_status:
                    sys.stdout.write(f'\r\033[K[Ollama] {status}\n')
                    sys.stdout.flush()
                    last_status = status
    print(f'\r\033[K[Ollama] Model {model} downloaded successfully!\n')
except Exception as e:
    sys.exit(1)
" "${MODEL_NAME}" || ollama pull "${MODEL_NAME}"

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
