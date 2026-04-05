# Ollama — API Reference

Complete guide to the Ollama REST API. All endpoints are available at `http://localhost:11434` by default.

---

## Base URL

```
Local:    http://localhost:11434
Docker:   http://localhost:11434  (same — port-mapped)
Remote:   https://ollama.yourdomain.com  (behind reverse proxy)
```

---

## Authentication

Ollama has **no built-in auth**. For remote access, use a reverse proxy with basic auth (see [GPU Server Setup](gpu-server-setup.md)).

For authenticated endpoints:

```bash
curl -u admin:password https://ollama.yourdomain.com/api/tags
```

---

## Endpoints Overview

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/generate` | Generate text completion |
| POST | `/api/chat` | Chat conversation |
| POST | `/api/embed` | Generate embeddings |
| POST | `/api/create` | Create a model from Modelfile |
| POST | `/api/pull` | Pull a model from registry |
| POST | `/api/push` | Push a model to registry |
| POST | `/api/copy` | Copy a model |
| DELETE | `/api/delete` | Delete a model |
| GET | `/api/tags` | List local models |
| POST | `/api/show` | Show model info |
| GET | `/api/ps` | List running models |
| GET | `/` | Health check |

---

## Generate — `/api/generate`

Single prompt → completion. Good for one-shot tasks.

### Basic Request

```bash
curl http://localhost:11434/api/generate \
  -d '{
    "model": "llama3.2",
    "prompt": "Explain Docker volumes in 3 sentences.",
    "stream": false
  }'
```

### Response

```json
{
  "model": "llama3.2",
  "created_at": "2026-04-05T10:00:00Z",
  "response": "Docker volumes are persistent storage mechanisms...",
  "done": true,
  "total_duration": 1234567890,
  "load_duration": 123456789,
  "prompt_eval_count": 12,
  "eval_count": 85,
  "eval_duration": 987654321
}
```

### With Streaming (default)

```bash
curl http://localhost:11434/api/generate \
  -d '{
    "model": "llama3.2",
    "prompt": "Write a haiku about coding."
  }'
```

Returns newline-delimited JSON chunks:

```json
{"model":"llama3.2","response":"Lines","done":false}
{"model":"llama3.2","response":" of","done":false}
{"model":"llama3.2","response":" code","done":false}
...
{"model":"llama3.2","response":"","done":true,"total_duration":...}
```

### With Options

```bash
curl http://localhost:11434/api/generate \
  -d '{
    "model": "llama3.2",
    "prompt": "Write a Python function to sort a list.",
    "stream": false,
    "options": {
      "temperature": 0.7,
      "top_p": 0.9,
      "top_k": 40,
      "num_predict": 500,
      "num_ctx": 4096,
      "seed": 42,
      "stop": ["\n\n"]
    }
  }'
```

### With System Prompt

```bash
curl http://localhost:11434/api/generate \
  -d '{
    "model": "llama3.2",
    "prompt": "Review this code: def add(a,b): return a+b",
    "system": "You are a senior Python developer. Be concise.",
    "stream": false
  }'
```

### With Images (Vision Models)

```bash
curl http://localhost:11434/api/generate \
  -d '{
    "model": "llava",
    "prompt": "What is in this image?",
    "images": ["BASE64_ENCODED_IMAGE_HERE"],
    "stream": false
  }'
```

---

## Chat — `/api/chat`

Multi-turn conversation with message history.

### Basic Chat

```bash
curl http://localhost:11434/api/chat \
  -d '{
    "model": "llama3.2",
    "messages": [
      {"role": "user", "content": "What is Kubernetes?"}
    ],
    "stream": false
  }'
