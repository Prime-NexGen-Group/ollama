#!/usr/bin/env bash
# setup.sh — Quick setup script for Ollama (local or Docker)
set -euo pipefail

MODELS_DIR="./models"
DEFAULT_MODEL="llama3.2"

echo "========================================="
echo "  Ollama Setup"
echo "========================================="
echo ""
echo "Choose your setup method:"
echo "  1) Local install (directly on this machine)"
echo "  2) Docker (CPU only)"
echo "  3) Docker with NVIDIA GPU"
echo ""
read -rp "Enter choice [1/2/3]: " choice

case "$choice" in
  1)
    echo ""
    echo "--- Installing Ollama locally ---"
    if command -v ollama &>/dev/null; then
      echo "Ollama is already installed: $(ollama --version)"
    else
      if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &>/dev/null; then
          brew install ollama
        else
          echo "Please install Homebrew first, or download from https://ollama.com/download/mac"
          exit 1
        fi
      elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -fsSL https://ollama.com/install.sh | sh
      else
        echo "Unsupported OS. Download from https://ollama.com/download"
        exit 1
      fi
    fi

    echo ""
    echo "Starting Ollama server..."
    export OLLAMA_MODELS="${OLLAMA_MODELS:-$HOME/.ollama/models}"
    echo "Model storage: $OLLAMA_MODELS"

    # Start server in background if not already running
    if ! curl -sf http://localhost:11434/ &>/dev/null; then
      ollama serve &
      sleep 3
    fi

    echo "Pulling default model: $DEFAULT_MODEL"
    ollama pull "$DEFAULT_MODEL"
    echo ""
    echo "Done! Run:  ollama run $DEFAULT_MODEL"
    ;;

  2)
    echo ""
    echo "--- Docker (CPU) Setup ---"
    if ! command -v docker &>/dev/null; then
      echo "Docker is not installed. Install it from https://docs.docker.com/get-docker/"
      exit 1
    fi

    mkdir -p "$MODELS_DIR"
    echo "Model storage: $(cd "$MODELS_DIR" && pwd)"
    echo ""
    docker compose up -d
    echo ""
    echo "Waiting for Ollama to be ready..."
    for i in $(seq 1 30); do
      if curl -sf http://localhost:11434/ &>/dev/null; then
        break
      fi
      sleep 2
    done

    echo "Pulling default model: $DEFAULT_MODEL"
    docker exec ollama ollama pull "$DEFAULT_MODEL"
    echo ""
    echo "Done!"
    echo "  Ollama API:  http://localhost:11434"
    echo "  Web UI:      http://localhost:3000"
    echo "  Chat:        docker exec -it ollama ollama run $DEFAULT_MODEL"
    ;;

  3)
    echo ""
    echo "--- Docker + GPU Setup ---"
    if ! command -v docker &>/dev/null; then
      echo "Docker is not installed. Install it from https://docs.docker.com/get-docker/"
      exit 1
    fi

    if ! docker info 2>/dev/null | grep -qi nvidia; then
      echo "WARNING: NVIDIA runtime not detected in Docker."
      echo "Install the NVIDIA Container Toolkit first."
      echo "Continuing anyway..."
    fi

    mkdir -p "$MODELS_DIR"
    echo "Model storage: $(cd "$MODELS_DIR" && pwd)"
    echo ""
    docker compose -f docker-compose.gpu.yml up -d
    echo ""
    echo "Waiting for Ollama to be ready..."
    for i in $(seq 1 30); do
      if curl -sf http://localhost:11434/ &>/dev/null; then
        break
      fi
      sleep 2
    done

    echo "Pulling default model: $DEFAULT_MODEL"
    docker exec ollama-gpu ollama pull "$DEFAULT_MODEL"
    echo ""
    echo "Done!"
    echo "  Ollama API:  http://localhost:11434"
    echo "  Web UI:      http://localhost:3000"
    echo "  Chat:        docker exec -it ollama-gpu ollama run $DEFAULT_MODEL"
    ;;

  *)
    echo "Invalid choice. Please run again and pick 1, 2, or 3."
    exit 1
    ;;
esac
