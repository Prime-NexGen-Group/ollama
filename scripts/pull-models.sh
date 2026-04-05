#!/usr/bin/env bash
# pull-models.sh — Download a curated set of models
set -euo pipefail

OLLAMA_CMD="ollama"

# If running in Docker, override the command
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^ollama'; then
  CONTAINER=$(docker ps --format '{{.Names}}' | grep '^ollama' | head -1)
  OLLAMA_CMD="docker exec $CONTAINER ollama"
fi

MODELS=(
  "llama3.2"            # 3B  — fast, general-purpose
  "deepseek-r1:14b"     # 14B — best reasoning/thinking model
  "phi4"                # 14B — Microsoft's latest, strong all-around
  "mistral"             # 7B  — great for coding & reasoning
  "nomic-embed-text"    # 274MB — best overall embedding model
  "mxbai-embed-large"   # 670MB — higher dimension, better accuracy
)

echo "Pulling models using: $OLLAMA_CMD"
echo "=================================="

for model in "${MODELS[@]}"; do
  echo ""
  echo ">>> Pulling $model ..."
  $OLLAMA_CMD pull "$model"
done

echo ""
echo "All models pulled. Available models:"
$OLLAMA_CMD list
