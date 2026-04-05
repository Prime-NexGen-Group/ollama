# Ollama — Cloud Deployment Guide

Deploy Ollama on cloud infrastructure while keeping model storage on **persistent local/attached volumes** (not ephemeral container storage).

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│  Cloud VM / Instance                            │
│  ┌───────────┐    ┌──────────────────────────┐  │
│  │  Ollama   │◄──►│ Persistent Disk / Volume  │  │
│  │  (Docker) │    │ /mnt/ollama-models        │  │
│  └─────┬─────┘    └──────────────────────────┘  │
│        │ :11434                                  │
│  ┌─────┴─────┐                                  │
│  │  Caddy /  │ :443 (HTTPS)                     │
│  │  NGINX    │◄──── Internet / VPN              │
│  └───────────┘                                  │
└─────────────────────────────────────────────────┘
```

Key principle: **Models live on a persistent volume that survives instance termination.**

---

## Option 1 — AWS (EC2 + EBS)

### 1. Launch an Instance

| Setting | Recommendation |
|---------|---------------|
| AMI | Ubuntu 22.04 LTS (or Amazon Linux 2023) |
| Instance type | `g5.xlarge` (GPU) or `c6i.2xlarge` (CPU) |
| Storage | 20 GB root + **100 GB EBS gp3** for models |

### 2. Attach & Mount the EBS Volume

```bash
# Find the device (usually /dev/nvme1n1 for new EBS)
lsblk

# Format (only first time!)
sudo mkfs.ext4 /dev/nvme1n1

# Mount
sudo mkdir -p /mnt/ollama-models
sudo mount /dev/nvme1n1 /mnt/ollama-models
sudo chown $USER:$USER /mnt/ollama-models

# Persist across reboots
echo '/dev/nvme1n1 /mnt/ollama-models ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

### 3. Install Docker & Run Ollama

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# For GPU instances — install NVIDIA drivers + container toolkit
sudo apt-get install -y nvidia-driver-535
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L "https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list" | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Run Ollama with models on the EBS volume
docker run -d \
  --name ollama \
  --gpus all \
  --restart unless-stopped \
  -v /mnt/ollama-models:/root/.ollama \
  -p 127.0.0.1:11434:11434 \
  ollama/ollama

docker exec ollama ollama pull llama3.2
```

### 4. Security Group

| Rule | Port | Source |
|------|------|--------|
| SSH | 22 | Your IP |
| HTTPS | 443 | 0.0.0.0/0 (or VPN CIDR) |
| Ollama (direct) | 11434 | **Block from public** — use reverse proxy |

---

## Option 2 — Google Cloud (GCE + Persistent Disk)

### 1. Create a VM

```bash
gcloud compute instances create ollama-server \
  --zone=us-central1-a \
  --machine-type=g2-standard-8 \
  --accelerator=type=nvidia-l4,count=1 \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=30GB \
  --maintenance-policy=TERMINATE
```

### 2. Create & Attach a Persistent Disk for Models

```bash
gcloud compute disks create ollama-models-disk \
  --size=100GB --type=pd-ssd --zone=us-central1-a

gcloud compute instances attach-disk ollama-server \
  --disk=ollama-models-disk --zone=us-central1-a
```

### 3. Mount the Disk

```bash
# SSH in
gcloud compute ssh ollama-server --zone=us-central1-a

# Inside the VM
sudo mkfs.ext4 -m 0 -E lazy_itable_init=0 /dev/sdb
sudo mkdir -p /mnt/ollama-models
sudo mount -o discard,defaults /dev/sdb /mnt/ollama-models
sudo chown $USER:$USER /mnt/ollama-models
echo '/dev/sdb /mnt/ollama-models ext4 discard,defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

### 4. Run Ollama (same Docker pattern)

```bash
# Install docker + nvidia drivers (same as AWS section above)
docker run -d \
  --name ollama \
  --gpus all \
  --restart unless-stopped \
  -v /mnt/ollama-models:/root/.ollama \
  -p 127.0.0.1:11434:11434 \
  ollama/ollama
```

