# Ollama — GPU Server Deployment Guide

Deploy Ollama with GPU acceleration on your own server for maximum inference speed.

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| GPU | NVIDIA with 8 GB+ VRAM (RTX 3060+, A100, L4, V100, etc.) |
| NVIDIA Driver | 525+ |
| Docker | 20.10+ |
| NVIDIA Container Toolkit | Required for GPU passthrough to Docker |
| OS | Ubuntu 22.04 LTS (recommended) |

---

## Step 1 — Install NVIDIA Drivers

```bash
# Check if drivers are already installed
nvidia-smi

# If not, install them
sudo apt-get update
sudo apt-get install -y nvidia-driver-535
sudo reboot
```

After reboot, verify:

```bash
nvidia-smi
# Should show your GPU, driver version, and CUDA version
```

---

## Step 2 — Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker run hello-world
```

---

## Step 3 — Install NVIDIA Container Toolkit

This lets Docker containers access your GPU.

```bash
# Add NVIDIA repo
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker to use NVIDIA runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Verify GPU is visible inside Docker:

```bash
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
```

---

## Step 4 — Set Up Persistent Model Storage

```bash
# Create a directory for models (use a large disk/partition)
sudo mkdir -p /opt/ollama-models
sudo chown $USER:$USER /opt/ollama-models
```

If you have a separate data disk (recommended):

```bash
# Find the disk
lsblk

# Format and mount (only first time!)
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /opt/ollama-models
sudo mount /dev/sdb /opt/ollama-models
sudo chown $USER:$USER /opt/ollama-models

# Persist across reboots
echo '/dev/sdb /opt/ollama-models ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

---

## Step 5 — Deploy with Docker Compose

Create a project directory:

```bash
mkdir -p ~/ollama-server && cd ~/ollama-server
```

Create `docker-compose.gpu.yml`:

```yaml
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "127.0.0.1:11434:11434"
    volumes:
      - /opt/ollama-models:/root/.ollama
    environment:
      - OLLAMA_KEEP_ALIVE=10m
      - OLLAMA_NUM_PARALLEL=4
      - OLLAMA_HOST=0.0.0.0:11434
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    healthcheck:
      test: ["CMD-SHELL", "ollama list || exit 1"]
      interval: 15s
      timeout: 10s
      retries: 5
      start_period: 30s

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:8080"
    volumes:
      - ./open-webui-data:/app/backend/data
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    depends_on:
      ollama:
        condition: service_healthy
```

Start it:

```bash
docker compose -f docker-compose.gpu.yml up -d
```

---

## Step 6 — Pull Models

```bash
# Reasoning model
docker exec ollama ollama pull deepseek-r1:14b

# Fast general model
docker exec ollama ollama pull llama3.2

# Smart all-around
docker exec ollama ollama pull phi4

# Embedding models
docker exec ollama ollama pull nomic-embed-text
docker exec ollama ollama pull mxbai-embed-large

# Verify GPU is being used
docker exec ollama ollama ps
```

---

## Step 7 — Secure with Reverse Proxy (HTTPS + Auth)

**Never expose Ollama directly to the internet — it has no authentication.**

### Option A: Caddy (easiest — automatic HTTPS)

```bash
sudo apt-get install -y caddy
```

```bash
# /etc/caddy/Caddyfile
cat << 'EOF' | sudo tee /etc/caddy/Caddyfile
ollama.yourdomain.com {
    basicauth * {
        admin HASHED_PASSWORD_HERE
    }
    reverse_proxy localhost:11434
}

chat.yourdomain.com {
    reverse_proxy localhost:3000
}
EOF
```

Generate password hash:

```bash
caddy hash-password --plaintext 'your-secure-password'
```

```bash
sudo systemctl restart caddy
```

### Option B: NGINX + Let's Encrypt

```bash
sudo apt-get install -y nginx certbot python3-certbot-nginx
```

```nginx
# /etc/nginx/sites-available/ollama
server {
    listen 80;
    server_name ollama.yourdomain.com;

    location / {
        auth_basic "Ollama API";
        auth_basic_user_file /etc/nginx/.htpasswd;

        proxy_pass http://127.0.0.1:11434;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
```

```bash
# Create password file
sudo apt-get install -y apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Enable site & get SSL cert
sudo ln -s /etc/nginx/sites-available/ollama /etc/nginx/sites-enabled/
sudo certbot --nginx -d ollama.yourdomain.com
sudo systemctl restart nginx
```

---

## Step 8 — Firewall

```bash
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 443/tcp    # HTTPS
sudo ufw allow 80/tcp     # HTTP (for cert renewal)
sudo ufw deny 11434       # Block direct Ollama access from outside
sudo ufw deny 3000        # Block direct WebUI access from outside
sudo ufw enable
```

---

## Verify GPU Usage

```bash
# Check running models and GPU layers
docker exec ollama ollama ps

# Monitor GPU in real-time
watch -n 1 nvidia-smi
```

Expected output from `ollama ps`:

```
NAME               ID         SIZE     PROCESSOR    UNTIL
deepseek-r1:14b    abcd1234   9.0 GB   100% GPU     5 minutes from now
```

If you see `100% GPU` — you're running at full speed.

---

## Multi-GPU Setup

If you have multiple GPUs:

```yaml
# docker-compose.gpu.yml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all           # Use all GPUs
          capabilities: [gpu]
```

Or specify specific GPUs:

```yaml
        - driver: nvidia
          device_ids: ["0", "1"]  # GPU 0 and 1 only
          capabilities: [gpu]
```

---

## Performance Tuning

| Setting | What it does | Recommended |
|---------|-------------|-------------|
| `OLLAMA_NUM_PARALLEL` | Concurrent requests | 2-4 for single GPU |
| `OLLAMA_MAX_LOADED_MODELS` | Models in VRAM at once | 1 (unless you have 48 GB+ VRAM) |
| `OLLAMA_KEEP_ALIVE` | Time model stays loaded | `10m` to `1h` |
| `OLLAMA_FLASH_ATTENTION` | Faster attention (less VRAM) | `1` (enable it) |

Add to your compose environment:

```yaml
environment:
  - OLLAMA_NUM_PARALLEL=4
  - OLLAMA_MAX_LOADED_MODELS=1
  - OLLAMA_KEEP_ALIVE=30m
  - OLLAMA_FLASH_ATTENTION=1
```

---

## Monitoring & Logs

```bash
# Container logs
docker logs -f ollama

# GPU monitoring
nvidia-smi dmon -d 5      # metrics every 5 seconds

# Disk usage (models)
du -sh /opt/ollama-models/
```

---

## Auto-Restart on Boot

Docker's `restart: unless-stopped` handles this. Verify:

```bash
sudo reboot
# After reboot:
docker ps   # Should show ollama and open-webui running
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `could not select device driver nvidia` | Install NVIDIA Container Toolkit (Step 3) |
| GPU not detected | Check `nvidia-smi` outside Docker first |
| Out of VRAM | Use a smaller model or set `OLLAMA_MAX_LOADED_MODELS=1` |
| Slow despite GPU | Check `ollama ps` — should show `100% GPU` |
| Container won't start | `docker logs ollama` — check for driver mismatch |
| Models missing after reboot | Check `/etc/fstab` mount is correct |

---

Next: [API Reference](api-reference.md) · [Docker Setup](docker-setup.md) · [Cloud Deployment](cloud-setup.md)
