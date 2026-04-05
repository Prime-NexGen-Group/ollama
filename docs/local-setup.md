# Ollama — Local Setup Guide

Run large language models entirely on your local machine.

---

## Prerequisites

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| RAM         | 8 GB    | 16 GB+      |
| Disk        | 10 GB free | 50 GB+ (models are large) |
| OS          | macOS 13+, Ubuntu 20.04+, Windows 10+ | Latest stable |
| GPU (optional) | — | NVIDIA with 6 GB+ VRAM / Apple Silicon |

---

## 1 — Install Ollama

### macOS

```bash
# Homebrew (recommended)
brew install ollama

# — OR — download the .dmg from https://ollama.com/download/mac
```

### Linux

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Windows

Download the installer from **https://ollama.com/download/windows** and follow the wizard.

---

## 2 — Start the Ollama Server

```bash
ollama serve
```

By default the server listens on **http://127.0.0.1:11434**.

> **Tip:** On macOS & Windows the desktop app starts the server automatically.

---

## 3 — Pull & Run a Model

```bash
# Pull a model first (one-time download)
ollama pull llama3.2

# Interactive chat
ollama run llama3.2
```

### Popular Models

| Model | Parameters | Disk Size | Use Case |
|-------|-----------|-----------|----------|
| `llama3.2` | 3 B | ~2 GB | Fast, general-purpose |
| `llama3.1` | 8 B | ~4.7 GB | Balanced quality/speed |
| `llama3.1:70b` | 70 B | ~40 GB | High quality, needs beefy hardware |
| `mistral` | 7 B | ~4.1 GB | Great coding & reasoning |
| `codellama` | 7 B | ~3.8 GB | Code generation |
| `phi3` | 3.8 B | ~2.2 GB | Small but capable |
| `gemma2` | 9 B | ~5.4 GB | Google's open model |
| `deepseek-coder-v2` | 16 B | ~8.9 GB | Advanced coding |

---

## 4 — Model Storage Location

Models are stored locally at:

| OS | Default Path |
|----|-------------|
| macOS | `~/.ollama/models` |
| Linux | `~/.ollama/models` |
| Windows | `C:\Users\<user>\.ollama\models` |

### Change the Storage Location

Set the `OLLAMA_MODELS` environment variable **before** starting the server:

```bash
# Example: store models on an external drive
export OLLAMA_MODELS="/Volumes/ExternalSSD/ollama-models"
ollama serve
```

To make it permanent, add the export to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.).

---

## 5 — Use the REST API

Ollama exposes a local REST API — no network dependency.

### Generate a Completion

```bash
curl http://localhost:11434/api/generate \
  -d '{
    "model": "llama3.2",
    "prompt": "Explain Kubernetes in one paragraph.",
    "stream": false
  }'
```

### Chat Conversation

```bash
curl http://localhost:11434/api/chat \
  -d '{
    "model": "llama3.2",
    "messages": [
      {"role": "user", "content": "What is a neural network?"}
    ],
    "stream": false
  }'
```

### List Local Models

```bash
curl http://localhost:11434/api/tags
```

---

## 6 — Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_HOST` | `127.0.0.1:11434` | Bind address for the server |
| `OLLAMA_MODELS` | `~/.ollama/models` | Model storage directory |
| `OLLAMA_NUM_PARALLEL` | `1` | Number of parallel requests |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Max models kept in memory |
| `OLLAMA_KEEP_ALIVE` | `5m` | How long to keep a model loaded after last request |
| `OLLAMA_ORIGINS` | `*` | Allowed CORS origins |

---

## 7 — Create a Custom Model (Modelfile)

```dockerfile
# Modelfile
FROM llama3.2

PARAMETER temperature 0.7
PARAMETER top_p 0.9

SYSTEM """
You are a helpful coding assistant. Always provide working code examples.
"""
```

```bash
ollama create my-coder -f Modelfile
ollama run my-coder
```

---

## 8 — GPU Acceleration

### NVIDIA (Linux / Windows)

Ollama auto-detects CUDA-capable GPUs. Ensure you have:
- NVIDIA driver **525+**
- CUDA toolkit is **not** required (Ollama bundles its own runtime)

Check GPU usage:

```bash
nvidia-smi
```

### Apple Silicon (macOS)

Metal acceleration is automatic on M1/M2/M3/M4 — no extra setup needed.

### CPU-Only Mode

```bash
OLLAMA_GPU_LAYERS=0 ollama serve
```

---

## 9 — Useful CLI Commands

```bash
ollama list               # List downloaded models
ollama show llama3.2      # Show model details
ollama cp llama3.2 my-backup  # Copy/rename a model
ollama rm old-model       # Delete a model
ollama ps                 # Show running models
ollama stop llama3.2      # Unload a model from memory
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `connection refused` | Make sure `ollama serve` is running |
| Out of memory | Use a smaller model or increase swap |
| Slow on CPU | Enable GPU acceleration (see above) |
| Model download fails | Check disk space and internet connection |
| Port already in use | `OLLAMA_HOST=0.0.0.0:11435 ollama serve` |

---

Next: [Docker Setup](docker-setup.md) · [Cloud Deployment](cloud-setup.md)
