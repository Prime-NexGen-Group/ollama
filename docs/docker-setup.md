# Ollama — Docker Setup (Local Model Storage)

Run Ollama in Docker while keeping all model data on your **host machine** so nothing is lost when the container restarts.

---

## Prerequisites

- Docker Engine 20.10+ (or Docker Desktop)
- At least 8 GB RAM allocated to Docker
- (Optional) NVIDIA Container Toolkit for GPU passthrough

---

## Quick Start

### CPU-Only

```bash
docker run -d \
  --name ollama \
  -v ollama-models:/root/.ollama \
  -p 11434:11434 \
  ollama/ollama
```

### NVIDIA GPU

```bash
docker run -d \
  --name ollama \
  --gpus all \
  -v ollama-models:/root/.ollama \
  -p 11434:11434 \
  ollama/ollama
```

Then pull a model:

```bash
docker exec ollama ollama pull llama3.2
docker exec -it ollama ollama run llama3.2
```

---

## Local Model Storage (The Key Part)

The `-v` flag binds a volume so models persist **on your host**, not inside the disposable container.

### Option A — Named Docker Volume (simplest)

```bash
-v ollama-models:/root/.ollama
```

Data lives in Docker's managed volume storage. Inspect with:

```bash
docker volume inspect ollama-models
```

### Option B — Bind Mount to a Specific Host Path (recommended)

Point to any directory on your machine:

```bash
# macOS / Linux
-v /home/you/ollama-models:/root/.ollama

# Windows (PowerShell)
-v C:\Users\you\ollama-models:/root/.ollama
```

This guarantees that:
- Models survive container removal (`docker rm`)
- You can back up models by copying the folder
- Multiple containers can share the same models (read-only)

---

## Docker Compose

Create a `docker-compose.yml`:

```yaml
# docker-compose.yml
version: "3.9"

services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      # LOCAL model storage — change the left side to your preferred path
      - ./models:/root/.ollama
    environment:
      - OLLAMA_KEEP_ALIVE=10m
      - OLLAMA_NUM_PARALLEL=2
    # Uncomment for NVIDIA GPU support:
    # deploy:
    #   resources:
    #     reservations:
    #       devices:
    #         - driver: nvidia
    #           count: all
    #           capabilities: [gpu]

  # Optional: web UI for chatting with models
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    ports:
      - "3000:8080"
    volumes:
      - ./open-webui-data:/app/backend/data
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    depends_on:
      - ollama
```

```bash
# Start everything
docker compose up -d

# Pull a model
docker exec ollama ollama pull llama3.2

# Open the web UI at http://localhost:3000
```

---

## Docker Compose with GPU (NVIDIA)

```yaml
# docker-compose.gpu.yml
version: "3.9"

services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama-gpu
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - ./models:/root/.ollama
    environment:
      - OLLAMA_KEEP_ALIVE=10m
      - OLLAMA_NUM_PARALLEL=4
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    ports:
      - "3000:8080"
    volumes:
      - ./open-webui-data:/app/backend/data
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    depends_on:
      - ollama
```

```bash
docker compose -f docker-compose.gpu.yml up -d
```

---

## Verifying Local Storage

```bash
# Check models are stored on your host
ls -la ./models/models/

# inside the container, same content
docker exec ollama ls /root/.ollama/models/
```

---

## Useful Docker Commands

```bash
# View logs
docker logs -f ollama

# Shell into the container
docker exec -it ollama bash

# List models
docker exec ollama ollama list

# Pull a new model
docker exec ollama ollama pull mistral

# Stop & remove (models are safe on host!)
docker compose down

# Restart
docker compose up -d

# Update to latest Ollama image
docker compose pull && docker compose up -d
```

---

## Exposing to the Network

To let other machines on your LAN reach Ollama:

```yaml
environment:
  - OLLAMA_HOST=0.0.0.0:11434
```

> **Security note:** Only expose on trusted networks. Ollama has no built-in authentication. Use a reverse proxy (NGINX/Caddy) with auth for production.

---

## Resource Limits

```yaml
services:
  ollama:
    # ...
    mem_limit: 16g
    cpus: "4.0"
```

---

## Health Check

```yaml
services:
  ollama:
    # ...
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/"]
      interval: 30s
      timeout: 10s
      retries: 3
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `permission denied` on volume | `sudo chown -R $USER:$USER ./models` |
| GPU not detected | Install [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) |
| Container exits immediately | Check logs: `docker logs ollama` |
| Models re-download after restart | Ensure the volume mount is correct |
| Port conflict | Change host port: `-p 11435:11434` |

---

Next: [Local Setup](local-setup.md) · [Cloud Deployment](cloud-setup.md)
