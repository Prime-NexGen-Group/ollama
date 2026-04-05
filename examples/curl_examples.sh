#!/usr/bin/env bash
# curl_examples.sh — Test all API endpoints from the command line
set -euo pipefail

BASE="${OLLAMA_URL:-http://localhost:11434}"
MODEL="${MODEL:-llama3.2}"
EMBED_MODEL="${EMBED_MODEL:-nomic-embed-text}"

echo "Using: $BASE"
echo "Model: $MODEL"
echo "=============================="

# Health check
echo -e "\n--- Health Check ---"
curl -s "$BASE/"
echo ""

# List models
echo -e "\n--- List Models ---"
curl -s "$BASE/api/tags" | python3 -m json.tool 2>/dev/null || curl -s "$BASE/api/tags"

# Running models
echo -e "\n--- Running Models ---"
curl -s "$BASE/api/ps" | python3 -m json.tool 2>/dev/null || curl -s "$BASE/api/ps"

# Chat
echo -e "\n--- Chat ---"
curl -s "$BASE/api/chat" \
  -d "{
    \"model\": \"$MODEL\",
    \"messages\": [{\"role\": \"user\", \"content\": \"Say hello in 5 words\"}],
    \"stream\": false
  }" | python3 -c "import sys,json; print(json.load(sys.stdin)['message']['content'])" 2>/dev/null

# Generate
echo -e "\n--- Generate ---"
curl -s "$BASE/api/generate" \
  -d "{
    \"model\": \"$MODEL\",
    \"prompt\": \"What is 2+2? Answer in one word.\",
    \"stream\": false
  }" | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])" 2>/dev/null

# Embeddings
echo -e "\n--- Embeddings ---"
curl -s "$BASE/api/embed" \
  -d "{
    \"model\": \"$EMBED_MODEL\",
    \"input\": \"Hello world\"
  }" | python3 -c "
import sys, json
data = json.load(sys.stdin)
vec = data['embeddings'][0]
print(f'Dimensions: {len(vec)}')
print(f'First 5: {vec[:5]}')
" 2>/dev/null

# Model info
echo -e "\n--- Model Info ---"
curl -s "$BASE/api/show" \
  -d "{\"name\": \"$MODEL\"}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'Family: {data.get(\"details\",{}).get(\"family\",\"?\")}')
print(f'Parameters: {data.get(\"details\",{}).get(\"parameter_size\",\"?\")}')
print(f'Quantization: {data.get(\"details\",{}).get(\"quantization_level\",\"?\")}')
" 2>/dev/null

echo -e "\n=============================="
echo "All endpoints working!"
