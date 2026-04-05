# Ollama — Public URL & Tunnel Guide

Expose your local Ollama to the internet with a **free dynamic URL** — no domain or static IP required.

---

## Why Tunnels?

- Share your Ollama instance with teammates
- Access from your phone or another machine
- Test API integrations without deploying to cloud
- Free — no domain or server needed

---

## Option 1 — Cloudflare Tunnel (Recommended, Free)

The best free option — fast, reliable, and doesn't require a Cloudflare account for quick tunnels.

### Quick Tunnel (No account needed)

```bash
# Install cloudflared
# macOS
brew install cloudflared

# Linux
curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared && sudo mv cloudflared /usr/local/bin/

# Expose Ollama API
cloudflared tunnel --url http://localhost:11434
```

Output:

```
Your quick Tunnel has been created! Visit it at:
https://random-name-here.trycloudflare.com
```

That URL is your **public Ollama API**:

```bash
curl https://random-name-here.trycloudflare.com/api/tags
```

### Expose the Web UI too

Open a second terminal:

```bash
cloudflared tunnel --url http://localhost:3000
```

Now you have two public URLs — one for the API, one for the chat UI.

### Named Tunnel (Persistent URL, needs free account)

```bash
cloudflared tunnel login
cloudflared tunnel create ollama
cloudflared tunnel route dns ollama ollama.yourdomain.com

# Create config
cat > ~/.cloudflared/config.yml << 'EOF'
tunnel: ollama
credentials-file: /home/user/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: ollama.yourdomain.com
    service: http://localhost:11434
  - hostname: chat.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
EOF

cloudflared tunnel run ollama
```

---

## Option 2 — ngrok (Free tier)

```bash
# Install
# macOS
brew install ngrok

# Linux
curl -fsSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | tar xz
sudo mv ngrok /usr/local/bin/

# Sign up at https://dashboard.ngrok.com (free) and get auth token
ngrok config add-authtoken YOUR_TOKEN

# Expose Ollama API
ngrok http 11434
```

Output:

```
Forwarding  https://abc123.ngrok-free.app -> http://localhost:11434
```

Use it:

```bash
curl https://abc123.ngrok-free.app/api/tags
```

### Expose both API + Web UI

```bash
# Terminal 1
ngrok http 11434

# Terminal 2
ngrok http 3000
```

> **Note:** Free ngrok gives random URLs that change each restart. Paid plan ($8/mo) gives static URLs.

---

## Option 3 — localhost.run (Zero install)

No installation needed — just SSH:

```bash
ssh -R 80:localhost:11434 nokey@localhost.run
```

Output:

```
https://abc123.localhost.run
```

For the Web UI:

```bash
ssh -R 80:localhost:3000 nokey@localhost.run
```

---

## Option 4 — Tailscale (Private network, free)

Access your Ollama from anywhere via a private VPN — not public, but secure.

```bash
# Install Tailscale
# macOS
brew install tailscale

# Linux
curl -fsSL https://tailscale.com/install.sh | sh

# Start
sudo tailscale up

# Find your Tailscale IP
tailscale ip -4
# e.g., 100.64.0.5
```

Then from any device on your Tailscale network:

```bash
curl http://100.64.0.5:11434/api/tags
# Open http://100.64.0.5:3000 for the Web UI
```

Make sure Ollama listens on all interfaces:

```yaml
# docker-compose.yml
environment:
  - OLLAMA_HOST=0.0.0.0:11434
```

---

## Using Your Public URL

### From Python

```python
import requests

# Just change the URL — everything else stays the same
OLLAMA_URL = "https://random-name-here.trycloudflare.com"

resp = requests.post(f"{OLLAMA_URL}/api/chat", json={
    "model": "llama3.2",
    "messages": [{"role": "user", "content": "Hello from the internet!"}],
    "stream": False,
})
print(resp.json()["message"]["content"])
```

### From JavaScript

```javascript
const OLLAMA_URL = "https://random-name-here.trycloudflare.com";

const resp = await fetch(`${OLLAMA_URL}/api/chat`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "llama3.2",
    messages: [{ role: "user", content: "Hello from the internet!" }],
    stream: false,
  }),
});
const data = await resp.json();
console.log(data.message.content);
```

### From curl

```bash
export OLLAMA_URL="https://random-name-here.trycloudflare.com"
curl $OLLAMA_URL/api/tags
```

---

## Docker Compose with Tunnel

Add a Cloudflare tunnel container to auto-expose on startup:

```yaml
services:
  ollama:
    image: ollama/ollama:latest
    # ... (same as before)

  tunnel:
    image: cloudflare/cloudflared:latest
    container_name: ollama-tunnel
    restart: unless-stopped
    command: tunnel --no-autoupdate --url http://ollama:11434
    depends_on:
      ollama:
        condition: service_healthy
```

The tunnel URL will appear in the logs:

```bash
docker logs ollama-tunnel 2>&1 | grep "trycloudflare.com"
```

---

## Security Considerations

| Method | Public? | Auth? | Best for |
|--------|---------|-------|----------|
| Cloudflare Quick Tunnel | Yes | No (add your own) | Quick sharing, demos |
| Cloudflare Named Tunnel | Yes | Can add Access rules | Production |
| ngrok | Yes | No (add your own) | Quick testing |
| localhost.run | Yes | No | Zero-install demos |
| Tailscale | No (private VPN) | Built-in | Secure personal access |

**Important:** Ollama has no authentication. If you use a public tunnel:

- Anyone with the URL can use your models
- Consider using Cloudflare Access (free) for auth
- Or only share the URL with trusted people
- Or use Tailscale for private-only access

---

## See Models in the Web UI

Your **Open WebUI** at `http://localhost:3000` (or its public tunnel URL) already shows:

- All available models in a dropdown
- Model details (size, parameters, family)
- Chat interface to test each model
- Admin panel to pull new models
- Usage history and conversations

No extra setup needed — it auto-discovers all models from Ollama.

---

Next: [API Reference](api-reference.md) · [GPU Server Setup](gpu-server-setup.md) · [Docker Setup](docker-setup.md)