---

## Option 3 — Azure (VM + Managed Disk)

### 1. Create VM + Disk

```bash
az vm create \
  --resource-group ollama-rg \
  --name ollama-server \
  --image Ubuntu2204 \
  --size Standard_NC6s_v3 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --data-disk-sizes-gb 100
```

### 2. Mount the Data Disk

```bash
ssh azureuser@<public-ip>

# The data disk is usually /dev/sdc
sudo mkfs.ext4 /dev/sdc
sudo mkdir -p /mnt/ollama-models
sudo mount /dev/sdc /mnt/ollama-models
sudo chown $USER:$USER /mnt/ollama-models
echo '/dev/sdc /mnt/ollama-models ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

### 3. Run Ollama Docker

Same Docker run command as the other providers with `-v /mnt/ollama-models:/root/.ollama`.

---

## Option 4 — DigitalOcean / Hetzner / Budget VPS

For CPU-only deployments on affordable VPS providers:

```bash
# Install Ollama directly (no Docker needed for simple setups)
curl -fsSL https://ollama.com/install.sh | sh

# Change model storage to the attached volume
export OLLAMA_MODELS="/mnt/volume1/ollama-models"
ollama serve &
ollama pull phi3   # small model for limited resources
```

---

## Reverse Proxy with Authentication

**Never expose Ollama directly to the internet.** Use a reverse proxy with auth.

### Caddy (automatic HTTPS)

```bash
# Caddyfile
cat > /etc/caddy/Caddyfile << 'EOF'
ollama.yourdomain.com {
    basicauth * {
        admin $2a$14$HASHED_PASSWORD_HERE
    }
    reverse_proxy localhost:11434
}
EOF

sudo systemctl restart caddy
```

Generate a hashed password:

```bash
caddy hash-password --plaintext 'your-secure-password'
```

### NGINX

```nginx
# /etc/nginx/sites-available/ollama
server {
    listen 443 ssl;
    server_name ollama.yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/ollama.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ollama.yourdomain.com/privkey.pem;

    auth_basic "Ollama API";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass http://127.0.0.1:11434;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
```

---

## Systemd Service (non-Docker)

If running Ollama directly on the VM:

```ini
# /etc/systemd/system/ollama.service
[Unit]
Description=Ollama LLM Server
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_MODELS=/mnt/ollama-models"

[Install]
WantedBy=default.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ollama
```

---

## Cloud Cost Comparison (approximate)

| Provider | Instance | GPU | Monthly Cost |
|----------|----------|-----|-------------|
| AWS | g5.xlarge | A10G 24 GB | ~$850 |
| AWS | c6i.2xlarge | CPU only | ~$250 |
| GCP | g2-standard-8 | L4 24 GB | ~$700 |
| GCP | n2-standard-4 | CPU only | ~$140 |
| Azure | NC6s v3 | V100 16 GB | ~$900 |
| DigitalOcean | 8 vCPU / 16 GB | CPU only | ~$96 |
| Hetzner | CCX33 | CPU only | ~$35 |

> **Tip:** For lighter use, a CPU-only VPS with a small model (phi3, llama3.2:3b) can work well under $50/month.

---

## Backup & Restore Models

```bash
# Backup: tar the model directory
tar -czf ollama-models-backup.tar.gz -C /mnt/ollama-models .

# Restore to a new instance
mkdir -p /mnt/ollama-models
tar -xzf ollama-models-backup.tar.gz -C /mnt/ollama-models
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| GPU not detected in Docker | Install NVIDIA Container Toolkit and restart Docker |
| Disk not mounted after reboot | Check `/etc/fstab` entry uses `nofail` |
| Model download times out | Use a larger instance or pull during off-peak |
| 502 from reverse proxy | Increase `proxy_read_timeout` — model loading takes time |
| SSH connection drops during pull | Use `tmux` or `screen` |

---

Next: [Local Setup](local-setup.md) · [Docker Setup](docker-setup.md)
