# Ollama — Local, Docker & Cloud LLM Setup

Run open-source LLMs anywhere. **Models are always stored locally** — on your host machine or a persistent volume — so nothing is lost when containers restart.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Repository Structure](#repository-structure)
- [Guides](#guides)
- [Models](#models)
- [API Usage](#api-usage)
- [Web UI & Dashboard](#web-ui--dashboard)
- [Public Access (Cloudflare Tunnel)](#public-access-cloudflare-tunnel)
- [Custom Models](#custom-models)
- [Examples](#examples)
- [Key Design: Local Model Storage](#key-design-local-model-storage)
- [Environment Variables](#environment-variables)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### Option A: One-command setup

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

Asks you to pick **local install**, **Docker (CPU)**, or **Docker (GPU)** — then handles everything.

### Option B: Docker Compose

```bash
# Start Ollama + Web UI
docker compose up -d

# Pull a model
docker exec ollama ollama pull llama3.2

# Chat via CLI
docker exec -it ollama ollama run llama3.2

# Open Web UI → http://localhost:3000
```

Models are stored in `./models/` on your host — **not** inside the container.

### Option C: Docker with NVIDIA GPU

```bash
docker compose -f docker-compose.gpu.yml up -d
docker exec ollama ollama pull llama3.2
```

### Option D: Direct local install (no Docker)

```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh

# Start & run
ollama serve &
ollama pull llama3.2
ollama run llama3.2
```

---

## Repository Structure

```
.
├── README.md                        # ← You are here
├── docker-compose.yml               # Docker (CPU) + Open WebUI + local model storage
├── docker-compose.gpu.yml           # Docker (NVIDIA GPU) + Open WebUI + local model storage
├── .env.example                     # Environment variable reference
├── .gitignore                       # Ignores model data directories
│
├── docs/
│   ├── local-setup.md               # Local install guide (macOS/Linux/Windows)
│   ├── docker-setup.md              # Docker guide with volume mounts
│   ├── gpu-server-setup.md          # GPU server deployment (NVIDIA + reverse proxy)
│   ├── cloud-setup.md               # AWS / GCP / Azure / budget VPS
│   ├── api-reference.md             # Full REST API + Python / JS examples
│   └── public-url-setup.md          # Free public URLs (Cloudflare, ngrok, Tailscale)
│
├── examples/
│   ├── python/
│   │   ├── chat_example.py          # Chat, generate, list models, embeddings
│   │   └── rag_example.py           # RAG pipeline (embed → search → answer)
│   ├── node/
│   │   └── chat_example.mjs         # Node.js chat & embeddings
│   └── curl_examples.sh             # Test all API endpoints from terminal
│
├── dashboard/
│   └── index.html                   # Model dashboard (open in any browser)
│
├── scripts/
│   ├── setup.sh                     # Interactive setup wizard
│   └── pull-models.sh               # Pull curated model set
│
├── modelfiles/
│   ├── Modelfile.coder              # Coding assistant personality
│   └── Modelfile.concise            # Brief/concise answer personality
│
└── models/                          # ← Model data (git-ignored, persists locally)
```

---

## Guides

| Guide | What it covers |
|-------|---------------|
| [Local Setup](docs/local-setup.md) | Install natively, CLI commands, GPU acceleration, REST API |
| [Docker Setup](docs/docker-setup.md) | Docker Compose, volume mounts, Open WebUI, health checks |
| [GPU Server Setup](docs/gpu-server-setup.md) | NVIDIA drivers, Container Toolkit, reverse proxy, firewall, monitoring |
| [Cloud Deployment](docs/cloud-setup.md) | AWS / GCP / Azure / DigitalOcean, persistent disks, systemd, cost comparison |
| [API Reference](docs/api-reference.md) | All REST endpoints, Python & JavaScript libraries, options reference |
| [Public URL / Tunnels](docs/public-url-setup.md) | Cloudflare Tunnel, ngrok, localhost.run, Tailscale |

---

## Models

### Recommended Models

| Model | Size | Type | Best For |
|-------|------|------|----------|
| `llama3.2` | ~2 GB | Chat | Fast general-purpose, light hardware |
| `deepseek-r1:14b` | ~9 GB | Reasoning | Best reasoning/thinking model, chain-of-thought |
| `phi4` | ~9 GB | Chat | Microsoft's latest, strong all-around |
| `mistral` | ~4.1 GB | Chat | Coding and reasoning |
| `nomic-embed-text` | ~274 MB | Embedding | Best overall embedding model (768 dim) |
| `mxbai-embed-large` | ~670 MB | Embedding | Higher accuracy embedding (1024 dim) |

### Pull Models

```bash
# One at a time
docker exec ollama ollama pull llama3.2
docker exec ollama ollama pull deepseek-r1:14b

# Or pull all recommended models at once
chmod +x scripts/pull-models.sh
./scripts/pull-models.sh
```

### Manage Models

```bash
docker exec ollama ollama list              # List downloaded models
docker exec ollama ollama ps                # Show running/loaded models
docker exec ollama ollama rm old-model      # Delete a model
docker exec ollama ollama show llama3.2     # Show model details
```

---

## API Usage

Ollama exposes a REST API at `http://localhost:11434`:

### Chat

```bash
curl http://localhost:11434/api/chat \
  -d '{
    "model": "llama3.2",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": false
  }'
```

### Generate Text

```bash
curl http://localhost:11434/api/generate \
  -d '{
    "model": "llama3.2",
    "prompt": "Explain Docker in one sentence.",
    "stream": false
  }'
```

### Embeddings

```bash
curl http://localhost:11434/api/embed \
  -d '{
    "model": "nomic-embed-text",
    "input": "Text to embed"
  }'
```

### List Models

```bash
curl http://localhost:11434/api/tags
```

Full endpoint reference with Python/JS examples → [API Reference](docs/api-reference.md)

---

## Web UI & Dashboard

### Open WebUI (ChatGPT-like interface)

Included in the Docker Compose setup — runs at `http://localhost:3000`:

```bash
docker compose up -d
# Open http://localhost:3000 → create admin account → start chatting
```

Features: chat with any model, conversation history, model selection dropdown, admin panel to pull models.

### Model Dashboard (lightweight)

A standalone HTML page that connects to your Ollama instance:

```bash
open dashboard/index.html
```

Features: see all installed models, model types (Chat/Embedding/Reasoning), one-click test, copy curl commands, works with any URL (local or public tunnel).

---

## Public Access (Cloudflare Tunnel)

Expose your local Ollama to the internet for free — no domain or static IP needed:

```bash
# Install (macOS)
brew install cloudflared

# Expose the API
cloudflared tunnel --url http://localhost:11434
# → https://random-name.trycloudflare.com

# Expose the Web UI (in another terminal)
cloudflared tunnel --url http://localhost:3000
# → https://another-name.trycloudflare.com
```

Now anyone can access your models via the public URL:

```bash
curl https://random-name.trycloudflare.com/api/chat \
  -d '{"model": "llama3.2", "messages": [{"role": "user", "content": "Hello!"}], "stream": false}'
```

> **Note:** URLs change on each restart. No account needed. See [Public URL Guide](docs/public-url-setup.md) for ngrok, Tailscale, and persistent tunnel options.

---

## Custom Models

Create personalities using Modelfiles:

```bash
# Create a coding assistant
docker exec ollama ollama create my-coder -f /dev/stdin <<'EOF'
FROM llama3.2
PARAMETER temperature 0.7
SYSTEM "You are a helpful coding assistant. Always provide working code examples."
EOF

# Use it
docker exec -it ollama ollama run my-coder
```

Or use the included Modelfiles:

```bash
# Copy modelfile into container and create
docker cp modelfiles/Modelfile.coder ollama:/tmp/
docker exec ollama ollama create my-coder -f /tmp/Modelfile.coder
```

---

## Examples

| File | Language | What it does |
|------|----------|-------------|
| [examples/python/chat_example.py](examples/python/chat_example.py) | Python | Chat, generate, list models, embeddings |
| [examples/python/rag_example.py](examples/python/rag_example.py) | Python | Full RAG pipeline — embed docs, search, answer with context |
| [examples/node/chat_example.mjs](examples/node/chat_example.mjs) | Node.js | Chat and embeddings |
| [examples/curl_examples.sh](examples/curl_examples.sh) | Bash | Test every API endpoint from terminal |

Run the Python example:

```bash
pip install requests
python examples/python/chat_example.py
```

Run the curl test suite:

```bash
chmod +x examples/curl_examples.sh
./examples/curl_examples.sh
```

---

## Key Design: Local Model Storage

All configurations mount model data to your **host filesystem**:

```
Host machine                  Docker container
./models/  ◄───volume───►  /root/.ollama
```

This means:
- Models **survive** `docker compose down`, `docker rm`, image updates
- **Back up** models by copying `./models/`
- **Share** models between multiple containers
- **Zero re-downloading** when updating the Ollama image

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_HOST` | `127.0.0.1:11434` | Server bind address |
| `OLLAMA_MODELS` | `~/.ollama/models` | Model storage directory |
| `OLLAMA_NUM_PARALLEL` | `1` | Parallel request handling |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Max models in memory at once |
| `OLLAMA_KEEP_ALIVE` | `5m` | Time to keep model loaded after last request |
| `OLLAMA_FLASH_ATTENTION` | `0` | Enable flash attention (faster, less VRAM) |
| `OLLAMA_ORIGINS` | `*` | Allowed CORS origins |

See [.env.example](.env.example) for a ready-to-use template.

---

## Security

- Ollama has **no built-in authentication**
- **Never expose port 11434 directly to the internet**
- For remote access, use a **reverse proxy** (Caddy/NGINX) with auth — see [GPU Server Guide](docs/gpu-server-setup.md)
- Cloudflare quick tunnels are **unauthenticated** — only share URLs with trusted people
- For private access, use **Tailscale** (VPN) — see [Public URL Guide](docs/public-url-setup.md)

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `connection refused` | Ensure `ollama serve` or Docker container is running |
| Models re-download after restart | Check volume mount — models should be in `./models/` |
| Out of memory | Use a smaller model or increase Docker memory limit |
| GPU not detected (Docker) | Install [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) |
| Slow generation | Enable GPU; or use a smaller/quantized model |
| Port already in use | `OLLAMA_HOST=0.0.0.0:11435 ollama serve` |
| Tunnel URL not working | Wait 10-15 seconds after starting cloudflared |
| Web UI can't find models | Ensure Ollama container is healthy: `docker ps` |

---

## License

This repository contains setup guides and configurations. Ollama itself is licensed under the [MIT License](https://github.com/ollama/ollama/blob/main/LICENSE).