```

### Response

```json
{
  "model": "llama3.2",
  "created_at": "2026-04-05T10:00:00Z",
  "message": {
    "role": "assistant",
    "content": "Kubernetes is an open-source container orchestration platform..."
  },
  "done": true,
  "total_duration": 2345678901
}
```

### Multi-Turn Conversation

```bash
curl http://localhost:11434/api/chat \
  -d '{
    "model": "llama3.2",
    "messages": [
      {"role": "system", "content": "You are a helpful coding assistant."},
      {"role": "user", "content": "Write a Python hello world"},
      {"role": "assistant", "content": "print(\"Hello, World!\")"},
      {"role": "user", "content": "Now make it a function"}
    ],
    "stream": false
  }'
```

### With DeepSeek R1 (Thinking Model)

```bash
curl http://localhost:11434/api/chat \
  -d '{
    "model": "deepseek-r1:14b",
    "messages": [
      {"role": "user", "content": "What is 25% of 1340?"}
    ],
    "stream": false
  }'
```

The response includes the model's reasoning chain in `<think>...</think>` tags.

---

## Embeddings — `/api/embed`

Generate vector embeddings for text. Used for RAG, semantic search, similarity matching.

### Single Text

```bash
curl http://localhost:11434/api/embed \
  -d '{
    "model": "nomic-embed-text",
    "input": "Ollama is a tool for running LLMs locally."
  }'
```

### Response

```json
{
  "model": "nomic-embed-text",
  "embeddings": [
    [0.123, -0.456, 0.789, ...]
  ]
}
```

### Batch Embeddings (Multiple Texts)

```bash
curl http://localhost:11434/api/embed \
  -d '{
    "model": "nomic-embed-text",
    "input": [
      "First document about Kubernetes",
      "Second document about Docker",
      "Third document about CI/CD"
    ]
  }'
```

Returns one embedding vector per input text.

### Using mxbai-embed-large (Higher Dimension)

```bash
curl http://localhost:11434/api/embed \
  -d '{
    "model": "mxbai-embed-large",
    "input": "This text will be embedded in 1024 dimensions."
  }'
```

---

## List Models — `GET /api/tags`

```bash
curl http://localhost:11434/api/tags
```

### Response

```json
{
  "models": [
    {
      "name": "llama3.2:latest",
      "model": "llama3.2:latest",
      "size": 2019393189,
      "digest": "a80c4f17acd5...",
      "modified_at": "2026-04-05T10:00:00Z",
      "details": {
        "parent_model": "",
        "format": "gguf",
        "family": "llama",
        "parameter_size": "3.2B",
        "quantization_level": "Q4_K_M"
      }
    }
  ]
}
```

---

## Show Model Info — `POST /api/show`

```bash
curl http://localhost:11434/api/show \
  -d '{"name": "llama3.2"}'
```

Returns: model details, parameters, system prompt, template, license.

---

## Running Models — `GET /api/ps`

```bash
curl http://localhost:11434/api/ps
```

### Response

```json
{
  "models": [
    {
      "name": "llama3.2:latest",
      "model": "llama3.2:latest",
      "size": 2019393189,
      "digest": "a80c4f17acd5...",
      "expires_at": "2026-04-05T10:10:00Z",
      "size_vram": 2019393189,
      "details": {
        "family": "llama",
        "parameter_size": "3.2B",
        "quantization_level": "Q4_K_M"
      }
    }
  ]
}
```

---

## Pull a Model — `POST /api/pull`

```bash
curl http://localhost:11434/api/pull \
  -d '{"name": "mistral", "stream": false}'
```

### Streaming Progress

```bash
curl http://localhost:11434/api/pull \
  -d '{"name": "phi4"}'
```

Returns progress chunks:

```json
{"status":"pulling manifest"}
{"status":"pulling abc123","digest":"sha256:abc123...","total":9000000000,"completed":1500000000}
...
{"status":"success"}
```

---

## Create a Custom Model — `POST /api/create`

```bash
curl http://localhost:11434/api/create \
  -d '{
    "name": "my-coder",
    "modelfile": "FROM llama3.2\nSYSTEM You are a coding assistant.\nPARAMETER temperature 0.7",
    "stream": false
  }'
```

---

## Copy a Model — `POST /api/copy`

```bash
curl http://localhost:11434/api/copy \
  -d '{
    "source": "llama3.2",
    "destination": "llama3.2-backup"
  }'
```

---

## Delete a Model — `DELETE /api/delete`

```bash
curl -X DELETE http://localhost:11434/api/delete \
  -d '{"name": "old-model"}'
```

---

## Health Check — `GET /`

```bash
curl http://localhost:11434/
# Returns: "Ollama is running"
```

---

## Python Examples

### Using `requests`

```python
import requests

# Chat
response = requests.post("http://localhost:11434/api/chat", json={
    "model": "llama3.2",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": False
})
print(response.json()["message"]["content"])

# Embeddings
response = requests.post("http://localhost:11434/api/embed", json={
    "model": "nomic-embed-text",
    "input": "Text to embed"
})
embedding = response.json()["embeddings"][0]
print(f"Dimension: {len(embedding)}")
```

### Using `ollama` Python Library

```bash
pip install ollama
```

```python
import ollama

# Chat
response = ollama.chat(model="llama3.2", messages=[
    {"role": "user", "content": "What is Python?"}
])
print(response["message"]["content"])

# Streaming
for chunk in ollama.chat(model="llama3.2", messages=[
    {"role": "user", "content": "Tell me a joke"}
], stream=True):
    print(chunk["message"]["content"], end="", flush=True)

# Embeddings
result = ollama.embed(model="nomic-embed-text", input="Hello world")
print(len(result["embeddings"][0]))  # 768

# List models
models = ollama.list()
for m in models["models"]:
    print(f"{m['name']} — {m['details']['parameter_size']}")
```

### Connecting to Remote Server

```python
import ollama

client = ollama.Client(host="https://ollama.yourdomain.com")
response = client.chat(model="llama3.2", messages=[
    {"role": "user", "content": "Hello from remote!"}
])
```

---

## JavaScript / Node.js Examples

```bash
npm install ollama
```

```javascript
import { Ollama } from 'ollama';

const ollama = new Ollama({ host: 'http://localhost:11434' });

// Chat
const response = await ollama.chat({
  model: 'llama3.2',
  messages: [{ role: 'user', content: 'Hello!' }],
});
console.log(response.message.content);

// Streaming
const stream = await ollama.chat({
  model: 'llama3.2',
  messages: [{ role: 'user', content: 'Tell me a story' }],
  stream: true,
});
for await (const chunk of stream) {
  process.stdout.write(chunk.message.content);
}

// Embeddings
const embed = await ollama.embed({
  model: 'nomic-embed-text',
  input: 'Text to embed',
});
console.log(embed.embeddings[0].length); // 768
```

---

## Common Options Reference

Use these in the `options` field for `/api/generate` and `/api/chat`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `temperature` | float | 0.8 | Randomness (0 = deterministic, 1 = creative) |
| `top_p` | float | 0.9 | Nucleus sampling threshold |
| `top_k` | int | 40 | Top-K sampling |
| `num_predict` | int | 128 | Max tokens to generate (-1 = unlimited) |
| `num_ctx` | int | 2048 | Context window size |
| `seed` | int | — | Random seed for reproducibility |
| `stop` | string[] | — | Stop sequences |
| `repeat_penalty` | float | 1.1 | Penalty for repeated tokens |
| `presence_penalty` | float | 0.0 | Penalize already-mentioned topics |
| `frequency_penalty` | float | 0.0 | Penalize frequently used tokens |

---

## Error Handling

| HTTP Code | Meaning |
|-----------|---------|
| 200 | Success |
| 400 | Bad request (invalid JSON, missing model) |
| 404 | Model not found (pull it first) |
| 500 | Internal error (check `docker logs ollama`) |

Example error response:

```json
{
  "error": "model 'nonexistent' not found, try pulling it first"
}
```

---

Next: [GPU Server Setup](gpu-server-setup.md) · [Docker Setup](docker-setup.md) · [Local Setup](local-setup.md)
